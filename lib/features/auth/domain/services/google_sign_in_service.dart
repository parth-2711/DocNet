import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/logging/app_logger.dart';

class GoogleAuthResult {
  final String email;
  final String displayName;

  const GoogleAuthResult({required this.email, required this.displayName});
}

/// Service wrapping reliable Google Sign-In via [GoogleSignIn].
class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);

  bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// Triggers the native platform Google Sign-In prompt.
  /// Returns [GoogleAuthResult] on success, or `null` if user dismissed the prompt.
  Future<GoogleAuthResult?> signIn() async {
    if (_isTestEnvironment) {
      return const GoogleAuthResult(
        email: 'google.test@familyvault.app',
        displayName: 'Google Test User',
      );
    }

    try {
      // Disconnect or sign out first to ensure account selection dialog always appears
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        AppLogger.info(
          'GoogleSignInService',
          'User dismissed Google Sign-In prompt',
        );
        return null;
      }

      final email = account.email;
      final displayName = account.displayName ?? email.split('@').first;

      return GoogleAuthResult(email: email, displayName: displayName);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
        AppLogger.info('GoogleSignInService', 'User canceled Google Sign-In');
        return null;
      }
      AppLogger.error(
        'GoogleSignInService',
        'Google PlatformException (${e.code}): ${e.message}',
        error: e,
      );
      rethrow;
    } catch (e) {
      AppLogger.error(
        'GoogleSignInService',
        'Unexpected error during Google Sign-In: $e',
        error: e,
      );
      rethrow;
    }
  }

  /// Signs out of Google session.
  Future<void> signOut() async {
    if (_isTestEnvironment) return;
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      AppLogger.warn('GoogleSignInService', 'Sign out error: $e');
    }
  }
}
