import 'dart:convert';
import 'dart:typed_data';
import '../../../security/domain/entities/encrypted_file_container.dart';
import '../../../security/domain/services/crypto_service.dart';
import '../entities/document_record.dart';
import '../entities/document_version.dart';
import '../repositories/document_repository.dart';
import '../repositories/storage_repository.dart';

/// Container for the decrypted plaintext file and authenticated metadata (ARCHITECTURE.md Section 6.2).
class DecryptedDocumentResult {
  final Uint8List plaintextBytes;
  final Map<String, dynamic> metadata;
  final DocumentRecord document;
  final DocumentVersion version;

  const DecryptedDocumentResult({
    required this.plaintextBytes,
    required this.metadata,
    required this.document,
    required this.version,
  });

  String get fileName => metadata['name'] as String? ?? 'Document';
  String get category => metadata['category'] as String? ?? 'Other';
  String? get description => metadata['description'] as String?;
}

/// Use case implementing client-side download, integrity validation, and decryption (ARCHITECTURE.md Section 6.2,
/// PRD.md DOC-015, DOC-016, VER-008).
class DownloadAndDecryptUseCase {
  final CryptoService cryptoService;
  final DocumentRepository documentRepository;
  final StorageRepository storageRepository;

  DownloadAndDecryptUseCase({
    required this.cryptoService,
    required this.documentRepository,
    required this.storageRepository,
  });

  /// Decrypts the specified document version on-device for authorized recipient.
  Future<DecryptedDocumentResult> execute({
    required String documentId,
    required String recipientUid,
    String? versionId,
  }) async {
    // 1. Fetch document metadata
    final document = await documentRepository.getDocumentById(documentId);
    if (document == null) {
      throw StateError('Document not found: $documentId');
    }

    // 2. Fetch specific version or current version
    final targetVersionId = versionId ?? document.currentVersionId;
    final versions = await documentRepository.getVersions(documentId);
    final version = versions.firstWhere(
      (v) => v.versionId == targetVersionId,
      orElse: () => throw StateError(
        'Version $targetVersionId not found for document $documentId',
      ),
    );

    // 3. Fetch authorized key envelope (Boundary C & KEY-001)
    final envelope = await documentRepository.getKeyEnvelope(
      documentId: documentId,
      recipientId: recipientUid,
    );
    if (envelope == null) {
      throw StateError(
        'Access Denied: No cryptographic key envelope found for recipient $recipientUid on document $documentId.',
      );
    }

    // 4. Unwrap DEK locally
    final dek = Uint8List.fromList(base64Decode(envelope.wrappedDek));

    // 5. Download ciphertext bytes from storage
    final ciphertextBytes = await storageRepository.getObject(
      version.storageObjectRef,
    );
    if (ciphertextBytes == null) {
      throw StateError(
        'Encrypted object missing from storage: ${version.storageObjectRef}',
      );
    }

    // 6. Verify cryptographic integrity before opening (VER-008)
    final computedSha256 = await cryptoService.computeSha256(ciphertextBytes);
    if (computedSha256.toLowerCase() != version.sha256.toLowerCase()) {
      throw const FormatException(
        'Cryptographic integrity failure: SHA-256 hash mismatch. File may be corrupt or tampered with.',
      );
    }

    // 7. Parse binary container
    final container = EncryptedFileContainer.fromBinary(ciphertextBytes);

    // 8. Decrypt file payload with canonical AAD
    final plaintext = await cryptoService.decryptFile(
      container: container,
      dek: dek,
    );

    // 9. Decrypt authenticated metadata
    final metadata = await cryptoService.decryptMetadata(
      encryptedMetadata: version.encryptedMetadata,
      key: dek,
    );

    return DecryptedDocumentResult(
      plaintextBytes: plaintext,
      metadata: metadata,
      document: document,
      version: version,
    );
  }
}
