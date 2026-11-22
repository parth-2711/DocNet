import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/auth/domain/entities/user_profile.dart';
import 'package:docnet/features/auth/presentation/controllers/auth_controller.dart';
import 'package:docnet/features/security/presentation/controllers/app_lock_controller.dart';
import 'package:docnet/features/security/presentation/widgets/app_lock_gate.dart';
import 'package:docnet/features/security/presentation/widgets/app_lock_screen.dart';

void main() {
  group('AppLockController Unit Tests', () {
    test('Initial lock state defaults to false in test environment', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final lockState = container.read(appLockProvider);
      expect(lockState.isLocked, isFalse);
      expect(lockState.isAuthenticating, isFalse);
    });

    test('Manual lock and unlock update state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      notifier.lock();
      // Only locks if biometrics is active; test active state via mock
      notifier.unlock();
      expect(container.read(appLockProvider).isLocked, isFalse);
    });

    test('Authenticate resolves cleanly in test environment', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      final result = await notifier.authenticate();
      expect(result, isTrue);
      expect(container.read(appLockProvider).isLocked, isFalse);
    });
  });

  group('AppLockGate & AppLockScreen Widget Tests', () {
    testWidgets('Renders child when biometrics is not enabled', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppLockGate(child: Scaffold(body: Text('Protected Content'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Content'), findsOneWidget);
      expect(find.byType(AppLockScreen), findsNothing);
    });

    testWidgets(
      'Renders AppLockScreen when user is authenticated with biometrics enabled and locked',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now().toUtc();
        final profileWithBio = UserProfile(
          uid: 'bio-test-uid',
          email: 'parth@example.com',
          displayName: 'Parth Godhani',
          biometricsEnabled: true,
          createdAt: now,
          updatedAt: now,
          onboardingCompleted: true,
        );

        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _MockBioAuthController(
                AuthState(
                  status: AuthStatus.authenticated,
                  userProfile: profileWithBio,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Manually trigger lock
        container.read(appLockProvider.notifier).state = const AppLockState(
          isLocked: true,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AppLockGate(
                child: Scaffold(body: Text('Protected Content')),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppLockScreen), findsOneWidget);
        expect(find.text('FamilyVault Locked'), findsOneWidget);
        expect(find.text('Unlock Vault'), findsOneWidget);
        expect(find.text('Protected Content'), findsNothing);
      },
    );

    testWidgets(
      'Tapping Unlock Vault on AppLockScreen calls authenticate and unlocks',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now().toUtc();
        final profileWithBio = UserProfile(
          uid: 'bio-test-uid',
          email: 'parth@example.com',
          displayName: 'Parth Godhani',
          biometricsEnabled: true,
          createdAt: now,
          updatedAt: now,
          onboardingCompleted: true,
        );

        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _MockBioAuthController(
                AuthState(
                  status: AuthStatus.authenticated,
                  userProfile: profileWithBio,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(appLockProvider.notifier).state = const AppLockState(
          isLocked: true,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AppLockGate(
                child: Scaffold(body: Text('Protected Content')),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Unlock Vault'), findsOneWidget);
        await tester.tap(find.text('Unlock Vault'));
        await tester.pumpAndSettle();

        // After unlock, protected content is visible
        expect(find.text('Protected Content'), findsOneWidget);
        expect(find.byType(AppLockScreen), findsNothing);
      },
    );
  });
}

class _MockBioAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _MockBioAuthController(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
