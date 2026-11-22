import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:docnet/core/logging/app_logger.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'persistent_auth_repository.dart';

/// Firebase Authentication repository creating and authenticating accounts directly in Firebase
/// while maintaining seamless compatibility with on-device Zero-Knowledge vault encryption.
class FirebaseAuthRepository implements AuthRepository {
  final LocalVaultStorageService storageService;
  final PersistentAuthRepository _localFallback;
  final fb.FirebaseAuth? _firebaseAuth;
  final _controller = StreamController<String?>.broadcast();
  StreamSubscription<fb.User?>? _fbSub;

  FirebaseAuthRepository(this.storageService)
      : _localFallback = PersistentAuthRepository(storageService),
        _firebaseAuth = (Firebase.apps.isNotEmpty && !_isTestEnvironment)
            ? fb.FirebaseAuth.instance
            : null {
    _init();
  }

  static bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get isFirebaseAvailable => _firebaseAuth != null;

  void _init() {
    final auth = _firebaseAuth;
    if (auth != null) {
      _fbSub = auth.authStateChanges().listen((fb.User? user) {
        AppLogger.info('FirebaseAuthRepository', 'Firebase auth state: ${user?.uid}');
        _controller.add(user?.uid);
      });
      final user = auth.currentUser;
      if (user != null) {
        _controller.add(user.uid);
      }
    } else {
      _localFallback.authStateChanges.listen((uid) {
        _controller.add(uid);
      });
    }
  }

  @override
  Stream<String?> get authStateChanges => _controller.stream;

  @override
  String? get currentUid =>
      isFirebaseAvailable ? _firebaseAuth?.currentUser?.uid : _localFallback.currentUid;

  @override
  String? get currentEmail =>
      isFirebaseAvailable ? _firebaseAuth?.currentUser?.email : _localFallback.currentEmail;

  @override
  String? get currentDisplayName =>
      isFirebaseAvailable
          ? (_firebaseAuth?.currentUser?.displayName ?? _localFallback.currentDisplayName)
          : _localFallback.currentDisplayName;

  @override
  Future<String> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (isFirebaseAvailable) {
      try {
        final credential = await _firebaseAuth!.signInWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          throw const FormatException('Failed to retrieve authenticated user from Firebase.');
        }
        return user.uid;
      } on fb.FirebaseAuthException catch (e) {
        throw FormatException(_mapFirebaseError(e));
      }
    } else {
      return _localFallback.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  @override
  Future<String> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (isFirebaseAvailable) {
      try {
        final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
          email: normalized,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          throw const FormatException('Failed to register user in Firebase.');
        }
        if (displayName != null && displayName.trim().isNotEmpty) {
          await user.updateDisplayName(displayName.trim());
        }
        return user.uid;
      } on fb.FirebaseAuthException catch (e) {
        throw FormatException(_mapFirebaseError(e));
      }
    } else {
      return _localFallback.registerWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
    }
  }

  @override
  Future<String> signInWithGoogle({
    String? googleEmail,
    String? googleDisplayName,
  }) async {
    if (isFirebaseAvailable) {
      try {
        final googleSignIn = GoogleSignIn(scopes: <String>['email']);
        final googleAccount = await googleSignIn.signIn();
        if (googleAccount == null) {
          throw const FormatException('Google Sign-In was canceled');
        }
        final googleAuth = await googleAccount.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _firebaseAuth!.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) {
          throw const FormatException('Failed to complete Google Sign-In with Firebase.');
        }
        return user.uid;
      } on fb.FirebaseAuthException catch (e) {
        throw FormatException(_mapFirebaseError(e));
      } catch (e) {
        AppLogger.warn('FirebaseAuthRepository', 'Google sign-in fallback: $e');
        return _localFallback.signInWithGoogle(
          googleEmail: googleEmail,
          googleDisplayName: googleDisplayName,
        );
      }
    } else {
      return _localFallback.signInWithGoogle(
        googleEmail: googleEmail,
        googleDisplayName: googleDisplayName,
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (isFirebaseAvailable) {
      try {
        await _firebaseAuth!.sendPasswordResetEmail(email: normalized);
      } on fb.FirebaseAuthException catch (e) {
        throw FormatException(_mapFirebaseError(e));
      }
    } else {
      await _localFallback.sendPasswordResetEmail(normalized);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (isFirebaseAvailable) {
      // In Firebase Auth, trigger the official password reset email flow
      await sendPasswordResetEmail(normalized);
    } else {
      await _localFallback.resetPassword(
        email: email,
        newPassword: newPassword,
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (isFirebaseAvailable) {
      try {
        await _firebaseAuth!.signOut();
      } catch (_) {}
    }
    await _localFallback.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    if (isFirebaseAvailable) {
      try {
        await _firebaseAuth!.currentUser?.delete();
      } catch (e) {
        AppLogger.warn('FirebaseAuthRepository', 'Error deleting Firebase user: $e');
      }
    }
    await _localFallback.deleteAccount();
  }

  String _mapFirebaseError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account registered with this email address in Firebase.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or credentials. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email address. Please sign in instead.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'The password is too weak. Please choose at least 8 characters.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      default:
        return e.message ?? 'Firebase Authentication error (${e.code}).';
    }
  }

  void dispose() {
    _fbSub?.cancel();
    _controller.close();
  }
}

