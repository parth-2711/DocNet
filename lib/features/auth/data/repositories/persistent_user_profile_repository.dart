import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Persistent implementation of UserProfileRepository saving user settings and
/// profile information locally across app launches (DATABASE_SCHEMA.md Section 4).
class PersistentUserProfileRepository implements UserProfileRepository {
  final LocalVaultStorageService storageService;

  final Map<String, UserProfile> _profiles = {};
  bool _loaded = false;

  PersistentUserProfileRepository(this.storageService);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('profiles');
      if (data is Map<String, dynamic>) {
        data.forEach((uid, item) {
          if (item is Map<String, dynamic>) {
            _profiles[uid] = UserProfile.fromMap(item);
          }
        });
      }
    } catch (_) {
      // Ignore initial missing file
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final map = <String, dynamic>{};
    _profiles.forEach((uid, p) {
      map[uid] = p.toMap();
    });
    await storageService.saveJson('profiles', map);
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    await _ensureLoaded();
    return _profiles[uid];
  }

  @override
  Future<UserProfile?> getProfileByEmail(String email) async {
    await _ensureLoaded();
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
    await _ensureLoaded();
    _profiles[profile.uid] = profile;
    await _persist();
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
    await _ensureLoaded();
    final existing = _profiles[uid];
    if (existing != null) {
      _profiles[uid] = existing.copyWith(
        displayName: displayName,
        email: email,
        language: language,
        themeMode: themeMode,
        onboardingCompleted: onboardingCompleted,
        biometricsEnabled: biometricsEnabled,
        updatedAt: DateTime.now().toUtc(),
      );
      await _persist();
    }
  }

  @override
  Future<void> deleteProfile(String uid) async {
    await _ensureLoaded();
    _profiles.remove(uid);
    await _persist();
  }
}
