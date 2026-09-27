import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_contact_config.dart';
import '../../constants/app_strings.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.supportEmail,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final String? supportEmail;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isDeleting = false;

  String get _contactEmail {
    return (widget.supportEmail ?? AppContactConfig.contactEmail).trim();
  }

  Future<void> _openMail() async {
    final email = _contactEmail;
    if (email.isEmpty) {
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': AppStrings.accountDeletionMailSubject},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.accountDeletionConfirmTitle),
          content: const Text(AppStrings.accountDeletionConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.accountDeletionExecute),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await widget.authenticationRepository.deleteOwnAccount();
      await widget.controller.logout(force: true);
    } on AccountDeletionUnavailableException {
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      await _showUnavailable();
    } on AccountDeletionFailedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('${AppStrings.accountDeletionFailed}。時間をおいて再度お試しください。'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _showUnavailable() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.settingsAccountDeletion),
          content: const Text(AppStrings.accountDeletionUnavailable),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            if (_contactEmail.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openMail();
                },
                child: const Text(AppStrings.settingsContactOperator),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsAccountDeletion)),
      body: SafeArea(
        child: AppContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(AppStrings.accountDeletionLead, style: body),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.accountDeletionRemoves,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('・食事・運動・体重などの個人の記録'),
                    const Text('・非公開の保存食品、テンプレート'),
                    const Text('・プロフィール、目標、Health から取り込んだ個人向けデータ'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.accountDeletionKeeps,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('・公開食品（作成者は「削除済みユーザー」。氏名やメールは載せません）'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.accountDeletionBilling,
                style: body?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: AppStrings.accountDeletionExecute,
                loading: _isDeleting,
                onPressed: _isDeleting ? null : _confirmAndDelete,
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: AppStrings.accountDeletionReadPolicy,
                onPressed: () =>
                    showLegalDocument(context, LegalDocument.accountDeletion),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
