import 'dart:convert';

import '../config/subscription_catalog.dart';

class SubscriptionEntitlementRecord {
  const SubscriptionEntitlementRecord({
    required this.productId,
    required this.expiresAt,
  });

  final String productId;

  /// Null when the store did not provide an expiry. That is not an active grant.
  final DateTime? expiresAt;
}

/// Plus access follows the latest unexpired subscription, not a sticky flag.
class SubscriptionEntitlementState {
  SubscriptionEntitlementState([Map<String, DateTime>? initial])
    : expiryByProduct = Map<String, DateTime>.of(initial ?? const {});

  final Map<String, DateTime> expiryByProduct;

  void apply(SubscriptionEntitlementRecord record) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      return;
    }
    final expiry = record.expiresAt;
    if (expiry == null) {
      expiryByProduct.remove(record.productId);
      return;
    }
    expiryByProduct[record.productId] = expiry;
  }

  void replaceAll(Iterable<SubscriptionEntitlementRecord> records) {
    expiryByProduct.clear();
    for (final record in records) {
      apply(record);
    }
  }

  DateTime? get latestExpiry {
    DateTime? best;
    for (final expiry in expiryByProduct.values) {
      if (best == null || expiry.isAfter(best)) {
        best = expiry;
      }
    }
    return best;
  }

  bool isActive(DateTime now) {
    final expiry = latestExpiry;
    return expiry != null && expiry.isAfter(now);
  }
}

DateTime? parseStoreExpiryMillis(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final millis = int.tryParse(raw);
  if (millis == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Apple's Transaction.jsonRepresentation `revocationDate`.
/// A value means the transaction was refunded or revoked and must not grant Plus.
DateTime? parseStoreRevocationDate(String? jsonRepresentation) {
  if (jsonRepresentation == null || jsonRepresentation.isEmpty) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(jsonRepresentation);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final raw = decoded['revocationDate'];
  if (raw == null) {
    return null;
  }
  if (raw is num) {
    return _dateFromEpoch(raw);
  }
  if (raw is String) {
    final asNum = num.tryParse(raw);
    if (asNum != null) {
      return _dateFromEpoch(asNum);
    }
    return DateTime.tryParse(raw);
  }
  return null;
}

DateTime _dateFromEpoch(num value) {
  final millis = value.abs() >= 1000000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis.round(), isUtc: true);
}
