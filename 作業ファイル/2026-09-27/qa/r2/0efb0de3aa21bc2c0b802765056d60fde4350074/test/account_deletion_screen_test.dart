import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/settings/account_deletion_screen.dart';
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
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
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

  testWidgets('settings opens in-app account deletion', (tester) async {
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

    await tester.scrollUntilVisible(
      find.text(AppStrings.settingsAccountDeletion),
      200,
    );
    await tester.tap(find.text(AppStrings.settingsAccountDeletion));
    await tester.pumpAndSettle();

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect(find.text(AppStrings.accountDeletionExecute), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('confirmed deletion calls repository then logs out', (
    tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountDeletionScreen(
          controller: controller,
          authenticationRepository: authRepository,
          supportEmail: 'calonavi.ayg.support@gmail.com',
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountDeletionExecute).last);
    await tester.pumpAndSettle();

    expect(authRepository.deleteOwnAccountCalled, isTrue);
    expect(authRepository.logoutCalled, isTrue);

    await authRepository.dispose();
  });

  testWidgets('missing RPC offers email fallback', (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    )..simulateDeleteUnavailable = true;
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountDeletionScreen(
          controller: controller,
          authenticationRepository: authRepository,
          supportEmail: 'calonavi.ayg.support@gmail.com',
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountDeletionExecute).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.accountDeletionUnavailable), findsOneWidget);
    expect(authRepository.logoutCalled, isFalse);

    await authRepository.dispose();
  });

  testWidgets('deletion failure shows the fixed Japanese message', (
    tester,
  ) async {
    const raw = 'invalid_grant raw-token-body';
    final authRepository =
        MockAuthenticationRepository(
            currentUser: const AuthUser(
              id: 'user-1',
              email: 'test@example.com',
            ),
          )
          ..simulateDeleteFailure = true
          ..deleteFailureMessage = raw;
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountDeletionScreen(
          controller: controller,
          authenticationRepository: authRepository,
          supportEmail: 'calonavi.ayg.support@gmail.com',
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountDeletionExecute).last);
    await tester.pumpAndSettle();

    expect(
      find.text('${AppStrings.accountDeletionFailed}。時間をおいて再度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining(raw), findsNothing);
    expect(find.textContaining('invalid_grant'), findsNothing);
    expect(authRepository.logoutCalled, isFalse);

    await authRepository.dispose();
  });
}
