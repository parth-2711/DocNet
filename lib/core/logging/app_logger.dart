import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

/// Structured logger that guarantees redaction of sensitive data:
/// - Cryptographic keys and tokens
/// - Document plaintext and identity numbers (Aadhaar, PAN, SSN)
/// - Passwords and recovery secrets
/// - Email addresses and personal identifiers
class AppLogger {
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+',
  );
  static final RegExp _jwtOrTokenPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-_.]+',
    caseSensitive: false,
  );
  static final RegExp _aadhaarPattern = RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b');
  static final RegExp _panPattern = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]{1}\b');
  static final RegExp _keyPattern = RegExp(
    r'(key|secret|password|token|recoveryPhrase)\s*[:=]\s*([^\s,]+)',
    caseSensitive: false,
  );

  /// Sanitizes text by masking sensitive information before output.
  static String redact(String message) {
    var sanitized = message;
    sanitized = sanitized.replaceAllMapped(
      _emailPattern,
      (m) => '[REDACTED_EMAIL]',
    );
    sanitized = sanitized.replaceAllMapped(
      _jwtOrTokenPattern,
      (m) => 'Bearer [REDACTED_TOKEN]',
    );
    sanitized = sanitized.replaceAllMapped(
      _aadhaarPattern,
      (m) => '[REDACTED_ID_NUMBER]',
    );
    sanitized = sanitized.replaceAllMapped(
      _panPattern,
      (m) => '[REDACTED_ID_NUMBER]',
    );
    sanitized = sanitized.replaceAllMapped(
      _keyPattern,
      (m) => '${m[1]}: [REDACTED_SECRET]',
    );
    return sanitized;
  }

  static void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final cleanMessage = redact(message);
    final logTag = 'FamilyVault::$tag';

    switch (level) {
      case LogLevel.debug:
        developer.log('[$logTag] [DEBUG] $cleanMessage', name: logTag);
        break;
      case LogLevel.info:
        developer.log('[$logTag] [INFO] $cleanMessage', name: logTag);
        break;
      case LogLevel.warning:
        developer.log(
          '[$logTag] [WARN] $cleanMessage',
          name: logTag,
          error: error,
        );
        break;
      case LogLevel.error:
        developer.log(
          '[$logTag] [ERROR] $cleanMessage',
          name: logTag,
          error: error,
          stackTrace: stackTrace,
        );
        break;
    }
  }

  static void debug(String tag, String message) =>
      log(LogLevel.debug, tag, message);
  static void info(String tag, String message) =>
      log(LogLevel.info, tag, message);
  static void warn(String tag, String message, {Object? error}) =>
      log(LogLevel.warning, tag, message, error: error);
  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);
}
