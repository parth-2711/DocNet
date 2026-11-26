import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:docnet/core/services/in_app_update_service.dart';
import 'package:docnet/core/widgets/app_update_gate.dart';
import 'package:docnet/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:docnet/features/auth/data/repositories/mock_user_profile_repository.dart';
import 'package:docnet/features/auth/presentation/controllers/auth_controller.dart';
import 'package:docnet/features/settings/presentation/settings_screen.dart';

class FakeAppUpdateClient implements AppUpdateClient {
  AppUpdateInfo Function()? onCheckForUpdate;
  Future<AppUpdateResult> Function()? onPerformImmediateUpdate;
  Future<AppUpdateResult> Function()? onStartFlexibleUpdate;
  Future<void> Function()? onCompleteFlexibleUpdate;
  final StreamController<InstallStatus> installStatusController =
      StreamController<InstallStatus>.broadcast();

  int checkCount = 0;
  int immediateCount = 0;
  int flexibleCount = 0;
  int completeFlexibleCount = 0;

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    checkCount++;
    if (onCheckForUpdate != null) {
      return onCheckForUpdate!();
    }
    return _makeInfo();
  }

  @override
  Future<AppUpdateResult> performImmediateUpdate() async {
    immediateCount++;
    if (onPerformImmediateUpdate != null) {
      return onPerformImmediateUpdate!();
    }
    return AppUpdateResult.success;
  }

  @override
  Future<AppUpdateResult> startFlexibleUpdate() async {
    flexibleCount++;
    if (onStartFlexibleUpdate != null) {
      return onStartFlexibleUpdate!();
    }
    return AppUpdateResult.success;
  }

  @override
  Future<void> completeFlexibleUpdate() async {
    completeFlexibleCount++;
    if (onCompleteFlexibleUpdate != null) {
      await onCompleteFlexibleUpdate!();
    }
  }

  @override
  Stream<InstallStatus> get installUpdateListener =>
      installStatusController.stream;

  void dispose() {
    installStatusController.close();
  }
}

AppUpdateInfo _makeInfo({
  UpdateAvailability availability = UpdateAvailability.updateNotAvailable,
  bool immediateAllowed = false,
  bool flexibleAllowed = false,
  int? availableVersionCode = 7,
  InstallStatus installStatus = InstallStatus.unknown,
  int updatePriority = 0,
  int? stalenessDays,
}) {
  return AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: immediateAllowed,
    immediateAllowedPreconditions: null,
    flexibleUpdateAllowed: flexibleAllowed,
    flexibleAllowedPreconditions: null,
    availableVersionCode: availableVersionCode,
    installStatus: installStatus,
    packageName: 'com.pgdeveloper.docnet',
    clientVersionStalenessDays: stalenessDays,
    updatePriority: updatePriority,
  );
}

void main() {
  group('AppUpdateController Unit Tests', () {
    late FakeAppUpdateClient client;

    setUp(() {
      client = FakeAppUpdateClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('Reports upToDate with friendly message when user-initiated', () async {
      client.onCheckForUpdate = () => _makeInfo(
        availability: UpdateAvailability.updateNotAvailable,
      );

      final controller = AppUpdateController(
        client: client,
        isAndroidOverride: true,
      );
      final result = await controller.checkForUpdate(userInitiated: true);

      expect(client.checkCount, 1);
      expect(result.status, AppUpdateStatus.upToDate);
      expect(result.message, contains('latest version'));
    });

    test('Uses immediate update when priority >= 4', () async {
      client.onCheckForUpdate = () => _makeInfo(
        availability: UpdateAvailability.updateAvailable,
        immediateAllowed: true,
        flexibleAllowed: true,
        updatePriority: 5,
      );
      client.onPerformImmediateUpdate = () async => AppUpdateResult.success;

      final controller = AppUpdateController(
        client: client,
        isAndroidOverride: true,
      );
      final result = await controller.checkForUpdate();

      expect(client.immediateCount, 1);
      expect(client.flexibleCount, 0);
      expect(result.status, AppUpdateStatus.upToDate);
    });

    test(
      'Starts flexible update, transitions to readyToInstall on downloaded event, and completes install',
      () async {
        client.onCheckForUpdate = () => _makeInfo(
          availability: UpdateAvailability.updateAvailable,
          immediateAllowed: false,
          flexibleAllowed: true,
          updatePriority: 1,
        );
        client.onStartFlexibleUpdate = () async {
          client.installStatusController.add(InstallStatus.downloading);
          client.installStatusController.add(InstallStatus.downloaded);
          return AppUpdateResult.success;
        };

        final controller = AppUpdateController(
          client: client,
          isAndroidOverride: true,
        );
        await controller.checkForUpdate();
        await Future<void>.delayed(Duration.zero);

        expect(client.flexibleCount, 1);
        expect(controller.state.status, AppUpdateStatus.readyToInstall);

        await controller.completeFlexibleUpdate();
        expect(client.completeFlexibleCount, 1);
        expect(controller.state.status, AppUpdateStatus.installing);
      },
    );

    test('Skips update calls cleanly on non-Android platforms', () async {
      final controller = AppUpdateController(
        client: client,
        isAndroidOverride: false,
      );
      final autoResult = await controller.checkForUpdate(userInitiated: false);
      expect(client.checkCount, 0);
      expect(autoResult.status, AppUpdateStatus.unsupported);
      expect(autoResult.message, isNull);

      final manualResult = await controller.checkForUpdate(userInitiated: true);
      expect(manualResult.status, AppUpdateStatus.unsupported);
      expect(manualResult.message, contains('Android'));
    });

    test(
      'Handles MissingPluginException silently in background and surfaces error on manual check',
      () async {
        client.onCheckForUpdate = () => throw MissingPluginException();

        final controller = AppUpdateController(
          client: client,
          isAndroidOverride: true,
        );
        final silent = await controller.checkForUpdate(userInitiated: false);
        expect(silent.status, AppUpdateStatus.idle);
        expect(silent.message, isNull);

        final manual = await controller.checkForUpdate(userInitiated: true);
        expect(manual.status, AppUpdateStatus.unsupported);
        expect(manual.message, isNotNull);
      },
    );
  });

  group('In-App Update UI Integration Tests', () {
    testWidgets(
      'AppUpdateGate displays restart banner when flexible update finishes downloading',
      (tester) async {
        final client = FakeAppUpdateClient();
        client.onCheckForUpdate = () => _makeInfo(
          availability: UpdateAvailability.updateAvailable,
          flexibleAllowed: true,
        );
        client.onStartFlexibleUpdate = () async {
          return AppUpdateResult.success;
        };

        addTearDown(client.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appUpdateClientProvider.overrideWithValue(client),
              appUpdateControllerProvider.overrideWith(
                (ref) => AppUpdateController(
                  client: client,
                  isAndroidOverride: true,
                ),
              ),
            ],
            child: const MaterialApp(
              home: AppUpdateGate(
                child: Scaffold(body: Center(child: Text('Home Content'))),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Update downloaded and ready to install'),
          findsOneWidget,
        );
        expect(find.text('Restart'), findsOneWidget);

        await tester.tap(find.text('Restart'));
        await tester.pumpAndSettle();

        expect(client.completeFlexibleCount, 1);
      },
    );

    testWidgets(
      'SettingsScreen renders Check for App Updates tile and displays check status',
      (tester) async {
        final mockAuth = MockAuthRepository();
        final mockProfile = MockUserProfileRepository();
        await mockAuth.signInWithEmailAndPassword(
          email: 'test@familyvault.app',
          password: 'Password123!',
        );

        final client = FakeAppUpdateClient()
          ..onCheckForUpdate = () => _makeInfo(
            availability: UpdateAvailability.updateNotAvailable,
          );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockAuth),
              userProfileRepositoryProvider.overrideWithValue(mockProfile),
              appUpdateClientProvider.overrideWithValue(client),
              appUpdateControllerProvider.overrideWith(
                (ref) => AppUpdateController(
                  client: client,
                  isAndroidOverride: true,
                ),
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final updateTile = find.text('Check for App Updates');
        await tester.scrollUntilVisible(
          updateTile,
          60.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(updateTile, findsOneWidget);

        await tester.tap(updateTile);
        await tester.pumpAndSettle();

        expect(client.checkCount, 1);
        expect(
          find.text('DocNet is already on the latest version.'),
          findsWidgets,
        );
      },
    );
  });
}
