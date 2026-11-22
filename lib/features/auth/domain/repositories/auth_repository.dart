/// Authentication repository contract matching PRD.md AUTH requirements.
abstract class AuthRepository {
  /// Stream emitting the active user's UID or null on sign-out.
  Stream<String?> get authStateChanges;

  /// Current authenticated UID, or null if unauthenticated.
  String? get currentUid;

  /// Current authenticated user email, or null.
  String? get currentEmail => null;

  /// Current authenticated user display name, or null.
  String? get currentDisplayName => null;

  /// Signs in with email and password.
  Future<String> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registers a new user with email and password.
  Future<String> registerWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs in with Google account.
  Future<String> signInWithGoogle({
    String? googleEmail,
    String? googleDisplayName,
  });

  /// Signs out the active user and clears local session.
  Future<void> signOut();

  /// Permanently deletes the current authenticated user's account and session.
  Future<void> deleteAccount();

  /// Requests a password reset email.
  Future<void> sendPasswordResetEmail(String email);

  /// Resets a user's password.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  });
}
