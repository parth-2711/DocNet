import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// In-memory UserProfileRepository for local development and tests.
class MockUserProfileRepository implements UserProfileRepository {
  final Map<String, UserProfile> _profiles = {};

  @override
  Future<UserProfile?> getProfile(String uid) async {
    return _profiles[uid];
  }

  @override
  Future<UserProfile?> getProfileByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    for (final p in _profiles.values) {
      if (p.email?.trim().toLowerCase() == normalized) {
        return p;
      }
    }
    return null;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  Future<void> updatePreferences({
    required String uid,
    String? displayName,
    String? email,
    String? language,
    String? themeMode,
    bool? onboardingCompleted,
    bool? biometricsEnabled,
  }) async {
    final existing = _profiles[uid];
    if (existing != null) {
      _profiles[uid] = existing.copyWith(
        displayName: displayName,
        email: email,
        language: language,
        themeMode: themeMode,
        onboardingCompleted: onboardingCompleted,
        biometricsEnabled: biometricsEnabled,
      );
    }
  }

  @override
  Future<void> deleteProfile(String uid) async {
    _profiles.remove(uid);
  }
}
