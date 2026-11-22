import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../activity/domain/entities/activity_event.dart';
import '../../activity/presentation/controllers/activity_controller.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/services/recovery_key_service.dart';

/// Key and Recovery Onboarding Screen matching PRD.md KEY-001, KEY-002, KEY-003.
class RecoverySetupScreen extends ConsumerStatefulWidget {
  const RecoverySetupScreen({super.key});

  @override
  ConsumerState<RecoverySetupScreen> createState() =>
      _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends ConsumerState<RecoverySetupScreen> {
  final RecoveryKeyService _recoveryService = RecoveryKeyService();
  String? _generatedPhrase;
  bool _confirmedSaved = false;

  @override
  void initState() {
    super.initState();
    _generatedPhrase = _recoveryService.generateRecoveryPhrase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final words = _generatedPhrase?.split(' ') ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Vault Recovery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warning banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkWarning.withAlpha(25)
                      : AppColors.lightWarning.withAlpha(25),
                  borderRadius: AppRadius.inputBorderRadius,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkWarning
                        : AppColors.lightWarning,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: isDark
                          ? AppColors.darkWarning
                          : AppColors.lightWarning,
                    ),
                    const SizedBox(width: AppSpacing.standard),
                    Expanded(
                      child: Text(
                        'FamilyVault uses zero-knowledge encryption. If you lose all your devices and your recovery secret, your encrypted documents cannot be restored by support.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkWarning
                              : AppColors.lightWarning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.large),

              Text(
                'Your Master Recovery Phrase',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                'Write down these 12 words in order and store them in a secure place.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.standard),

              // Word grid
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: AppRadius.inputBorderRadius,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline
                        : AppColors.lightOutline,
                  ),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${index + 1}. ${words[index]}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.large),

              // Confirmation checkbox
              CheckboxListTile(
                value: _confirmedSaved,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'I have recorded my 12-word recovery phrase safely.',
                  style: theme.textTheme.bodyMedium,
                ),
                onChanged: (val) {
                  setState(() {
                    _confirmedSaved = val ?? false;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.standard),

              // Complete setup button
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete Vault Setup'),
                onPressed: _confirmedSaved
                    ? () async {
                        final auth = ref.read(authControllerProvider);
                        final uid = auth.userProfile?.uid ?? 'local-user';
                        await ref
                            .read(activityRepositoryProvider)
                            .logEvent(
                              ActivityEvent(
                                activityId: const Uuid().v4(),
                                actorUid: uid,
                                eventType:
                                    ActivityEventType.recoveryPhraseVerified,
                                summary:
                                    '12-word recovery phrase confirmed and stored',
                                timestamp: DateTime.now().toUtc(),
                              ),
                            );
                        await ref
                            .read(authControllerProvider.notifier)
                            .completeOnboarding();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
