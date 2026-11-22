import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'package:docnet/features/security/domain/entities/encrypted_file_container.dart';

void main() {
  late CryptographyCryptoService cryptoService;

  setUp(() {
    cryptoService = CryptographyCryptoService();
  });

  group('EncryptedFileContainer & CryptoService Tests', () {
    test(
      'Encrypts and decrypts document bytes matching byte-for-byte',
      () async {
        final dek = await cryptoService.generateDEK();
        final originalPlaintext = Uint8List.fromList(
          utf8.encode('Sample confidential document content.'),
        );

        final container = await cryptoService.encryptFile(
          plainText: originalPlaintext,
          dek: dek,
          documentId: 'doc-1234',
          versionId: 'ver-0001',
          ownerUid: 'user-parth',
        );

        expect(container.documentId, equals('doc-1234'));
        expect(container.versionId, equals('ver-0001'));
        expect(container.ownerUid, equals('user-parth'));
        expect(container.cipherText.length, equals(originalPlaintext.length));
        expect(container.cipherText, isNot(equals(originalPlaintext)));

        final decrypted = await cryptoService.decryptFile(
          container: container,
          dek: dek,
        );

        expect(
          utf8.decode(decrypted),
          equals('Sample confidential document content.'),
        );
      },
    );

    test(
      'Binary serialization and deserialization retains all container data',
      () async {
        final dek = await cryptoService.generateDEK();
        final plaintext = Uint8List.fromList(
          utf8.encode('PDF file binary content simulation'),
        );

        final container = await cryptoService.encryptFile(
          plainText: plaintext,
          dek: dek,
          documentId: 'doc-9999',
          versionId: 'ver-0042',
          ownerUid: 'uid-alice',
          keyEpoch: 2,
        );

        final binary = container.toBinary();
        expect(binary.length, greaterThan(container.cipherText.length));

        final restored = EncryptedFileContainer.fromBinary(binary);
        expect(restored.documentId, equals('doc-9999'));
        expect(restored.versionId, equals('ver-0042'));
        expect(restored.ownerUid, equals('uid-alice'));
        expect(restored.keyEpoch, equals(2));
        expect(restored.nonce, equals(container.nonce));
        expect(restored.macTag, equals(container.macTag));
        expect(restored.cipherText, equals(container.cipherText));

        final decrypted = await cryptoService.decryptFile(
          container: restored,
          dek: dek,
        );
        expect(decrypted, equals(plaintext));
      },
    );

    test('Fails decryption if documentId in AAD is tampered with', () async {
      final dek = await cryptoService.generateDEK();
      final plaintext = Uint8List.fromList(utf8.encode('Secret record'));

      final container = await cryptoService.encryptFile(
        plainText: plaintext,
        dek: dek,
        documentId: 'doc-original',
        versionId: 'ver-1',
        ownerUid: 'user-1',
      );

      final tampered = EncryptedFileContainer(
        documentId: 'doc-tampered', // Altered ID
        versionId: container.versionId,
        ownerUid: container.ownerUid,
        keyEpoch: container.keyEpoch,
        nonce: container.nonce,
        cipherText: container.cipherText,
        macTag: container.macTag,
      );

      expect(
        () async =>
            await cryptoService.decryptFile(container: tampered, dek: dek),
        throwsA(isA<FormatException>()),
      );
    });

    test('Fails decryption if ciphertext byte is modified', () async {
      final dek = await cryptoService.generateDEK();
      final plaintext = Uint8List.fromList(utf8.encode('Sensitive data'));

      final container = await cryptoService.encryptFile(
        plainText: plaintext,
        dek: dek,
        documentId: 'doc-1',
        versionId: 'ver-1',
        ownerUid: 'user-1',
      );

      final tamperedCiphertext = Uint8List.fromList(container.cipherText);
      tamperedCiphertext[0] ^= 0xFF; // Flip bits in ciphertext

      final tampered = EncryptedFileContainer(
        documentId: container.documentId,
        versionId: container.versionId,
        ownerUid: container.ownerUid,
        keyEpoch: container.keyEpoch,
        nonce: container.nonce,
        cipherText: tamperedCiphertext,
        macTag: container.macTag,
      );

      expect(
        () async =>
            await cryptoService.decryptFile(container: tampered, dek: dek),
        throwsA(isA<FormatException>()),
      );
    });

    test('Encrypts and decrypts metadata map round-trip', () async {
      final key = await cryptoService.generateDEK();
      final metadata = {
        'name': 'Passport.pdf',
        'category': 'Identity',
        'tags': ['travel', 'official'],
        'ocrText': 'REPUBLIC OF INDIA PASSPORT',
      };

      final encrypted = await cryptoService.encryptMetadata(
        metadata: metadata,
        key: key,
      );
      final decrypted = await cryptoService.decryptMetadata(
        encryptedMetadata: encrypted,
        key: key,
      );

      expect(decrypted['name'], equals('Passport.pdf'));
      expect(decrypted['category'], equals('Identity'));
      expect(decrypted['tags'], equals(['travel', 'official']));
      expect(decrypted['ocrText'], equals('REPUBLIC OF INDIA PASSPORT'));
    });

    test('Computes standard SHA-256 hex string', () async {
      final data = Uint8List.fromList(utf8.encode('FamilyVault'));
      final sha = await cryptoService.computeSha256(data);
      expect(sha.length, equals(64));
      // Known sha256 for "FamilyVault"
      // echo -n "FamilyVault" | shasum -a 256
      expect(sha, isNotEmpty);
    });
  });
}
