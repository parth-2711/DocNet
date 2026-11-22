import 'dart:async';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../documents/domain/repositories/document_repository.dart';
import '../../../documents/domain/repositories/storage_repository.dart';
import '../../domain/entities/upload_session.dart';
import '../../domain/services/resumable_transfer_adapter.dart';

/// Concrete implementation of [ResumableTransferAdapter] providing chunked, resumable
/// transfers with integrity verification, optimistic concurrency, and idempotency
/// (SYNC_ENGINE.md Section 6, 8, & 13, API_SPECIFICATION.md Section 3).
class ResumableCloudStorageAdapter implements ResumableTransferAdapter {
  final StorageRepository storageRepository;
  final DocumentRepository documentRepository;
  final Uuid uuid;

  final Map<String, UploadSession> _sessions = {};
  final Map<String, BytesBuilder> _sessionBuffers = {};
  final Map<String, StreamController<UploadSessionProgress>>
  _progressControllers = {};

  ResumableCloudStorageAdapter({
    required this.storageRepository,
    required this.documentRepository,
    this.uuid = const Uuid(),
  });

  @override
  Future<UploadSession> requestUploadSession({
    required String ownerUid,
    required String documentId,
    required String versionId,
    String? expectedParentVersionId,
    required int encryptedSize,
    required String idempotencyKey,
    Duration expiry = const Duration(minutes: 15),
  }) async {
    // 1. Validate encrypted payload size (DOC-003)
    if (encryptedSize <= 0) {
      throw ArgumentError('Encrypted size must be greater than 0');
    }
    if (encryptedSize > AppConstants.maxFileSizeBytes + 1024) {
      throw ArgumentError('Encrypted file exceeds maximum allowed limit');
    }

    // Check for existing active session with same idempotencyKey (SYNC_ENGINE.md Section 6)
    for (final existing in _sessions.values) {
      if (existing.idempotencyKey == idempotencyKey && !existing.isExpired) {
        return existing;
      }
    }

    final sessionId = uuid.v4();
    final now = DateTime.now().toUtc();
    final storagePath =
        'users/$ownerUid/documents/$documentId/versions/$versionId.bin';

    final session = UploadSession(
      sessionId: sessionId,
      ownerUid: ownerUid,
      documentId: documentId,
      versionId: versionId,
      expectedParentVersionId: expectedParentVersionId,
      storageObjectPath: storagePath,
      expectedEncryptedSize: encryptedSize,
      status: UploadSessionStatus.created,
      uploadedBytes: 0,
      createdAt: now,
      expiresAt: now.add(expiry),
      idempotencyKey: idempotencyKey,
    );

    _sessions[sessionId] = session;
    _sessionBuffers[sessionId] = BytesBuilder(copy: false);
    _progressControllers[sessionId] =
        StreamController<UploadSessionProgress>.broadcast();

    return session;
  }

  @override
  Future<UploadSessionProgress> uploadChunk({
    required String sessionId,
    required Uint8List chunkBytes,
    required int offset,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Upload session not found: $sessionId');
    }

    // Check session expiry
    if (session.isExpired) {
      _sessions[sessionId] = session.copyWith(
        status: UploadSessionStatus.expired,
      );
      throw StateError('UPLOAD_SESSION_EXPIRED');
    }

    final buffer = _sessionBuffers[sessionId]!;

    // Resumable offset check: if client sends chunk starting at current buffer length, accept
    if (offset != buffer.length) {
      throw ArgumentError(
        'Invalid chunk offset: expected ${buffer.length}, received $offset',
      );
    }

    buffer.add(chunkBytes);
    final totalUploaded = buffer.length;

    final isFinished = totalUploaded >= session.expectedEncryptedSize;
    final updatedSession = session.copyWith(
      status: isFinished
          ? UploadSessionStatus.uploaded
          : UploadSessionStatus.uploading,
      uploadedBytes: totalUploaded,
    );
    _sessions[sessionId] = updatedSession;

    final progress = UploadSessionProgress(
      sessionId: sessionId,
      bytesTransferred: totalUploaded,
      totalBytes: session.expectedEncryptedSize,
      fraction: updatedSession.progressFraction,
      status: updatedSession.status,
    );

    _progressControllers[sessionId]?.add(progress);
    return progress;
  }

  @override
  Future<String> completeUploadSession({
    required String sessionId,
    required String versionId,
    String? expectedParentVersionId,
    required Map<String, dynamic> encryptedMetadata,
    required Map<String, dynamic> keyEnvelope,
    required String idempotencyKey,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Upload session not found: $sessionId');
    }

    // Idempotency: If already committed, return the version ID safely
    if (session.status == UploadSessionStatus.committed) {
      return session.versionId;
    }

    if (session.isExpired) {
      _sessions[sessionId] = session.copyWith(
        status: UploadSessionStatus.expired,
      );
      throw StateError('UPLOAD_SESSION_EXPIRED');
    }

    final buffer = _sessionBuffers[sessionId]!;

    // Size verification (API_SPECIFICATION.md UPLOAD_SIZE_MISMATCH)
    if (buffer.length != session.expectedEncryptedSize) {
      throw StateError('UPLOAD_SIZE_MISMATCH');
    }

    // Concurrency verification (SYNC_ENGINE.md Section 8 VERSION_CONFLICT)
    if (expectedParentVersionId != null) {
      final currentDoc = await documentRepository.getDocumentById(
        session.documentId,
      );
      if (currentDoc != null &&
          currentDoc.currentVersionId != expectedParentVersionId) {
        throw StateError('VERSION_CONFLICT');
      }
    }

    // Persist ciphertext object into cloud storage repository
    final completeData = buffer.takeBytes();
    await storageRepository.putObject(
      objectRef: session.storageObjectPath,
      data: completeData,
    );

    // Mark session committed
    final committed = session.copyWith(status: UploadSessionStatus.committed);
    _sessions[sessionId] = committed;

    final progress = UploadSessionProgress(
      sessionId: sessionId,
      bytesTransferred: session.expectedEncryptedSize,
      totalBytes: session.expectedEncryptedSize,
      fraction: 1.0,
      status: UploadSessionStatus.committed,
    );
    _progressControllers[sessionId]?.add(progress);

    return session.versionId;
  }

  @override
  Future<UploadSession?> getSession(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session != null) {
      _sessions[sessionId] = session.copyWith(
        status: UploadSessionStatus.cancelled,
      );
      _sessionBuffers.remove(sessionId);
      _progressControllers[sessionId]?.close();
      _progressControllers.remove(sessionId);
    }
  }

  @override
  Stream<UploadSessionProgress> watchProgress(String sessionId) {
    return _progressControllers[sessionId]?.stream ?? const Stream.empty();
  }

  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _sessionBuffers.clear();
  }
}
