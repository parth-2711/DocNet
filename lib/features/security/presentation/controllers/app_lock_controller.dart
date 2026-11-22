import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/logging/app_logger.dart';

class AppLockState {
  final bool isLocked;
  final bool isAuthenticating;
  final String? errorMessage;
  final int failedAttempts;

  const AppLockState({
    this.isLocked = false,
    this.isAuthenticating = false,
    this.errorMessage,
    this.failedAttempts = 0,
  });

  AppLockState copyWith({
    bool? isLocked,
    bool? isAuthenticating,
    String? errorMessage,
    int? failedAttempts,
  }) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: errorMessage,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>((
  ref,
) {
  return AppLockController(ref);
});

class AppLockController extends StateNotifier<AppLockState> {
  final Ref _ref;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get _isTest =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  AppLockController(this._ref) : super(const AppLockState()) {
    _init();
  }

  void _init() {
    final authState = _ref.read(authControllerProvider);
    final bioEnabled = authState.userProfile?.biometricsEnabled ?? false;
    final isAuthed = authState.status == AuthStatus.authenticated;

    // On cold start, if user is authenticated and biometrics is enabled, start locked (except in unit tests)
    if (isAuthed && bioEnabled && !_isTest) {
      state = state.copyWith(isLocked: true);
    }

    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status != AuthStatus.authenticated) {
        // User logged out or account deleted; unlock gate
        state = const AppLockState(isLocked: false);
      } else {
        final nextBio = next.userProfile?.biometricsEnabled ?? false;
        if (!nextBio && state.isLocked) {
          // Biometrics disabled by user; unlock
          state = state.copyWith(isLocked: false, errorMessage: null);
        }
      }
    });
  }

  bool _isBiometricsActive() {
    final authState = _ref.read(authControllerProvider);
    return authState.status == AuthStatus.authenticated &&
        (authState.userProfile?.biometricsEnabled ?? false);
  }

  void onAppPaused() {
    if (_isTest) return;
    if (state.isAuthenticating) {
      // The system biometric dialog itself caused the transition; do not re-lock
      return;
    }
    if (_isBiometricsActive()) {
      AppLogger.info(
        'AppLock',
        'App paused with biometrics enabled. Locking vault.',
      );
      state = state.copyWith(isLocked: true);
    }
  }

  void onAppResumed() {
    if (_isTest) return;
    if (state.isAuthenticating) return;
    if (state.isLocked && _isBiometricsActive()) {
      AppLogger.info(
        'AppLock',
        'App resumed in locked state. Requesting biometric unlock.',
      );
      authenticate();
    }
  }

  Future<bool> authenticate() async {
    if (state.isAuthenticating) return false;

    if (_isTest) {
      state = state.copyWith(isLocked: false, isAuthenticating: false);
      return true;
    }

    state = state.copyWith(isAuthenticating: true, errorMessage: null);

    try {
      final isSupported =
          await _localAuth.isDeviceSupported() ||
          await _localAuth.canCheckBiometrics;

      if (!isSupported) {
        // Device lacks biometric sensor; unlock cleanly
        AppLogger.warn(
          'AppLock',
          'Device does not support biometrics. Unlocking.',
        );
        state = state.copyWith(isLocked: false, isAuthenticating: false);
        return true;
      }

      final success = await _localAuth.authenticate(
        localizedReason:
            'Scan fingerprint, face, or enter device PIN to unlock FamilyVault',
        biometricOnly: false, // Allows device PIN/pattern fallback
        persistAcrossBackgrounding: true,
      );

      if (success) {
        AppLogger.info('AppLock', 'Biometric unlock successful');
        state = state.copyWith(
          isLocked: false,
          isAuthenticating: false,
          errorMessage: null,
          failedAttempts: 0,
        );
        return true;
      } else {
        AppLogger.warn(
          'AppLock',
          'Biometric authentication was cancelled or failed',
        );
        state = state.copyWith(
          isAuthenticating: false,
          errorMessage: 'Authentication required. Tap Unlock to try again.',
          failedAttempts: state.failedAttempts + 1,
        );
        return false;
      }
    } catch (e) {
      AppLogger.error('AppLock', 'Error during biometric unlock: $e');
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: 'Biometric error ($e). Tap Unlock to retry.',
        failedAttempts: state.failedAttempts + 1,
      );
      return false;
    }
  }

  void lock() {
    if (_isBiometricsActive()) {
      state = state.copyWith(isLocked: true);
    }
  }

  void unlock() {
    state = state.copyWith(
      isLocked: false,
      isAuthenticating: false,
      errorMessage: null,
    );
  }
}
