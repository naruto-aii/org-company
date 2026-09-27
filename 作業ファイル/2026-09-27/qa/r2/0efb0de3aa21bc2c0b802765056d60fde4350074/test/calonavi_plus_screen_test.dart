import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_screen.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_subscription_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plus screen shows store prices, renewal, and legal links', (
    tester,
  ) async {
    final repository = MockSubscriptionRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );

    expect(find.text(AppStrings.plusPriceLoading), findsOneWidget);
    expect(find.textContaining(r'US$2.99'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    await tester.pump();

    expect(find.text(AppStrings.plusTitle), findsOneWidget);
    expect(find.text('月額 US\$2.99'), findsOneWidget);
    expect(find.text('年額 US\$29.99'), findsOneWidget);
    expect(find.text(AppStrings.plusAutoRenew), findsOneWidget);
    expect(find.text(AppStrings.plusCancelHow), findsOneWidget);
    expect(find.text(AppStrings.plusTermsLink), findsOneWidget);
    expect(find.text(AppStrings.plusPrivacyLink), findsOneWidget);

    await tester.tap(find.text('月額 US\$2.99'));
    await tester.pumpAndSettle();

    expect(repository.monthlyCalled, isTrue);
    expect(repository.plus, isTrue);

    await repository.dispose();
  });

  testWidgets('failed prices hide purchase buttons and keep restore', (
    tester,
  ) async {
    final repository = MockSubscriptionRepository()
      ..offerings = SubscriptionOfferings.failed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.plusPriceUnavailable), findsOneWidget);
    expect(find.text(AppStrings.plusRetryPrices), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text(AppStrings.plusRestore), findsOneWidget);
    expect(find.text(AppStrings.plusAutoRenew), findsOneWidget);

    await tester.tap(find.text(AppStrings.plusRestore));
    await tester.pumpAndSettle();
    expect(repository.restoreCalled, isTrue);
    expect(repository.plus, isFalse);

    repository.offerings = const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: 'calonavi_plus_monthly',
        period: PlusBillingPeriod.month,
        localizedPrice: '¥480',
      ),
      yearly: null,
      loadFailed: false,
    );
    await tester.tap(find.text(AppStrings.plusRetryPrices));
    await tester.pump();

    expect(find.text('月額 ¥480'), findsOneWidget);
    expect(find.text(AppStrings.plusPriceUnavailable), findsNothing);

    await repository.dispose();
  });

  testWidgets('terms and privacy links open the in-app legal pages', (
    tester,
  ) async {
    final repository = MockSubscriptionRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text(AppStrings.plusTermsLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.plusTermsLink));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(LegalDocumentScreen),
        matching: find.byTooltip('閉じる'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.plusPrivacyLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.plusPrivacyLink));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.textContaining('プライバシー'), findsWidgets);

    await repository.dispose();
  });

  testWidgets('restore with nothing found shows a message', (tester) async {
    final repository = MockSubscriptionRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.plusRestore));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.plusRestoreEmpty), findsOneWidget);
    expect(find.text(AppStrings.plusTitle), findsOneWidget);
    expect(repository.plus, isFalse);

    await repository.dispose();
  });

  testWidgets('restore success and failure use fixed messages', (tester) async {
    final repository = MockSubscriptionRepository()..restoreGrantsPlus = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.plusRestore));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.plusRestoreSuccess), findsOneWidget);

    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    repository.restoreGrantsPlus = false;
    repository.restoreFails = true;
    repository.setPlus(false);
    await tester.ensureVisible(find.text(AppStrings.plusRestore));
    await tester.tap(find.text(AppStrings.plusRestore));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.plusRestoreFailed), findsOneWidget);
    expect(find.textContaining('SKError'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);

    await repository.dispose();
  });

  testWidgets('purchase failure hides the store error', (tester) async {
    final repository = MockSubscriptionRepository()
      ..purchaseError = SubscriptionPurchaseFailedException(
        'ASD: product unavailable',
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusScreen(repository: repository),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('月額 US\$2.99'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.plusPurchaseFailed), findsOneWidget);
    expect(find.textContaining('ASD'), findsNothing);
    expect(repository.plus, isFalse);

    await repository.dispose();
  });
}
