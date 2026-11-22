import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:docnet/features/auth/data/repositories/mock_user_profile_repository.dart';
import 'package:docnet/features/auth/presentation/controllers/auth_controller.dart';

void main() {
  late MockAuthRepository authRepo;
  late MockUserProfileRepository profileRepo;
  late AuthController controller;

  setUp(() {
    authRepo = MockAuthRepository();
    profileRepo = MockUserProfileRepository();
    controller = AuthController(authRepo, profileRepo);
  });

  tearDown(() {
    authRepo.dispose();
  });

  group('AuthController Tests', () {
    test('Initial state is unauthenticated', () {
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
    });

    test('Successful sign in transitions to authenticated', () async {
      await controller.signIn(
        email: 'test@familyvault.app',
        password: 'Password123!',
      );

      expect(controller.state.status, equals(AuthStatus.authenticated));
      expect(controller.state.userProfile, isNotNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('Failed sign in sets error status and message', () async {
      await controller.signIn(
        email: 'test@familyvault.app',
        password: 'WrongPassword',
      );

      expect(controller.state.status, equals(AuthStatus.error));
      expect(
        controller.state.errorMessage,
        contains('Invalid email or password'),
      );
    });

    test('Registering new user marks onboardingCompleted as false', () async {
      await controller.register(
        email: 'newuser@familyvault.app',
        password: 'SafePassword999',
        displayName: 'New Member',
      );

      expect(controller.state.status, equals(AuthStatus.authenticated));
      expect(controller.state.userProfile?.onboardingCompleted, isFalse);

      // Completing onboarding updates profile
      await controller.completeOnboarding();
      expect(controller.state.userProfile?.onboardingCompleted, isTrue);
    });

    test('Sign out transitions to unauthenticated', () async {
      await controller.signIn(
        email: 'test@familyvault.app',
        password: 'Password123!',
      );
      expect(controller.state.status, equals(AuthStatus.authenticated));

      await controller.signOut();
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
      expect(controller.state.userProfile, isNull);
    });

    test(
      'deleteAccount wipes user profile, credentials, and transitions to unauthenticated',
      () async {
        await controller.signIn(
          email: 'test@familyvault.app',
          password: 'Password123!',
        );
        expect(controller.state.status, equals(AuthStatus.authenticated));
        final uid = authRepo.currentUid!;

        await controller.deleteAccount();
        expect(controller.state.status, equals(AuthStatus.unauthenticated));
        expect(controller.state.userProfile, isNull);
        expect(authRepo.currentUid, isNull);

        final profile = await profileRepo.getProfile(uid);
        expect(profile, isNull);
      },
    );

    test('resetPassword updates user credentials and allows sign in with new password', () async {
      await controller.resetPassword(
        email: 'test@familyvault.app',
        newPassword: 'BrandNewPassword123!',
      );

      // Old password should fail
      await controller.signIn(
        email: 'test@familyvault.app',
        password: 'Password123!',
      );
      expect(controller.state.status, equals(AuthStatus.error));

      // New password should succeed
      await controller.signIn(
        email: 'test@familyvault.app',
        password: 'BrandNewPassword123!',
      );
      expect(controller.state.status, equals(AuthStatus.authenticated));
    });

    test('resetPassword throws error for non-existent email', () async {
      expect(
        () => controller.resetPassword(
          email: 'unknown@familyvault.app',
          newPassword: 'BrandNewPassword123!',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
