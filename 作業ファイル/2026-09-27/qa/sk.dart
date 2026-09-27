import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/subscription_catalog.dart';
import '../services/subscription_entitlement.dart';
import '../services/subscription_offer.dart';
import 'subscription_exceptions.dart';
import 'subscription_repository.dart';

class EntitlementLoad {
  const EntitlementLoad({required this.records, required this.authoritative});

  final List<SubscriptionEntitlementRecord> records;

  /// True when the store answered. A failure must not wipe a still-valid expiry.
  final bool authoritative;
}

/// App Store の自動更新サブスクリプション。
class StoreKitSubscriptionRepository extends SubscriptionRepository {
  StoreKitSubscriptionRepository({
    InAppPurchase? store,
    SharedPreferences? preferences,
    Stream<List<PurchaseDetails>>? purchaseUpdates,
    Future<EntitlementLoad> Function()? loadEntitlements,
    DateTime Function()? clock,
  }) : _store = store,
       _preferences = preferences,
       _purchaseUpdates = purchaseUpdates,
       _loadEntitlements = loadEntitlements,
       _clock = clock ?? DateTime.now;

  static const expiryKey = 'calonavi_plus_expires_at_ms';
  static const legacyPlusKey = 'calonavi_plus_active';

  final InAppPurchase? _store;
  final SharedPreferences? _preferences;
  final Stream<List<PurchaseDetails>>? _purchaseUpdates;
  final Future<EntitlementLoad> Function()? _loadEntitlements;
  final DateTime Function() _clock;

  final StreamController<bool> _plusController =
      StreamController<bool>.broadcast();
  final SubscriptionEntitlementState _entitlement =
      SubscriptionEntitlementState();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _plus = false;

  @override
  bool get isPlusActive => _plus;

  @override
  Stream<bool> get plusChanges => _plusController.stream;

  Future<void> initialize() async {
    final prefs = await _prefs();
    await prefs.remove(legacyPlusKey);
    final stored = prefs.getInt(expiryKey);
    if (stored != null) {
      _entitlement.replaceAll([
        SubscriptionEntitlementRecord(
          productId: SubscriptionCatalog.monthlyProductId,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(stored),
        ),
      ]);
    }
    _plus = _entitlement.isActive(_clock());
    _purchaseSubscription ??= _updates.listen(_onPurchases);
    try {
      await _refreshEntitlement();
    } catch (_) {}
  }

  Stream<List<PurchaseDetails>> get _updates {
    final updates = _purchaseUpdates;
    if (updates != null) {
      return updates;
    }
    return (_store ?? InAppPurchase.instance).purchaseStream;
  }

  InAppPurchase? get _purchases {
    if (_store != null) {
      return _store;
    }
    if (_purchaseUpdates != null) {
      return null;
    }
    return InAppPurchase.instance;
  }

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    final store = _purchases ?? InAppPurchase.instance;
    try {
      final available = await store.isAvailable();
      if (!available) {
        return SubscriptionOfferings.failed;
      }
      final response = await store.queryProductDetails({
        SubscriptionCatalog.monthlyProductId,
        SubscriptionCatalog.yearlyProductId,
      });
      if (response.error != null) {
        return SubscriptionOfferings.failed;
      }
      return SubscriptionOfferings(
        monthly: _offerFor(
          response.productDetails,
          SubscriptionCatalog.monthlyProductId,
        ),
        yearly: _offerFor(
          response.productDetails,
          SubscriptionCatalog.yearlyProductId,
        ),
        loadFailed: false,
      );
    } catch (_) {
      return SubscriptionOfferings.failed;
    }
  }

  @override
  Future<void> restore() async {
    final store = _purchases ?? InAppPurchase.instance;
    await store.restorePurchases();
    await _refreshEntitlement();
  }

  @override
  Future<void> purchaseMonthly() {
    return _buy(SubscriptionCatalog.monthlyProductId);
  }

  @override
  Future<void> purchaseYearly() {
    return _buy(SubscriptionCatalog.yearlyProductId);
  }

  Future<void> _buy(String productId) async {
    final store = _purchases ?? InAppPurchase.instance;
    final available = await store.isAvailable();
    if (!available) {
      throw SubscriptionPurchaseUnavailableException();
    }
    final response = await store.queryProductDetails({
      SubscriptionCatalog.monthlyProductId,
      SubscriptionCatalog.yearlyProductId,
    });
    if (response.error != null) {
      throw SubscriptionPurchaseFailedException(response.error!.message);
    }
    ProductDetails? product;
    for (final item in response.productDetails) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }
    if (product == null || product.price.trim().isEmpty) {
      throw SubscriptionPurchaseFailedException(
        '購入商品が見つかりません。App Store Connect で商品を作成してください。',
      );
    }
    final launched = await store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!launched) {
      throw SubscriptionPurchaseFailedException('購入画面を開けませんでした。');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final store = _purchases;
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _entitlement.apply(
          SubscriptionEntitlementRecord(
            productId: purchase.productID,
            expiresAt: _expiryOf(purchase),
          ),
        );
      }
      if (purchase.pendingCompletePurchase && store != null) {
        await store.completePurchase(purchase);
      }
    }
    await _persist();
  }

  Future<void> _refreshEntitlement() async {
    final load = _loadEntitlements ?? _loadStoreEntitlements;
    final result = await load();
    if (!result.authoritative) {
      _plus = _entitlement.isActive(_clock());
      return;
    }
    _entitlement.replaceAll(result.records);
    await _persist();
  }

  Future<EntitlementLoad> _loadStoreEntitlements() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return const EntitlementLoad(records: [], authoritative: false);
    }
    try {
      final transactions = await SK2Transaction.transactions();
      return EntitlementLoad(
        records: [
          for (final transaction in transactions)
            SubscriptionEntitlementRecord(
              productId: transaction.productId,
              expiresAt: parseStoreExpiryMillis(transaction.expirationDate),
            ),
        ],
        authoritative: true,
      );
    } catch (_) {
      return const EntitlementLoad(records: [], authoritative: false);
    }
  }

  SubscriptionProductOffer? _offerFor(
    List<ProductDetails> products,
    String productId,
  ) {
    for (final product in products) {
      if (product.id != productId || product.price.trim().isEmpty) {
        continue;
      }
      return SubscriptionProductOffer(
        productId: product.id,
        period: periodForProduct(
          productId: product.id,
          storePeriod: _storePeriod(product),
        ),
        localizedPrice: product.price,
      );
    }
    return null;
  }

  PlusBillingPeriod? _storePeriod(ProductDetails product) {
    if (product is! AppStoreProduct2Details) {
      return null;
    }
    final period = product.sk2Product.subscription?.subscriptionPeriod;
    if (period == null) {
      return null;
    }
    return switch (period.unit) {
      SK2SubscriptionPeriodUnit.month when period.value == 1 =>
        PlusBillingPeriod.month,
      SK2SubscriptionPeriodUnit.year when period.value == 1 =>
        PlusBillingPeriod.year,
      _ => PlusBillingPeriod.other,
    };
  }

  DateTime? _expiryOf(PurchaseDetails purchase) {
    if (purchase is SK2PurchaseDetails) {
      return parseStoreExpiryMillis(purchase.expirationDate);
    }
    return null;
  }

  Future<void> _persist() async {
    final expiry = _entitlement.latestExpiry;
    final prefs = await _prefs();
    if (expiry == null) {
      await prefs.remove(expiryKey);
    } else {
      await prefs.setInt(expiryKey, expiry.millisecondsSinceEpoch);
    }
    final active = _entitlement.isActive(_clock());
    if (active == _plus) {
      return;
    }
    _plus = active;
    if (!_plusController.isClosed) {
      _plusController.add(active);
    }
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? await SharedPreferences.getInstance();
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _plusController.close();
  }
}
