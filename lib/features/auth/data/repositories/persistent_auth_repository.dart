import 'dart:async';
import 'dart:io';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';

/// Persistent implementation of AuthRepository saving credentials and maintaining
/// active user sessions across app restarts on device storage (PRD.md Section 6.1).
class PersistentAuthRepository implements AuthRepository {
  final LocalVaultStorageService storageService;
  final _controller = StreamController<String?>.broadcast();
  String? _currentUid;
  final Map<String, Map<String, dynamic>> _users = {};
  bool _loaded = false;

  PersistentAuthRepository(this.storageService) {
    _init();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('auth');
      if (data is Map<String, dynamic>) {
        if (data['users'] is Map<String, dynamic>) {
          (data['users'] as Map<String, dynamic>).forEach((email, u) {
            if (u is Map<String, dynamic>) {
              _users[email.toLowerCase()] = Map<String, dynamic>.from(u);
            }
          });
        }
        _currentUid = data['lastActiveUid'] as String?;
      }
    } catch (_) {
    } finally {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        // Pre-seed default test account for automated test suites only
        if (!_users.containsKey('test@familyvault.app')) {
          _users['test@familyvault.app'] = {
            'uid': 'uid-test-familyvault-app',
            'email': 'test@familyvault.app',
            'password': 'Password123!',
            'displayName': 'Vault User',
            'provider': 'email',
          };
        }
      } else {
        // Production runtime: strictly remove any legacy demo/dummy test accounts
        if (_users.containsKey('test@familyvault.app')) {
          _users.remove('test@familyvault.app');
          if (_currentUid == 'uid-test-familyvault-app') {
            _currentUid = null;
          }
          _persist();
        }
      }
      _loaded = true;
    }
  }

  void _init() {
    _ensureLoaded().then((_) {
      if (_currentUid != null) {
        _controller.add(_currentUid);
      }
    });
  }

  Future<void> _persist() async {
    await storageService.saveJson('auth', {
      'lastActiveUid': _currentUid,
      'users': _users,
    });
  }

  @override
  Stream<String?> get authStateChanges => _controller.stream;

  @override
  String? get currentUid => _currentUid;

  @override
  String? get currentEmail {
    if (_currentUid == null) return null;
    for (final entry in _users.values) {
      if (entry['uid'] == _currentUid) {
        return entry['email'] as String?;
      }
    }
    return null;
  }

  @override
  String? get currentDisplayName {
    if (_currentUid == null) return null;
    for (final entry in _users.values) {
      if (entry['uid'] == _currentUid) {
        return entry['displayName'] as String?;
      }
    }
    return null;
  }

  @override
  Future<String> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _ensureLoaded();
    final normalized = email.trim().toLowerCase();
    final user = _users[normalized];
    if (user == null) {
      throw const FormatException(
        'No account found with this email. Please tap "Create one" below to register.',
      );
    }
    if (user['password'] != password) {
      throw const FormatException(
        'Incorrect password. Please verify your credentials and try again.',
      );
    }
    _currentUid = user['uid'] as String;
    await _persist();
    _controller.add(_currentUid);
    return _currentUid!;
  }

  @override
  Future<String> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _ensureLoaded();
    final normalized = email.trim().toLowerCase();
    if (_users.containsKey(normalized)) {
      throw const FormatException(
        'An account with this email already exists. Please sign in instead.',
      );
    }
    if (password.length < 8) {
      throw const FormatException(
        'Password must be at least 8 characters long.',
      );
    }

    final uid = 'uid-${normalized.replaceAll('@', '-').replaceAll('.', '-')}';
    _users[normalized] = {
      'uid': uid,
      'email': normalized,
      'password': password,
      'displayName': displayName ?? normalized.split('@').first,
      'provider': 'email',
    };
    _currentUid = uid;
    await _persist();
    _controller.add(_currentUid);
    return _currentUid!;
  }

  @override
  Future<String> signInWithGoogle({
    String? googleEmail,
    String? googleDisplayName,
  }) async {
    await _ensureLoaded();
    final email = (googleEmail ?? 'user@familyvault.app').trim().toLowerCase();
    final existingUser = _users[email];
    final uid = existingUser?['uid'] as String? ??
        'uid-${email.replaceAll('@', '-').replaceAll('.', '-')}';

    String resolvedName = '';
    if (googleDisplayName != null &&
        googleDisplayName.trim().isNotEmpty &&
        googleDisplayName != 'Google User' &&
        googleDisplayName != 'Google Account User') {
      resolvedName = googleDisplayName.trim();
    } else if (email.contains('@')) {
      final prefix = email.split('@').first;
      final parts = prefix.split(RegExp(r'[._\-]'));
      resolvedName = parts
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : ''))
          .join(' ');
    }
    if (resolvedName.isEmpty) resolvedName = 'User';

    _users[email] = {
      'uid': uid,
      'email': email,
      'displayName': resolvedName,
      'provider': 'google',
    };
    _currentUid = uid;
    await _persist();
    _controller.add(_currentUid);
    return _currentUid!;
  }

  @override
  Future<void> signOut() async {
    await _ensureLoaded();
    _currentUid = null;
    await _persist();
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    await _ensureLoaded();
    if (_currentUid != null) {
      _users.removeWhere((_, u) => u['uid'] == _currentUid);
      _currentUid = null;
      await _persist();
      _controller.add(null);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _ensureLoaded();
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
    await _ensureLoaded();
    final normalized = email.trim().toLowerCase();
    final user = _users[normalized];
    if (user == null) {
      throw const FormatException('No account found with this email.');
    }
    if (newPassword.length < 8) {
      throw const FormatException(
        'Password must be at least 8 characters long.',
      );
    }
    user['password'] = newPassword;
    await _persist();
  }

  void dispose() {
    _controller.close();
  }
}
