import '../entities/user_profile.dart';

/// User profile repository contract (DATABASE_SCHEMA.md Section 4).
abstract class UserProfileRepository {
  /// Retrieves a user profile by UID.
  Future<UserProfile?> getProfile(String uid);

  /// Retrieves a user profile by email address.
  Future<UserProfile?> getProfileByEmail(String email);

  /// Saves or updates the entire profile.
  Future<void> saveProfile(UserProfile profile);

  /// Updates specific user preferences.
  Future<void> updatePreferences({
    required String uid,
    String? displayName,
    String? email,
    String? language,
    String? themeMode,
    bool? onboardingCompleted,
    bool? biometricsEnabled,
  });

  /// Permanently deletes a user profile.
  Future<void> deleteProfile(String uid);
}
