import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/local_vault_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_update_gate.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/security/presentation/widgets/app_lock_gate.dart';
import 'routing/app_router.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  final authState = ref.watch(authControllerProvider);
  final modeStr = authState.userProfile?.themeMode;
  if (modeStr == 'light') return ThemeMode.light;
  if (modeStr == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Main', 'Initializing ${AppConstants.appName} application');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Main', 'Firebase initialized successfully');
  } catch (e, stack) {
    AppLogger.error(
      'Main',
      'Firebase initialization skipped or failed: $e',
      error: e,
      stackTrace: stack,
    );
  }

  final storageService = LocalVaultStorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        localVaultStorageServiceProvider.overrideWithValue(storageService),
      ],
      child: const FamilyVaultApp(),
    ),
  );
}

class FamilyVaultApp extends ConsumerWidget {
  const FamilyVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => AppLockGate(
        child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
