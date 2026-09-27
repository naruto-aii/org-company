import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/legal/legal_document.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final referenceDate = DateTime(2026, 7, 21);

  AppController createController({
    required MockAuthenticationRepository authRepository,
  }) {
    final healthRepository = MockHealthRepository(isAvailable: false);
    final controller = AppController(
      healthRepository: healthRepository,
      authenticationRepository: authRepository,
    );
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 75,
        targetDate: referenceDate.add(const Duration(days: 90)),
      ),
    );
    return controller;
  }

  testWidgets('settings opens terms in a full-screen sheet with close', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          hideHealthSettings: true,
          supportEmail: 'calonavi.ayg.support@gmail.com',
        ),
      ),
    );

    await tester.ensureVisible(find.text('利用規約'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('利用規約'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('利用規約'), findsWidgets);
    expect(find.byTooltip('閉じる'), findsOneWidget);
    expect(find.textContaining('ログインした時点で'), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);
    expect(find.textContaining('24歳'), findsNothing);

    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsNothing);
    expect(find.text(AppStrings.settingsContactOperator), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('legal document screen renders privacy from assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.privacy),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.textContaining('Apple Health'), findsOneWidget);
    expect(find.textContaining('アクティブエネルギー'), findsOneWidget);
    expect(find.textContaining('ユーザーID'), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);
    expect(find.textContaining('【公表日：社長確認後に記入】'), findsWidgets);
    expect(find.textContaining('ソースには書かれていない'), findsNothing);
    expect(find.textContaining('Health Connect'), findsNothing);
    expect(find.textContaining('更新用トークンを保存していないログイン'), findsOneWidget);
    expect(find.textContaining('認可コードを保存していないログイン'), findsNothing);
    expect(
      find.textContaining('Google アカウントの氏名とプロフィール画像の URL'),
      findsOneWidget,
    );
    expect(find.textContaining('アカウントの削除が完了したときに消去する'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('有料プランへ最初に切り替えた日時を集計'),
      300,
    );
    expect(find.textContaining('有料プランへ最初に切り替えた日時を集計'), findsOneWidget);
    expect(find.textContaining('個別に勧誘を送ったりすることはありません'), findsOneWidget);
    expect(find.textContaining('製品改善のため'), findsNothing);
    expect(find.textContaining('歩数'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('【国名：社長確認後に記入】'), 300);
    expect(find.textContaining('【国名：社長確認後に記入】'), findsWidgets);
    expect(find.textContaining('Supabase'), findsWidgets);
    expect(find.textContaining('確認が終わるまで委託先とは記載しません'), findsNothing);
    expect(find.textContaining('国名を記入したあと'), findsNothing);
    expect(find.textContaining('【運営主体と所在国：社長確認後に記入】'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('フランス法（1901年7月1日法）'),
      300,
    );
    expect(find.textContaining('フランス法（1901年7月1日法）'), findsOneWidget);
    expect(
      find.textContaining('https://world.openfoodfacts.org/privacy'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('【その国の制度を踏まえた措置：社長確認後に記入】'),
      300,
    );
    expect(find.textContaining('【その国の制度を踏まえた措置：社長確認後に記入】'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('アカウントに紐づく公開食品への評価、通報、ブロック'),
      300,
    );
    expect(
      find.textContaining('アカウントに紐づく公開食品への評価、通報、ブロックは、アカウント削除時に削除します'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('【バックアップの保持日数：社長確認後に記入】'),
      300,
    );
    expect(find.textContaining('【バックアップの保持日数：社長確認後に記入】'), findsOneWidget);
    expect(find.textContaining('最初に切り替えた日時'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('トークンが残ることがあります'), 300);
    expect(find.textContaining('トークンが残ることがあります'), findsOneWidget);
    expect(find.textContaining('トークンの行が残ることがあります'), findsNothing);
    expect(find.textContaining('連携解除の通信は行いません'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('【手数料：社長確認後に記入】'), 300);
    expect(find.textContaining('【手数料：社長確認後に記入】'), findsOneWidget);
    expect(find.textContaining('24歳'), findsNothing);
    expect(find.textContaining('Web 版'), findsNothing);
    expect(find.byTooltip('閉じる'), findsOneWidget);
  });

  testWidgets('tokushoho screen renders from assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.tokushoho),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('特定商取引法に基づく表記'), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);
    expect(find.textContaining('アプリ内課金'), findsOneWidget);
    expect(find.textContaining('購入画面に表示される価格'), findsOneWidget);
    expect(find.textContaining('380'), findsNothing);
    expect(find.textContaining('4,180'), findsNothing);
    expect(find.byTooltip('閉じる'), findsOneWidget);
  });

  testWidgets('account deletion screen renders in-app steps from assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.accountDeletion),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除'), findsOneWidget);
    expect(find.textContaining('最終更新日: 2026-09-27'), findsOneWidget);
    expect(find.textContaining('アプリ内からの削除'), findsOneWidget);
    expect(find.textContaining('アカウント情報（メールアドレス等）と利用状況の記録'), findsOneWidget);
    expect(find.textContaining('Sign in with Apple の更新用トークン'), findsOneWidget);
    expect(find.textContaining('トークンが残ることがあります'), findsOneWidget);
    expect(find.textContaining('その行が残ることがあります'), findsNothing);
    expect(find.textContaining('Apple 側の連携を解除しません'), findsOneWidget);
    expect(find.textContaining('設定 > Apple ID > サインインとセキュリティ'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('公開食品'), 300);
    expect(find.textContaining('公開食品'), findsOneWidget);
    expect(find.textContaining('削除済みユーザー'), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget);
  });
}
