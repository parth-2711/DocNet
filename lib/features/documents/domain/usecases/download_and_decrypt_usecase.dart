import 'dart:convert';
import 'dart:typed_data';
import '../../../family/domain/entities/document_permission.dart';
import '../../../family/domain/repositories/family_repository.dart';
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
  final DocumentPermission? permission;

  const DecryptedDocumentResult({
    required this.plaintextBytes,
    required this.metadata,
    required this.document,
    required this.version,
    this.permission,
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
  final FamilyRepository? familyRepository;

  DownloadAndDecryptUseCase({
    required this.cryptoService,
    required this.documentRepository,
    required this.storageRepository,
    this.familyRepository,
  });

  /// Decrypts the specified document version on-device for authorized recipient.
  Future<DecryptedDocumentResult> execute({
    required String documentId,
    required String recipientUid,
    String? recipientEmail,
    String? versionId,
  }) async {
    // 1. Fetch document metadata
    final document = await documentRepository.getDocumentById(documentId);
    if (document == null) {
      throw StateError('Document not found: $documentId');
    }

    // 2. Enforce explicit per-user permissions for non-owners
    DocumentPermission? activePermission;
    if (document.ownerUid != recipientUid && familyRepository != null) {
      activePermission = await familyRepository!.getPermission(
        documentId: documentId,
        granteeId: recipientUid,
        granteeEmail: recipientEmail,
      );
      if (activePermission == null || !activePermission.canView) {
        throw StateError(
          'Access Denied: You do not have permission to view this document.',
        );
      }
      if (activePermission.isExpired) {
        throw StateError(
          'Access Expired: Your permission to view this document has expired.',
        );
      }
    }

    // 3. Fetch specific version or current version
    final targetVersionId = versionId ?? document.currentVersionId;
    final versions = await documentRepository.getVersions(documentId);
    final version = versions.firstWhere(
      (v) => v.versionId == targetVersionId,
      orElse: () => throw StateError(
        'Version $targetVersionId not found for document $documentId',
      ),
    );

    // 4. Fetch authorized key envelope (Boundary C & KEY-001)
    final envelope = await documentRepository.getKeyEnvelope(
      documentId: documentId,
      recipientId: recipientUid,
      recipientEmail: recipientEmail,
    );
    if (envelope == null) {
      throw StateError(
        'Access Denied: No cryptographic key envelope found for recipient $recipientUid on document $documentId.',
      );
    }

    // 5. Unwrap DEK locally
    final dek = Uint8List.fromList(base64Decode(envelope.wrappedDek));

    // 6. Download ciphertext bytes from storage (local or synced cloud blob)
    final ciphertextBytes = await storageRepository.getObject(
      version.storageObjectRef,
    );
    if (ciphertextBytes == null) {
      throw StateError(
        'Encrypted object missing from storage: ${version.storageObjectRef}',
      );
    }

    // 7. Verify cryptographic integrity before opening (VER-008)
    final computedSha256 = await cryptoService.computeSha256(ciphertextBytes);
    if (computedSha256.toLowerCase() != version.sha256.toLowerCase()) {
      throw const FormatException(
        'Cryptographic integrity failure: SHA-256 hash mismatch. File may be corrupt or tampered with.',
      );
    }

    // 8. Parse binary container
    final container = EncryptedFileContainer.fromBinary(ciphertextBytes);

    // 9. Decrypt file payload with canonical AAD
    final plaintext = await cryptoService.decryptFile(
      container: container,
      dek: dek,
    );

    // 10. Decrypt authenticated metadata
    final metadata = await cryptoService.decryptMetadata(
      encryptedMetadata: version.encryptedMetadata,
      key: dek,
    );

    return DecryptedDocumentResult(
      plaintextBytes: plaintext,
      metadata: metadata,
      document: document,
      version: version,
      permission: activePermission,
    );
  }
}
