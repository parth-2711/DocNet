import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../activity/domain/entities/activity_event.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../security/domain/services/crypto_service.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/repositories/sync_queue_repository.dart';
import '../entities/document_record.dart';
import '../entities/document_version.dart';
import '../entities/key_envelope.dart';
import '../repositories/document_repository.dart';
import '../repositories/storage_repository.dart';

/// Result returned upon successfully preparing and enqueuing an encrypted document upload.
class UploadDocumentResult {
  final DocumentRecord document;
  final DocumentVersion version;
  final KeyEnvelope envelope;
  final SyncOperation syncOperation;

  const UploadDocumentResult({
    required this.document,
    required this.version,
    required this.envelope,
    required this.syncOperation,
  });
}

/// Use case implementing the client-side encrypted upload pipeline (ARCHITECTURE.md Section 6.1,
/// PRD.md DOC-001, DOC-002, DOC-003, DOC-005, VER-002, VER-003).
class UploadDocumentUseCase {
  final CryptoService cryptoService;
  final DocumentRepository documentRepository;
  final SyncQueueRepository syncQueueRepository;
  final StorageRepository? storageRepository;
  final ActivityRepository? activityRepository;
  final Uuid uuid;

  UploadDocumentUseCase({
    required this.cryptoService,
    required this.documentRepository,
    required this.syncQueueRepository,
    this.storageRepository,
    this.activityRepository,
    this.uuid = const Uuid(),
  });

  /// Executes client-side validation, encryption, envelope wrapping, and local persistence.
  Future<UploadDocumentResult> execute({
    required Uint8List fileBytes,
    required String fileName,
    required String category,
    required String ownerUid,
    String? existingDocumentId,
    String? expectedParentVersionId,
    String? description,
    List<String>? tags,
  }) async {
    // 1. Validate file extension (DOC-002)
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (!AppConstants.supportedExtensions.contains(ext)) {
      throw ArgumentError(
        'Unsupported file type: .$ext. Supported formats are: ${AppConstants.supportedExtensions.join(', ').toUpperCase()}.',
      );
    }

    // 2. Validate file size (DOC-003)
    if (fileBytes.length > AppConstants.maxFileSizeBytes) {
      throw ArgumentError(
        'File size exceeds the 25 MB maximum limit. Actual size: ${(fileBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB.',
      );
    }

    final isReplacement = existingDocumentId != null;
    final documentId = existingDocumentId ?? uuid.v4();
    final versionId = uuid.v4();
    final now = DateTime.now().toUtc();

    // 3. Generate random 256-bit DEK (KEY-001)
    final dek = await cryptoService.generateDEK();

    // 4. Encrypt document file bytes with canonical AAD (ENCRYPTION.md Section 4 & 6)
    final encryptedContainer = await cryptoService.encryptFile(
      plainText: fileBytes,
      dek: dek,
      documentId: documentId,
      versionId: versionId,
      ownerUid: ownerUid,
      keyEpoch: 1,
    );
    final encryptedBinary = encryptedContainer.toBinary();

    // 5. Compute SHA-256 of encrypted ciphertext (VER-008)
    final sha256Hex = await cryptoService.computeSha256(encryptedBinary);

    // 6. Encrypt sensitive metadata (ENCRYPTION.md Section 5)
    final metadataPayload = <String, dynamic>{
      'name': fileName,
      'category': category,
    };
    if (description != null) {
      metadataPayload['description'] = description;
    }
    if (tags != null) {
      metadataPayload['tags'] = tags;
    }
    final encryptedMetadata = await cryptoService.encryptMetadata(
      metadata: metadataPayload,
      key: dek,
    );

    // 7. Wrap DEK for owner key envelope (ENCRYPTION.md Section 7)
    final envelope = KeyEnvelope(
      envelopeId: uuid.v4(),
      documentId: documentId,
      recipientType: 'user',
      recipientId: ownerUid,
      wrappedDek: base64Encode(dek),
      wrappingAlgorithm: 'AES-256-GCM',
      keyEpoch: 1,
      createdAt: now,
    );

    // 8. Determine version number
    var versionNumber = 1;
    if (isReplacement) {
      final existingVersions = await documentRepository.getVersions(documentId);
      versionNumber = existingVersions.length + 1;
    }

    // 9. Create immutable version record (VER-002, VER-003)
    final versionRecord = DocumentVersion(
      documentId: documentId,
      versionId: versionId,
      versionNumber: versionNumber,
      parentVersionId: expectedParentVersionId,
      ownerUid: ownerUid,
      storageObjectRef:
          'users/$ownerUid/documents/$documentId/versions/$versionId.bin',
      storageObjectSize: encryptedBinary.length,
      sha256: sha256Hex,
      encryptedMetadata: encryptedMetadata,
      createdAt: now,
      uploadedByUid: ownerUid,
      committedAt: now,
    );

    // 10. Create or update document metadata record
    final documentRecord = DocumentRecord(
      documentId: documentId,
      ownerUid: ownerUid,
      currentVersionId: versionId,
      category: category,
      encryptedMetadata: encryptedMetadata,
      mimeType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
      originalSizeBytes: fileBytes.length,
      encryptedSizeBytes: encryptedBinary.length,
      createdAt: now,
      updatedAt: now,
      versionCount: versionNumber,
      decryptedName: fileName,
      decryptedDescription: description,
      decryptedTags: tags ?? const [],
    );

    // 11. Enqueue operation to offline sync queue before transfer (SYNC_ENGINE.md Section 3 & 5)
    final syncOperation = SyncOperation(
      operationId: uuid.v4(),
      userId: ownerUid,
      deviceId: 'device-local-1',
      operationType: isReplacement
          ? SyncOperationType.replace
          : SyncOperationType.upload,
      documentId: documentId,
      versionId: versionId,
      expectedParentVersionId: expectedParentVersionId,
      encryptedPayloadReference: versionRecord.storageObjectRef,
      status: SyncOperationStatus.queued,
      idempotencyKey:
          '${documentId}_${versionId}_${now.millisecondsSinceEpoch}',
      createdAt: now,
      updatedAt: now,
    );

    await syncQueueRepository.enqueue(syncOperation);

    // 12. Store ciphertext object in storage if repository is provided
    if (storageRepository != null) {
      await storageRepository!.putObject(
        objectRef: versionRecord.storageObjectRef,
        data: encryptedBinary,
      );
    }

    // 13. Save version, document, and envelope into DocumentRepository
    await documentRepository.saveVersion(versionRecord);
    await documentRepository.saveDocument(documentRecord);
    await documentRepository.saveKeyEnvelope(envelope);

    // 14. Record audit event (PRD.md 6.12, AUDIT-001, AUDIT-002: no plaintext file names)
    if (activityRepository != null) {
      await activityRepository!.logEvent(
        ActivityEvent(
          activityId: uuid.v4(),
          actorUid: ownerUid,
          targetDocumentId: documentId,
          eventType: isReplacement
              ? ActivityEventType.documentReplaced
              : ActivityEventType.documentCreated,
          summary: isReplacement
              ? 'Encrypted document version replaced'
              : 'Encrypted document uploaded',
          metadata: {
            'versionId': versionId,
            'category': category,
            'originalSizeBytes': fileBytes.length,
            'encryptedSizeBytes': encryptedBinary.length,
          },
          timestamp: now,
        ),
      );
    }

    return UploadDocumentResult(
      document: documentRecord,
      version: versionRecord,
      envelope: envelope,
      syncOperation: syncOperation,
    );
  }
}
