import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../logging/app_logger.dart';

/// Abstraction over Play Store In-App Updates for clean testing and desktop/web safety.
abstract class AppUpdateClient {
  Future<AppUpdateInfo> checkForUpdate();
  Future<AppUpdateResult> performImmediateUpdate();
  Future<AppUpdateResult> startFlexibleUpdate();
  Future<void> completeFlexibleUpdate();
  Stream<InstallStatus> get installUpdateListener;
}

class PlayStoreAppUpdateClient implements AppUpdateClient {
  const PlayStoreAppUpdateClient();

  @override
  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  @override
  Future<AppUpdateResult> performImmediateUpdate() =>
      InAppUpdate.performImmediateUpdate();

  @override
  Future<AppUpdateResult> startFlexibleUpdate() =>
      InAppUpdate.startFlexibleUpdate();

  @override
  Future<void> completeFlexibleUpdate() =>
      InAppUpdate.completeFlexibleUpdate();

  @override
  Stream<InstallStatus> get installUpdateListener =>
      InAppUpdate.installUpdateListener;
}

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  installing,
  userDenied,
  unsupported,
  error,
}

class AppUpdateState {
  final AppUpdateStatus status;
  final int? availableVersionCode;
  final String? message;

  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.availableVersionCode,
    this.message,
  });

  bool get isBusy =>
      status == AppUpdateStatus.checking ||
      status == AppUpdateStatus.installing;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    int? availableVersionCode,
    bool clearVersionCode = false,
    String? message,
    bool clearMessage = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      availableVersionCode: clearVersionCode
          ? null
          : (availableVersionCode ?? this.availableVersionCode),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class AppUpdateController extends StateNotifier<AppUpdateState> {
  final AppUpdateClient _client;
  final bool? _isAndroidOverride;
  StreamSubscription<InstallStatus>? _installSub;

  AppUpdateController({
    required this._client,
    this._isAndroidOverride,
  }) : super(const AppUpdateState());

  bool get isSupportedPlatform =>
      _isAndroidOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  void _ensureInstallListener() {
    if (_installSub != null || !isSupportedPlatform) return;
    try {
      _installSub = _client.installUpdateListener.listen(
        (installStatus) {
          switch (installStatus) {
            case InstallStatus.pending:
            case InstallStatus.downloading:
              state = state.copyWith(
                status: AppUpdateStatus.downloading,
                message: 'Downloading update from Google Play...',
              );
              break;
            case InstallStatus.downloaded:
              if (state.status != AppUpdateStatus.installing) {
                state = state.copyWith(
                  status: AppUpdateStatus.readyToInstall,
                  message: 'Update downloaded. Restart to finish installing.',
                );
              }
              break;
            case InstallStatus.installing:
              state = state.copyWith(
                status: AppUpdateStatus.installing,
                message: 'Installing update...',
              );
              break;
            case InstallStatus.installed:
              state = state.copyWith(
                status: AppUpdateStatus.upToDate,
                clearVersionCode: true,
                message: 'DocNet is up to date.',
              );
              break;
            case InstallStatus.canceled:
              state = state.copyWith(
                status: AppUpdateStatus.userDenied,
                message: 'Update download cancelled.',
              );
              break;
            case InstallStatus.failed:
              state = state.copyWith(
                status: AppUpdateStatus.error,
                message: 'Update failed to download. Please try again later.',
              );
              break;
            case InstallStatus.unknown:
              break;
          }
        },
        onError: (Object error, StackTrace stack) {
          AppLogger.debug(
            'InAppUpdate',
            'Install listener error ignored: $error',
          );
        },
      );
    } on MissingPluginException {
      // Expected in test environments or unsupported hosts.
    } catch (e) {
      AppLogger.debug('InAppUpdate', 'Unable to attach install listener: $e');
    }
  }

  /// Checks Google Play for an available update and launches either an
  /// immediate flow (for high-priority / stale builds) or a flexible download.
  Future<AppUpdateState> checkForUpdate({bool userInitiated = false}) async {
    if (!isSupportedPlatform) {
      final next = AppUpdateState(
        status: AppUpdateStatus.unsupported,
        message: userInitiated
            ? 'In-app updates are only available on Android via Google Play.'
            : null,
      );
      state = next;
      return next;
    }

    if (state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading) {
      return state;
    }

    _ensureInstallListener();

    state = state.copyWith(
      status: AppUpdateStatus.checking,
      message: userInitiated ? 'Checking Google Play for updates...' : null,
      clearMessage: !userInitiated,
    );

    try {
      final info = await _client.checkForUpdate();

      // Resume or finalize an already-downloaded flexible update.
      if (info.installStatus == InstallStatus.downloaded) {
        state = state.copyWith(
          status: AppUpdateStatus.readyToInstall,
          availableVersionCode: info.availableVersionCode,
          message: 'Update downloaded. Restart to finish installing.',
        );
        if (userInitiated) {
          await completeFlexibleUpdate();
        }
        return state;
      }

      // Resume an interrupted immediate update if Play Core reports one in progress.
      if (info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          info.immediateUpdateAllowed) {
        final result = await _client.performImmediateUpdate();
        return _applyUpdateResult(result, isFlexible: false);
      }

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        state = state.copyWith(
          status: AppUpdateStatus.updateAvailable,
          availableVersionCode: info.availableVersionCode,
          message: 'A newer version of DocNet is available on Google Play.',
        );

        final isHighPriorityOrStale =
            info.updatePriority >= 4 || (info.clientVersionStalenessDays ?? 0) >= 7;

        if (info.immediateUpdateAllowed &&
            (isHighPriorityOrStale || !info.flexibleUpdateAllowed)) {
          final result = await _client.performImmediateUpdate();
          return _applyUpdateResult(result, isFlexible: false);
        }

        if (info.flexibleUpdateAllowed) {
          state = state.copyWith(
            status: AppUpdateStatus.downloading,
            message: 'Downloading update in the background...',
          );
          final result = await _client.startFlexibleUpdate();
          return _applyUpdateResult(result, isFlexible: true);
        }
      }

      state = AppUpdateState(
        status: AppUpdateStatus.upToDate,
        message: userInitiated ? 'DocNet is already on the latest version.' : null,
      );
      return state;
    } on MissingPluginException {
      state = AppUpdateState(
        status: userInitiated ? AppUpdateStatus.unsupported : AppUpdateStatus.idle,
        message: userInitiated
            ? 'In-app update service is not available on this device.'
            : null,
      );
      return state;
    } on PlatformException catch (e) {
      AppLogger.warn(
        'InAppUpdate',
        'Play Store checkForUpdate failed (${e.code}): ${e.message}',
      );
      state = AppUpdateState(
        status: userInitiated ? AppUpdateStatus.error : AppUpdateStatus.idle,
        message: userInitiated
            ? 'Could not check Google Play for updates. Ensure DocNet is installed from Google Play.'
            : null,
      );
      return state;
    } catch (e, stack) {
      AppLogger.error(
        'InAppUpdate',
        'Unexpected error checking for updates',
        error: e,
        stackTrace: stack,
      );
      state = AppUpdateState(
        status: userInitiated ? AppUpdateStatus.error : AppUpdateStatus.idle,
        message: userInitiated
            ? 'Failed to check for updates. Please try again later.'
            : null,
      );
      return state;
    }
  }

  AppUpdateState _applyUpdateResult(
    AppUpdateResult result, {
    required bool isFlexible,
  }) {
    switch (result) {
      case AppUpdateResult.success:
        if (isFlexible) {
          // On some devices/emulators startFlexibleUpdate completes only after download finishes.
          if (state.status == AppUpdateStatus.downloading) {
            state = state.copyWith(
              status: AppUpdateStatus.readyToInstall,
              message: 'Update downloaded. Restart to finish installing.',
            );
          }
        } else {
          state = state.copyWith(
            status: AppUpdateStatus.upToDate,
            clearVersionCode: true,
            message: 'DocNet has been updated.',
          );
        }
        break;
      case AppUpdateResult.userDeniedUpdate:
        state = state.copyWith(
          status: AppUpdateStatus.userDenied,
          message: 'Update postponed.',
        );
        break;
      case AppUpdateResult.inAppUpdateFailed:
        state = state.copyWith(
          status: AppUpdateStatus.error,
          message: 'Google Play could not complete the update.',
        );
        break;
    }
    return state;
  }

  /// Completes a downloaded flexible update by prompting Play Core to restart & install.
  Future<void> completeFlexibleUpdate() async {
    if (!isSupportedPlatform) return;
    state = state.copyWith(
      status: AppUpdateStatus.installing,
      message: 'Applying downloaded update...',
    );
    try {
      await _client.completeFlexibleUpdate();
    } catch (e, stack) {
      AppLogger.error(
        'InAppUpdate',
        'Failed to complete flexible update',
        error: e,
        stackTrace: stack,
      );
      state = state.copyWith(
        status: AppUpdateStatus.error,
        message: 'Could not restart to install update. Please try again.',
      );
    }
  }

  @override
  void dispose() {
    _installSub?.cancel();
    super.dispose();
  }
}

final appUpdateClientProvider = Provider<AppUpdateClient>(
  (ref) => const PlayStoreAppUpdateClient(),
);

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) {
      return AppUpdateController(
        client: ref.watch(appUpdateClientProvider),
      );
    });
