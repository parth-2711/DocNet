import 'dart:typed_data';
import '../entities/encrypted_file_container.dart';
import '../entities/encrypted_metadata.dart';

/// Cryptographic service contract enforcing zero-knowledge document encryption,
/// metadata confidentiality, and cryptographic integrity (ENCRYPTION.md).
abstract class CryptoService {
  /// Generates cryptographically secure random bytes of given length.
  Future<Uint8List> generateSecureRandomBytes(int length);

  /// Generates a unique 256-bit (32-byte) Document Encryption Key (DEK).
  Future<Uint8List> generateDEK();

  /// Encrypts document bytes using AES-256-GCM with associated authenticated data (AAD).
  Future<EncryptedFileContainer> encryptFile({
    required Uint8List plainText,
    required Uint8List dek,
    required String documentId,
    required String versionId,
    required String ownerUid,
    int keyEpoch = 1,
  });

  /// Decrypts an EncryptedFileContainer using the authorized DEK.
  /// Throws an exception if the key is incorrect, AAD was altered, or ciphertext was tampered with.
  Future<Uint8List> decryptFile({
    required EncryptedFileContainer container,
    required Uint8List dek,
  });

  /// Encrypts arbitrary structured metadata (JSON) using AES-256-GCM.
  Future<EncryptedMetadata> encryptMetadata({
    required Map<String, dynamic> metadata,
    required Uint8List key,
  });

  /// Decrypts encrypted metadata into the original map.
  Future<Map<String, dynamic>> decryptMetadata({
    required EncryptedMetadata encryptedMetadata,
    required Uint8List key,
  });

  /// Computes the hex-encoded SHA-256 digest of data.
  Future<String> computeSha256(Uint8List data);
}
