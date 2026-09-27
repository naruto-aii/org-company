import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_contact_config.dart';
import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';
import '../subscription/calonavi_plus_screen.dart';
import 'account_deletion_screen.dart';
import 'calculation_references_screen.dart';
import 'settings_basic_info_screen.dart';
import 'settings_food_master_screen.dart';
import 'settings_goal_screen.dart';
import 'settings_health_activity_screen.dart';

/// 設定。
///
/// Figma: SP / 10 設定（24:345）
///
/// Figma にない「特定商取引法に基づく表記」「サポート」も、ストア審査で
/// 到達できる必要があるため同じ行で並べてある。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.healthRepository,
    this.openFoodFactsService,
    this.hideHealthSettings = false,
    this.supportEmail,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository? healthRepository;
  final OpenFoodFactsService? openFoodFactsService;
  final bool hideHealthSettings;
  final String? supportEmail;

  static const double _rowGap = 8;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $url')));
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final email = authenticationRepository.currentUser?.email;
    final contactEmail = (supportEmail ?? AppContactConfig.contactEmail).trim();
    final health = healthRepository;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => DesignPage(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Text('設定', style: AppTypography.headingL),
            const SizedBox(height: 4),
            Text(
              'あなたに合った使い方で、\nカロナビをもっと便利に。',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            SettingsRow(
              icon: AppIcons.user,
              title: 'ログイン中',
              subtitle: email ?? 'アカウント情報の確認・変更',
              showChevron: false,
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.information,
              title: AppStrings.settingsBasicInfo,
              subtitle: '年齢・性別・身長・体重など',
              onTap: () => _push(
                context,
                SettingsBasicInfoScreen(controller: controller),
              ),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.goal,
              title: AppStrings.settingsGoal,
              subtitle: '目標体重・目標カロリーなど',
              onTap: () =>
                  _push(context, SettingsGoalScreen(controller: controller)),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.exercise,
              title: '活動・Health',
              subtitle: hideHealthSettings
                  ? AppStrings.webHealthUnavailable
                  : '運動・歩数・ヘルスケア連携の設定',
              onTap: hideHealthSettings || health == null
                  ? null
                  : () => _push(
                      context,
                      SettingsHealthActivityScreen(
                        controller: controller,
                        healthRepository: health,
                      ),
                    ),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.meal,
              title: 'マイ食品',
              subtitle: 'よく食べる食品の登録・管理',
              onTap: () => _push(
                context,
                SettingsFoodMasterScreen(
                  controller: controller,
                  openFoodFactsService: openFoodFactsService,
                ),
              ),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.calculator,
              title: '計算根拠',
              subtitle: 'カロリー・栄養素の算出方法について',
              onTap: () => _push(context, const CalculationReferencesScreen()),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.calorie,
              title: AppStrings.plusTitle,
              subtitle: controller.isCalonaviPlusActive
                  ? AppStrings.plusActive
                  : AppStrings.plusInactive,
              onTap: () =>
                  showCalonaviPlus(context, controller.subscriptionRepository),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.document,
              title: '利用規約',
              subtitle: 'サービスのご利用条件',
              onTap: () => showLegalDocument(context, LegalDocument.terms),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.shield,
              title: 'プライバシー',
              subtitle: '個人情報の取り扱いについて',
              onTap: () => showLegalDocument(context, LegalDocument.privacy),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.document,
              title: AppStrings.settingsTokushoho,
              subtitle: '販売条件・事業者情報',
              onTap: () => showLegalDocument(context, LegalDocument.tokushoho),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.information,
              title: AppStrings.settingsSupport,
              subtitle: '使い方・よくある質問',
              onTap: () => showLegalDocument(context, LegalDocument.support),
            ),
            if (contactEmail.isNotEmpty) ...[
              const SizedBox(height: _rowGap),
              SettingsRow(
                icon: AppIcons.mail,
                title: AppStrings.settingsContactOperator,
                subtitle: contactEmail,
                onTap: () => _openUrl(context, 'mailto:$contactEmail'),
              ),
            ],
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.logout,
              title: AppStrings.settingsLogout,
              subtitle: '別のアカウントで利用する場合はこちら',
              danger: true,
              onTap: () => controller.logout(),
            ),
            const SizedBox(height: _rowGap),
            SettingsRow(
              icon: AppIcons.trash,
              title: AppStrings.settingsAccountDeletion,
              subtitle: AppStrings.settingsAccountDeletionSubtitle,
              danger: true,
              onTap: () => _push(
                context,
                AccountDeletionScreen(
                  controller: controller,
                  authenticationRepository: authenticationRepository,
                  supportEmail: contactEmail,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
