import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/core/logging/app_logger.dart';

void main() {
  group('AppLogger Redaction Tests', () {
    test('redacts email addresses', () {
      const input = 'User test.user@example.com logged in successfully.';
      final result = AppLogger.redact(input);
      expect(result, contains('[REDACTED_EMAIL]'));
      expect(result, isNot(contains('test.user@example.com')));
    });

    test('redacts Bearer tokens', () {
      const input =
          'Authorization failed for header: Bearer eyJhbGciOiJIUzI1NiJ9.abc.def';
      final result = AppLogger.redact(input);
      expect(result, contains('Bearer [REDACTED_TOKEN]'));
      expect(result, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('redacts Indian Aadhaar 12-digit number format', () {
      const input = 'Processing document for Aadhaar 9876 5432 1098 attached.';
      final result = AppLogger.redact(input);
      expect(result, contains('[REDACTED_ID_NUMBER]'));
      expect(result, isNot(contains('9876 5432 1098')));
    });

    test('redacts Indian PAN card number format', () {
      const input = 'PAN card ABCDE1234F uploaded.';
      final result = AppLogger.redact(input);
      expect(result, contains('[REDACTED_ID_NUMBER]'));
      expect(result, isNot(contains('ABCDE1234F')));
    });

    test(
      'redacts secrets, keys, and recovery phrases in key-value formats',
      () {
        const input = 'Encryption failed with key: super_secret_master_key_123';
        final result = AppLogger.redact(input);
        expect(result, contains('key: [REDACTED_SECRET]'));
        expect(result, isNot(contains('super_secret_master_key_123')));
      },
    );
  });
}
