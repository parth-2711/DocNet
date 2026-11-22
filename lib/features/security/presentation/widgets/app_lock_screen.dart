import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/app_lock_controller.dart';

/// Full-screen high-security biometric lock gate for FamilyVault.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    // On real devices, auto-prompt biometric dialog as soon as lock screen opens
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(appLockProvider.notifier).authenticate();
        }
      });
    }
  }

  void _showSignOutConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out of FamilyVault?'),
        content: const Text(
          'Signing out will clear the current active session. You will need your account password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightError,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lockState = ref.watch(appLockProvider);
    final authState = ref.watch(authControllerProvider);
    final profile = authState.userProfile;
    final displayName = profile?.effectiveDisplayName ?? 'User';

    return PopScope(
      canPop: false, // Cannot bypass lock with back button
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.authBackgroundGradientDark
                : AppColors.authBackgroundGradientLight,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.large,
                  vertical: AppSpacing.standard,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Lock Shield Emblem
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? AppColors.darkButtonGradient
                                : AppColors.buttonGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isDark
                                            ? AppColors.darkPrimary
                                            : AppColors.lightPrimary)
                                        .withAlpha(isDark ? 80 : 50),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                size: 52,
                                color: Colors.white.withAlpha(240),
                              ),
                              const Icon(
                                Icons.lock_rounded,
                                size: 24,
                                color: Color(0xFF183653),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),

                      // Title
                      Text(
                        'FamilyVault Locked',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Welcome back, $displayName.\nAuthenticate with fingerprint, face, or PIN to unlock.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),

                      // Error Banner if needed
                      if (lockState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppColors.darkError
                                        : AppColors.lightError)
                                    .withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (isDark
                                          ? AppColors.darkError
                                          : AppColors.lightError)
                                      .withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lockState.errorMessage!,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkError
                                        : AppColors.lightError,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.standard),
                      ],

                      // Unlock Action Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          key: const ValueKey('app_lock_unlock_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                            foregroundColor: isDark
                                ? const Color(0xFF0C1929)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: lockState.isAuthenticating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.fingerprint_rounded, size: 24),
                          label: Text(
                            lockState.isAuthenticating
                                ? 'Authenticating...'
                                : 'Unlock Vault',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: lockState.isAuthenticating
                              ? null
                              : () {
                                  ref
                                      .read(appLockProvider.notifier)
                                      .authenticate();
                                },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.standard),

                      // Sign Out Option
                      TextButton(
                        onPressed: _showSignOutConfirmDialog,
                        child: Text(
                          'Switch Account or Sign Out',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),

                      // Security reassurance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color:
                                (isDark
                                        ? AppColors.darkSuccess
                                        : AppColors.lightSuccess)
                                    .withAlpha(180),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Hardware-Backed Biometric Security',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
