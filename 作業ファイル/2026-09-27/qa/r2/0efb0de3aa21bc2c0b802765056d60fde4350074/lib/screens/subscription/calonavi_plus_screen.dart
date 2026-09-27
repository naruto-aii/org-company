import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/subscription_exceptions.dart';
import '../../repositories/subscription_repository.dart';
import '../../screens/legal/legal_document.dart';
import '../../screens/legal/legal_document_screen.dart';
import '../../services/subscription_offer.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_content_constraint.dart';

Future<bool> guardPlusFeature({
  required BuildContext context,
  required AppController controller,
  required Future<void> Function() ensure,
}) async {
  try {
    await ensure();
    return true;
  } on SubscriptionLimitExceededException {
    if (context.mounted) {
      await showCalonaviPlus(context, controller.subscriptionRepository);
    }
    return false;
  }
}

Future<void> showCalonaviPlus(
  BuildContext context,
  SubscriptionRepository repository,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => CalonaviPlusScreen(repository: repository),
    ),
  );
}

class CalonaviPlusScreen extends StatefulWidget {
  const CalonaviPlusScreen({super.key, required this.repository});

  final SubscriptionRepository repository;

  @override
  State<CalonaviPlusScreen> createState() => _CalonaviPlusScreenState();
}

class _CalonaviPlusScreenState extends State<CalonaviPlusScreen> {
  bool _busy = false;
  bool _loadingPrices = true;
  SubscriptionOfferings? _offerings;

  @override
  void initState() {
    super.initState();
    _loadPrices(showLoading: false);
  }

  Future<void> _loadPrices({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _loadingPrices = true);
    }
    SubscriptionOfferings offerings;
    try {
      offerings = await widget.repository.loadOfferings();
    } catch (_) {
      offerings = SubscriptionOfferings.failed;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _offerings = offerings;
      _loadingPrices = false;
    });
  }

  Future<void> _purchase(Future<void> Function() action) async {
    await _guarded(() async {
      await action();
      if (!mounted) {
        return;
      }
      if (widget.repository.isPlusActive) {
        _showMessage(AppStrings.plusPurchaseSuccess);
        _closeIfPossible();
      }
    }, failureMessage: AppStrings.plusPurchaseFailed);
  }

  Future<void> _restore() async {
    await _guarded(() async {
      await widget.repository.restore();
      if (!mounted) {
        return;
      }
      if (widget.repository.isPlusActive) {
        _showMessage(AppStrings.plusRestoreSuccess);
        _closeIfPossible();
      } else {
        _showMessage(AppStrings.plusRestoreEmpty);
      }
    }, failureMessage: AppStrings.plusRestoreFailed);
  }

  Future<void> _guarded(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
    } on SubscriptionPurchaseUnavailableException {
      if (!mounted) {
        return;
      }
      _showMessage(AppStrings.plusPurchaseUnavailable);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(failureMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _closeIfPossible() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;
    final offerings = _offerings;
    final monthly = offerings?.monthly;
    final yearly = offerings?.yearly;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.plusTitle),
        leading: IconButton(
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: AppContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(AppStrings.plusLead, style: body),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('・公開食品検索が無制限'),
                    Text('・食事テンプレートが無制限'),
                    Text('・運動テンプレートが無制限'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.plusFreeQuota,
                style: body?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loadingPrices)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    children: [
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: AppSpacing.sm),
                      Text(AppStrings.plusPriceLoading),
                    ],
                  ),
                )
              else ...[
                if (monthly != null && monthly.canPurchase)
                  PrimaryButton(
                    label: monthly.buttonLabel,
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : () => _purchase(widget.repository.purchaseMonthly),
                  ),
                if (yearly != null && yearly.canPurchase)
                  SecondaryButton(
                    label: yearly.buttonLabel,
                    onPressed: _busy
                        ? null
                        : () => _purchase(widget.repository.purchaseYearly),
                  ),
                if (monthly?.canPurchase != true && yearly?.canPurchase != true)
                  Text(AppStrings.plusPriceUnavailable, style: body),
                if (monthly?.canPurchase != true && yearly?.canPurchase != true)
                  TextButton(
                    onPressed: _busy ? null : _loadPrices,
                    child: const Text(AppStrings.plusRetryPrices),
                  ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: const Text(AppStrings.plusRestore),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(AppStrings.plusAutoRenew, style: body),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.plusCancelHow,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () =>
                        showLegalDocument(context, LegalDocument.terms),
                    child: const Text(AppStrings.plusTermsLink),
                  ),
                  TextButton(
                    onPressed: () =>
                        showLegalDocument(context, LegalDocument.privacy),
                    child: const Text(AppStrings.plusPrivacyLink),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
