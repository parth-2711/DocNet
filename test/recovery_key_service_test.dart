import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/security/domain/services/recovery_key_service.dart';

void main() {
  late RecoveryKeyService recoveryService;

  setUp(() {
    recoveryService = RecoveryKeyService();
  });

  group('RecoveryKeyService Tests', () {
    test('Generates a 12-word recovery phrase', () {
      final phrase = recoveryService.generateRecoveryPhrase();
      final words = phrase.split(' ');
      expect(words.length, equals(12));
      for (var word in words) {
        expect(word.trim(), isNotEmpty);
      }
    });

    test(
      'Derives 32-byte wrapping key deterministically with same phrase and salt',
      () async {
        final phrase = recoveryService.generateRecoveryPhrase();
        final salt = recoveryService.generateSalt();

        final key1 = await recoveryService.deriveWrappingKey(
          recoveryPhrase: phrase,
          salt: salt,
        );
        final key2 = await recoveryService.deriveWrappingKey(
          recoveryPhrase: phrase,
          salt: salt,
        );

        expect(key1.length, equals(32));
        expect(key2.length, equals(32));
        expect(key1, equals(key2));
      },
    );

    test('Produces different wrapping keys with different salts', () async {
      final phrase = recoveryService.generateRecoveryPhrase();
      final salt1 = recoveryService.generateSalt();
      final salt2 = Uint8List.fromList(salt1);
      salt2[0] ^= 0xFF; // Different salt

      final key1 = await recoveryService.deriveWrappingKey(
        recoveryPhrase: phrase,
        salt: salt1,
      );
      final key2 = await recoveryService.deriveWrappingKey(
        recoveryPhrase: phrase,
        salt: salt2,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('KdfDescriptor serializes to and from map correctly', () {
      const descriptor = KdfDescriptor(
        algorithm: 'HKDF-SHA-256',
        saltBase64: 'c2FsdA==',
        iterations: 100000,
        memoryCostKb: 65536,
        parallelism: 1,
        keyLength: 32,
      );

      final map = descriptor.toMap();
      final restored = KdfDescriptor.fromMap(map);

      expect(restored.algorithm, equals('HKDF-SHA-256'));
      expect(restored.saltBase64, equals('c2FsdA=='));
      expect(restored.iterations, equals(100000));
      expect(restored.keyLength, equals(32));
    });
  });
}
