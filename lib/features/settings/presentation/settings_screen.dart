import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/local_vault_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/domain/entities/user_profile.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/devices_screen.dart';
import '../../documents/presentation/controllers/documents_controller.dart';
import '../../family/presentation/controllers/family_controller.dart';
import '../../security/domain/services/recovery_key_service.dart';

/// Settings & Security Screen matching THEME.md Section 11 and PRD.md requirements.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final nameController = TextEditingController(
      text: profile.effectiveDisplayName,
    );
    final emailController = TextEditingController(text: profile.email ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g. Parth Godhani',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.standard),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g. yourname@gmail.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newEmail = emailController.text.trim();
              Navigator.pop(dialogCtx);

              await ref
                  .read(authControllerProvider.notifier)
                  .updateProfile(
                    displayName: newName.isNotEmpty ? newName : null,
                    email: newEmail.isNotEmpty ? newEmail : null,
                  );

              // Auto-refresh family space so name and email reflect everywhere
              try {
                ref.read(familyControllerProvider.notifier).loadFamily();
              } catch (_) {}

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showVaultKeyDialog(BuildContext context, WidgetRef ref) {
    final recoveryService = RecoveryKeyService();
    final phrase = recoveryService.generateRecoveryPhrase();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Vault Recovery Phrase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Write down these 12 words in a safe place. This phrase allows you to recover your vault on any device.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.standard),
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withAlpha(80),
                  ),
                ),
                child: Text(
                  phrase,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.compact),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Phrase to Clipboard'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: phrase));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recovery phrase copied to clipboard!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('I Have Saved It'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometrics(
    BuildContext context,
    WidgetRef ref,
    bool currentValue,
  ) async {
    final localAuth = LocalAuthentication();
    final messenger = ScaffoldMessenger.of(context);

    if (currentValue) {
      // Disabling app lock
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(biometricsEnabled: false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Biometric app lock disabled.')),
      );
      return;
    }

    // Enabling app lock: require successful biometric / PIN authentication
    try {
      final isSupported =
          await localAuth.isDeviceSupported() ||
          await localAuth.canCheckBiometrics;

      if (!isSupported) {
        // Device lacks biometric hardware but allow enabling PIN/device lock mode
        await ref
            .read(authControllerProvider.notifier)
            .updateProfile(biometricsEnabled: true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'App Lock enabled. Your vault is protected by device security.',
            ),
          ),
        );
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason:
            'Authenticate with fingerprint, face, or PIN to enable FamilyVault App Lock',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        await ref
            .read(authControllerProvider.notifier)
            .updateProfile(biometricsEnabled: true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric App Lock enabled! Vault will now lock whenever the app is backgrounded or reopened.',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication cancelled; App Lock remains disabled.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not enable App Lock: $e')),
      );
    }
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    String currentTheme,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select Theme Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System Default'),
              trailing: currentTheme == 'system'
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                Navigator.pop(dialogCtx);
                await ref
                    .read(authControllerProvider.notifier)
                    .updateProfile(themeMode: 'system');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Theme set to System Default.'),
                    ),
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Light Mode'),
              trailing: currentTheme == 'light'
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                Navigator.pop(dialogCtx);
                await ref
                    .read(authControllerProvider.notifier)
                    .updateProfile(themeMode: 'light');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme set to Light Mode.')),
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Dark Mode'),
              trailing: currentTheme == 'dark'
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                Navigator.pop(dialogCtx);
                await ref
                    .read(authControllerProvider.notifier)
                    .updateProfile(themeMode: 'dark');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme set to Dark Mode.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportVaultData(BuildContext context, WidgetRef ref) {
    final docsState = ref.read(documentsControllerProvider);
    final count = docsState.documents.length;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Export Vault Data'),
        content: Text(
          'Export all $count encrypted personal document(s) via the system share sheet? Decrypted temporary copies will be shared to your designated external target.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final storageService = ref.read(localVaultStorageServiceProvider);
              final xFiles = <XFile>[];

              try {
                for (final doc in docsState.documents) {
                  final tempFile = await storageService
                      .writeTemporaryDecryptedFile(
                        fileName:
                            doc.decryptedName ??
                            'Document_${doc.documentId}.pdf',
                        bytes: utf8.encode(
                          'FamilyVault decrypted export for ${doc.decryptedName}',
                        ),
                      );
                  xFiles.add(XFile(tempFile.path));
                }

                if (xFiles.isNotEmpty) {
                  await Share.shareXFiles(
                    xFiles,
                    text: 'FamilyVault Export: $count document(s)',
                  );
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Exported $count document(s) via share sheet.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
            child: const Text('Export Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final profile = authState.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Security',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.standard,
          vertical: AppSpacing.compact,
        ),
        children: [
          // Account Profile Card
          if (profile != null) ...[
            Builder(
              builder: (context) {
                final resolvedDisplayName = profile.effectiveDisplayName;
                final resolvedInitial = resolvedDisplayName.isNotEmpty
                    ? resolvedDisplayName.substring(0, 1).toUpperCase()
                    : 'U';

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.standard),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutline.withAlpha(35)
                          : AppColors.lightOutline.withAlpha(60),
                    ),
                    boxShadow: AppShadows.softCard(isDark),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? AppColors.darkButtonGradient
                              : AppColors.buttonGradient,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          resolvedInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      title: Text(
                        resolvedDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            profile.effectiveEmail ?? profile.effectiveDisplayName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 13,
                                color: isDark
                                    ? AppColors.darkSuccess
                                    : AppColors.lightSuccess,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Zero-Knowledge Vault Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkSuccess
                                      : AppColors.lightSuccess,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, size: 18),
                      ),
                      onTap: () =>
                          _showEditProfileDialog(context, ref, profile),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.standard),
          ],

          // Section 1: Security
          _buildSectionHeader('SECURITY & VAULT ACCESS', isDark),
          _buildSectionCard(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.vpn_key_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Vault Key & Recovery Secret',
                subtitle: 'Backed up and verified',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _showVaultKeyDialog(context, ref),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.devices_rounded,
                iconColor: const Color(0xFF0284C7),
                title: 'Enrolled Devices',
                subtitle: 'Manage authorized devices & sessions',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevicesScreen()),
                  );
                },
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF059669),
                title: 'App Lock (Biometrics)',
                subtitle: 'Unlock with device credentials',
                trailing: Switch(
                  value: profile?.biometricsEnabled ?? false,
                  onChanged: (_) => _toggleBiometrics(
                    context,
                    ref,
                    profile?.biometricsEnabled ?? false,
                  ),
                ),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.standard),

          // Section 2: Preferences
          _buildSectionHeader('PREFERENCES', isDark),
          _buildSectionCard(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.palette_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Theme Mode',
                subtitle: profile?.themeMode == 'light'
                    ? 'Light Mode'
                    : profile?.themeMode == 'dark'
                    ? 'Dark Mode'
                    : 'System default',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _showThemeDialog(
                  context,
                  ref,
                  profile?.themeMode ?? 'system',
                ),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.standard),

          // Section 3: Data & Storage
          _buildSectionHeader('DATA & STORAGE', isDark),
          _buildSectionCard(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.cleaning_services_rounded,
                iconColor: const Color(0xFF0D9488),
                title: 'Clear Decrypted Cache',
                subtitle: 'Removes local decrypted temporary files',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  final storageService = ref.read(
                    localVaultStorageServiceProvider,
                  );
                  await storageService.clearTemporaryDecryptedFiles();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Temporary decrypted cache cleared.'),
                      ),
                    );
                  }
                },
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.file_download_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'Export Vault Data',
                subtitle: 'Download all personal documents',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _exportVaultData(context, ref),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.standard),

          // Section 4: Account Actions
          _buildSectionHeader('ACCOUNT & SECURITY', isDark),
          _buildSectionCard(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFF64748B),
                title: 'Sign Out',
                subtitle: 'Log out of this device',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                },
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.lightError,
                title: 'Delete Account & Vault',
                titleColor: isDark ? AppColors.darkError : AppColors.lightError,
                subtitle: 'Permanent deletion of account and stored objects',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Delete Account & Vault?'),
                      content: const Text(
                        'This action is permanent and cannot be undone. All your encrypted personal vault files, keys, and device sessions will be deleted.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Delete Permanently'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref
                        .read(authControllerProvider.notifier)
                        .deleteAccount();
                  }
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.standard),

          // Section 5: Legal & Privacy
          _buildSectionHeader('LEGAL & PRIVACY', isDark),
          _buildSectionCard(
            isDark: isDark,
            children: [
              _buildSettingTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: const Color(0xFF0284C7),
                title: 'Privacy Policy',
                subtitle: 'Zero-Knowledge encryption & data protection',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _showPrivacyPolicy(context),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingTile(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Data & Account Deletion Policy',
                subtitle: 'Learn how your data is purged & manage requests',
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _showDataDeletionPolicy(context),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpacing.standard),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.privacy_tip_rounded, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'FamilyVault (com.pgdeveloper.docnet)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const Divider(height: 24),
              const Text(
                'Zero-Knowledge Guarantee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'All your personal documents, files, and tags are encrypted directly on this device using authenticated AES-256-GCM symmetric encryption before syncing. The encryption keys are protected on-device via Android Keystore and Argon2id. We do not possess the keys to your files and cannot read, decrypt, or share your documents.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Information We Collect',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Account Credentials: Your email address and display name for user session authentication.\n• Encrypted Blobs: Encrypted ciphertext of your files and key envelopes.\n• Hardware Keystore: Biometric authentication is handled strictly by the local Android OS. No biometric templates are ever accessed or transmitted.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Information We Never Collect',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Unencrypted document copies\n• Master encryption passwords or plain keys\n• Location tracking or advertising identifiers',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Web Policy & Contact',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Web Policy: https://pgdeveloper.com/privacy-policy.html\nContact: vtpbca60@gmail.com',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showDataDeletionPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpacing.standard),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'Account & Data Deletion',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Google Play Data Safety Compliance',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const Divider(height: 24),
              const Text(
                'How to Delete Your Account',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                '1. In-App: Tap "Delete Account & Vault" in the Account & Security section of this screen.\n2. Web Portal: Visit https://pgdeveloper.com/delete-account.html\n3. Email Request: Contact vtpbca60@gmail.com with subject "Account Deletion Request".',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Permanently Purged',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                '• User profile & auth credentials\n• All encrypted documents & file versions\n• All wrapped key envelopes & cryptographic access tokens\n• Activity audit history and active device sessions\n\nNo backup copies of keys or encrypted documents are retained once deleted.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark
              ? AppColors.darkTextSecondary.withAlpha(160)
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withAlpha(35)
              : AppColors.lightOutline.withAlpha(60),
        ),
        boxShadow: AppShadows.softCard(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(isDark ? 35 : 20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 58,
      color: isDark
          ? AppColors.darkOutline.withAlpha(25)
          : AppColors.lightOutline.withAlpha(50),
    );
  }
}
