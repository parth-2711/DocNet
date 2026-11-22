import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/app_lock_controller.dart';
import 'app_lock_screen.dart';

/// Wraps the application root to enforce biometric security.
/// Listens to Android / iOS application lifecycle events to lock the vault
/// whenever the user backgrounds or pauses the application.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final notifier = ref.read(appLockProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        notifier.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        notifier.onAppResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockProvider);
    final authState = ref.watch(authControllerProvider);
    final isAuthed = authState.status == AuthStatus.authenticated;
    final isBiometricsActive =
        isAuthed && (authState.userProfile?.biometricsEnabled ?? false);

    if (isBiometricsActive && lockState.isLocked) {
      return const AppLockScreen();
    }

    return widget.child;
  }
}
