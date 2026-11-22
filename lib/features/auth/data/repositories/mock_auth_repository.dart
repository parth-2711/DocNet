import 'dart:async';
import '../../domain/repositories/auth_repository.dart';

/// In-memory AuthRepository implementation for local development, testing, and platform verification.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<String?>.broadcast();
  String? _currentUid;
  String? _currentEmail;
  String? _currentDisplayName;

  final Map<String, String> _users = {'test@familyvault.app': 'Password123!'};

  @override
  Stream<String?> get authStateChanges => _controller.stream;

  @override
  String? get currentUid => _currentUid;

  @override
  String? get currentEmail => _currentEmail;

  @override
  String? get currentDisplayName => _currentDisplayName;

  @override
  Future<String> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!_users.containsKey(normalized) || _users[normalized] != password) {
      throw const FormatException('Invalid email or password');
    }
    _currentUid = 'uid-${normalized.replaceAll('@', '-').replaceAll('.', '-')}';
    _currentEmail = normalized;
    _currentDisplayName = normalized.split('@').first;
    _controller.add(_currentUid);
    return _currentUid!;
  }

  @override
  Future<String> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_users.containsKey(normalized)) {
      throw const FormatException('Account already registered');
    }
    if (password.length < 8) {
      throw const FormatException('Password must be at least 8 characters');
    }
    _users[normalized] = password;
    _currentUid = 'uid-${normalized.replaceAll('@', '-').replaceAll('.', '-')}';
    _currentEmail = normalized;
    _currentDisplayName = normalized.split('@').first;
    _controller.add(_currentUid);
    return _currentUid!;
  }

  @override
  Future<String> signInWithGoogle({
    String? googleEmail,
    String? googleDisplayName,
  }) async {
    final email = googleEmail ?? 'test@familyvault.app';
    final normalized = email.trim().toLowerCase();
    _currentUid =
        'uid-google-${normalized.replaceAll('@', '-').replaceAll('.', '-')}';
    _currentEmail = normalized;
    _currentDisplayName = googleDisplayName ?? normalized.split('@').first;
    _controller.add(_currentUid);
    return _currentUid!;
  }

  @override
  Future<void> signOut() async {
    _currentUid = null;
    _currentEmail = null;
    _currentDisplayName = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    if (_currentUid != null) {
      _users.removeWhere(
        (email, _) =>
            'uid-${email.replaceAll('@', '-').replaceAll('.', '-')}' ==
            _currentUid,
      );
      _currentUid = null;
      _currentEmail = null;
      _currentDisplayName = null;
      _controller.add(null);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_users.containsKey(normalized)) {
      throw const FormatException('No account found with this email.');
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!_users.containsKey(normalized)) {
      throw const FormatException('No account found with this email.');
    }
    if (newPassword.length < 8) {
      throw const FormatException(
        'Password must be at least 8 characters long.',
      );
    }
    _users[normalized] = newPassword;
  }

  void dispose() {
    _controller.close();
  }
}
