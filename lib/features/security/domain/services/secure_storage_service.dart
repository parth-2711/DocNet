/// Interface for platform secure key storage (KEY-005, PRD.md Section 4).
///
/// Ensures document keys, vault wrapping keys, and device secrets are stored
/// using hardware-backed or OS-level security (Keystore, Keychain, DPAPI),
/// never in plain SharedPreferences, unencrypted SQLite, or plain files.
abstract class SecureStorageService {
  /// Writes a secret key/value securely.
  Future<void> write({required String key, required String value});

  /// Reads a secret value. Returns null if not found.
  Future<String?> read({required String key});

  /// Deletes a specific key.
  Future<void> delete({required String key});

  /// Checks if a key exists in secure storage.
  Future<bool> containsKey({required String key});

  /// Clears all keys belonging to FamilyVault in secure storage (e.g. on sign out / account reset).
  Future<void> deleteAll();
}
