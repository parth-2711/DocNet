import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../domain/entities/encrypted_file_container.dart';
import '../../domain/entities/encrypted_metadata.dart';
import '../../domain/services/crypto_service.dart';

/// Cryptography service implementation using package:cryptography (AES-256-GCM & SHA-256).
class CryptographyCryptoService implements CryptoService {
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();
  final Random _secureRandom = Random.secure();

  @override
  Future<Uint8List> generateSecureRandomBytes(int length) async {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  @override
  Future<Uint8List> generateDEK() async {
    // 256-bit (32-byte) key for AES-256
    return generateSecureRandomBytes(32);
  }

  @override
  Future<EncryptedFileContainer> encryptFile({
    required Uint8List plainText,
    required Uint8List dek,
    required String documentId,
    required String versionId,
    required String ownerUid,
    int keyEpoch = 1,
  }) async {
    if (dek.length != 32) {
      throw ArgumentError(
        'DEK must be exactly 32 bytes (256 bits) for AES-256-GCM',
      );
    }

    // 12-byte (96-bit) standard nonce for AES-GCM
    final nonce = await generateSecureRandomBytes(12);

    final container = EncryptedFileContainer(
      documentId: documentId,
      versionId: versionId,
      ownerUid: ownerUid,
      keyEpoch: keyEpoch,
      nonce: nonce,
      cipherText: Uint8List(0),
      macTag: Uint8List(0),
    );

    // Compute canonical AAD
    final aad = container.computeAAD();
    final secretKey = SecretKey(dek);

    final secretBox = await _aesGcm.encrypt(
      plainText,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    return EncryptedFileContainer(
      formatVersion: EncryptedFileContainer.currentFormatVersion,
      documentId: documentId,
      versionId: versionId,
      ownerUid: ownerUid,
      keyEpoch: keyEpoch,
      nonce: nonce,
      cipherText: Uint8List.fromList(secretBox.cipherText),
      macTag: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  @override
  Future<Uint8List> decryptFile({
    required EncryptedFileContainer container,
    required Uint8List dek,
  }) async {
    if (dek.length != 32) {
      throw ArgumentError(
        'DEK must be exactly 32 bytes (256 bits) for AES-256-GCM',
      );
    }

    final aad = container.computeAAD();
    final secretKey = SecretKey(dek);
    final secretBox = SecretBox(
      container.cipherText,
      nonce: container.nonce,
      mac: Mac(container.macTag),
    );

    try {
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: aad,
      );
      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Cryptographic integrity check failed: wrong key, tampered ciphertext, or altered AAD',
      );
    }
  }

  @override
  Future<EncryptedMetadata> encryptMetadata({
    required Map<String, dynamic> metadata,
    required Uint8List key,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('Key must be exactly 32 bytes for AES-256-GCM');
    }

    final jsonString = jsonEncode(metadata);
    final clearText = utf8.encode(jsonString);
    final nonce = await generateSecureRandomBytes(12);
    final secretKey = SecretKey(key);

    final secretBox = await _aesGcm.encrypt(
      clearText,
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptedMetadata(
      nonce: nonce,
      cipherText: Uint8List.fromList(secretBox.cipherText),
      macTag: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  @override
  Future<Map<String, dynamic>> decryptMetadata({
    required EncryptedMetadata encryptedMetadata,
    required Uint8List key,
  }) async {
    if (key.length != 32) {
      throw ArgumentError('Key must be exactly 32 bytes for AES-256-GCM');
    }

    final secretKey = SecretKey(key);
    final secretBox = SecretBox(
      encryptedMetadata.cipherText,
      nonce: encryptedMetadata.nonce,
      mac: Mac(encryptedMetadata.macTag),
    );

    try {
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final jsonString = utf8.decode(decryptedBytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Failed to decrypt metadata: authentication tag mismatch',
      );
    }
  }

  @override
  Future<String> computeSha256(Uint8List data) async {
    final digest = await _sha256.hash(data);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
