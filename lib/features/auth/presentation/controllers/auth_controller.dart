import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/persistent_user_profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/services/google_sign_in_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserProfile? userProfile;
  final String? errorMessage;

  const AuthState({required this.status, this.userProfile, this.errorMessage});

  const AuthState.initial()
    : status = AuthStatus.initial,
      userProfile = null,
      errorMessage = null;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      userProfile = null,
      errorMessage = null;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? userProfile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      userProfile: userProfile ?? this.userProfile,
      errorMessage: errorMessage,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return FirebaseAuthRepository(storageService);
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return PersistentUserProfileRepository(storageService);
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final profileRepo = ref.watch(userProfileRepositoryProvider);
    return AuthController(authRepo, profileRepo);
  },
);

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final UserProfileRepository _profileRepo;

  AuthController(this._authRepo, this._profileRepo)
    : super(const AuthState.unauthenticated()) {
    _init();
  }

  void _init() {
    if (_authRepo.currentUid != null) {
      _loadProfile(_authRepo.currentUid!);
    }
    _authRepo.authStateChanges.listen((uid) async {
      if (uid == null) {
        state = const AuthState.unauthenticated();
      } else {
        await _loadProfile(uid);
      }
    });
  }

  static String deriveDisplayName(String email) {
    if (!email.contains('@')) return 'User';
    final prefix = email.split('@').first;
    final parts = prefix.split(RegExp(r'[._\-]'));
    final formatted = parts
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : ''))
        .join(' ');
    return formatted.isNotEmpty ? formatted : 'User';
  }

  Future<void> _loadProfile(String uid) async {
    var profile = await _profileRepo.getProfile(uid);
    final activeEmail = _authRepo.currentEmail;
    final activeName = _authRepo.currentDisplayName;

    final isDummyEmail =
        profile?.email == null ||
        profile!.email!.isEmpty ||
        profile.email == 'user@familyvault.app' ||
        profile.email == 'google.user@familyvault.app' ||
        (profile.email?.endsWith('@familyvault.app') ?? false);

    final isDummyName =
        profile?.displayName == null ||
        profile!.displayName!.isEmpty ||
        profile.displayName == 'Vault User' ||
        profile.displayName == 'Google User' ||
        profile.displayName == 'Google Account User' ||
        profile.displayName == 'User';

    if (profile == null) {
      final now = DateTime.now().toUtc();
      final effectiveEmail = activeEmail ?? 'user@familyvault.app';
      final effectiveName =
          (activeName != null &&
              activeName != 'Vault User' &&
              activeName != 'Google User')
          ? activeName
          : deriveDisplayName(effectiveEmail);
      profile = UserProfile(
        uid: uid,
        email: effectiveEmail,
        displayName: effectiveName,
        createdAt: now,
        updatedAt: now,
        onboardingCompleted: true,
      );
      await _profileRepo.saveProfile(profile);
    } else if (isDummyEmail || isDummyName) {
      final effectiveEmail = (isDummyEmail && activeEmail != null)
          ? activeEmail
          : (profile.email ?? activeEmail ?? 'user@familyvault.app');
      final effectiveName =
          (isDummyName &&
              activeName != null &&
              activeName != 'Vault User' &&
              activeName != 'Google User')
          ? activeName
          : (isDummyName
                ? deriveDisplayName(effectiveEmail)
                : profile.displayName);

      profile = profile.copyWith(
        email: effectiveEmail,
        displayName: effectiveName,
      );
      await _profileRepo.saveProfile(profile);
    }
    state = AuthState(status: AuthStatus.authenticated, userProfile: profile);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final uid = await _authRepo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      var profile = await _profileRepo.getProfile(uid);
      final derivedName = deriveDisplayName(email);
      if (profile == null) {
        final now = DateTime.now().toUtc();
        profile = UserProfile(
          uid: uid,
          email: email,
          displayName: derivedName,
          createdAt: now,
          updatedAt: now,
          onboardingCompleted: true,
        );
        await _profileRepo.saveProfile(profile);
      } else {
        final isDummyEmail =
            profile.email == null ||
            profile.email!.isEmpty ||
            profile.email == 'user@familyvault.app' ||
            profile.email == 'google.user@familyvault.app' ||
            (profile.email?.endsWith('@familyvault.app') ?? false) ||
            profile.email != email;
        final isDummyName =
            profile.displayName == null ||
            profile.displayName!.isEmpty ||
            profile.displayName == 'Vault User' ||
            profile.displayName == 'Google User' ||
            profile.displayName == 'Google Account User';

        if (isDummyEmail || isDummyName) {
          profile = profile.copyWith(
            email: email,
            displayName: isDummyName ? derivedName : profile.displayName,
          );
          await _profileRepo.saveProfile(profile);
        }
      }
      state = AuthState(status: AuthStatus.authenticated, userProfile: profile);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final uid = await _authRepo.registerWithEmailAndPassword(
        email: email,
        password: password,
      );
      final now = DateTime.now().toUtc();
      final effectiveName =
          (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : deriveDisplayName(email);
      final profile = UserProfile(
        uid: uid,
        email: email,
        displayName: effectiveName,
        createdAt: now,
        updatedAt: now,
        onboardingCompleted: false, // New user needs recovery setup
      );
      await _profileRepo.saveProfile(profile);
      state = AuthState(status: AuthStatus.authenticated, userProfile: profile);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInWithGoogle({String? email, String? displayName}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final uid = await _authRepo.signInWithGoogle(
        googleEmail: email,
        googleDisplayName: displayName,
      );
      final googleMail =
          email ?? _authRepo.currentEmail ?? 'user@familyvault.app';
      final googleName =
          (displayName != null &&
              displayName.trim().isNotEmpty &&
              displayName != 'Google User' &&
              displayName != 'Google Account User')
          ? displayName.trim()
          : (_authRepo.currentDisplayName ?? deriveDisplayName(googleMail));

      var profile = await _profileRepo.getProfile(uid);
      if (profile == null) {
        final now = DateTime.now().toUtc();
        profile = UserProfile(
          uid: uid,
          email: googleMail,
          displayName: googleName,
          createdAt: now,
          updatedAt: now,
          onboardingCompleted: true,
        );
        await _profileRepo.saveProfile(profile);
      } else {
        final isDummy =
            profile.email == 'user@familyvault.app' ||
            profile.email == 'google.user@familyvault.app' ||
            (profile.email?.endsWith('@familyvault.app') ?? false) ||
            profile.email != googleMail ||
            profile.displayName == 'Vault User' ||
            profile.displayName == 'Google User' ||
            profile.displayName == 'Google Account User' ||
            profile.displayName == null;

        if (isDummy) {
          profile = profile.copyWith(
            email: googleMail,
            displayName: googleName,
          );
          await _profileRepo.saveProfile(profile);
        }
      }
      state = AuthState(status: AuthStatus.authenticated, userProfile: profile);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? language,
    String? themeMode,
    bool? biometricsEnabled,
  }) async {
    final current = state.userProfile;
    if (current == null) return;

    final updated = current.copyWith(
      displayName: displayName ?? current.displayName,
      email: email ?? current.email,
      language: language ?? current.language,
      themeMode: themeMode ?? current.themeMode,
      biometricsEnabled: biometricsEnabled ?? current.biometricsEnabled,
      updatedAt: DateTime.now().toUtc(),
    );
    await _profileRepo.saveProfile(updated);
    state = state.copyWith(userProfile: updated);
  }

  Future<void> completeOnboarding() async {
    final profile = state.userProfile;
    if (profile != null) {
      final updated = profile.copyWith(onboardingCompleted: true);
      await _profileRepo.saveProfile(updated);
      state = state.copyWith(userProfile: updated);
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignInService().signOut();
    } catch (_) {}
    await _authRepo.signOut();
    state = const AuthState.unauthenticated();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _authRepo.sendPasswordResetEmail(email);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('FormatException: ', ''),
      );
      rethrow;
    }
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _authRepo.resetPassword(email: email, newPassword: newPassword);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('FormatException: ', ''),
      );
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    final uid = _authRepo.currentUid;
    if (uid != null) {
      await _profileRepo.deleteProfile(uid);
      await _authRepo.deleteAccount();
      state = const AuthState.unauthenticated();
    }
  }
}
