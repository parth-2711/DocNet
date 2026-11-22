import 'dart:typed_data';
import '../entities/upload_session.dart';

/// Progress information emitted during chunked resumable transfers.
class UploadSessionProgress {
  final String sessionId;
  final int bytesTransferred;
  final int totalBytes;
  final double fraction;
  final UploadSessionStatus status;

  const UploadSessionProgress({
    required this.sessionId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.fraction,
    required this.status,
  });
}

/// Abstract contract for resumable chunked file transfers (SYNC_ENGINE.md Section 6 & API_SPECIFICATION.md Section 3).
abstract class ResumableTransferAdapter {
  /// Initiates a short-lived upload session (`requestUpload`).
  Future<UploadSession> requestUploadSession({
    required String ownerUid,
    required String documentId,
    required String versionId,
    String? expectedParentVersionId,
    required int encryptedSize,
    required String idempotencyKey,
    Duration expiry = const Duration(minutes: 15),
  });

  /// Uploads a byte chunk resuming from [offset] bytes.
  Future<UploadSessionProgress> uploadChunk({
    required String sessionId,
    required Uint8List chunkBytes,
    required int offset,
  });

  /// Commits the uploaded session and transactionally verifies expected parent version (`completeUpload`).
  Future<String> completeUploadSession({
    required String sessionId,
    required String versionId,
    String? expectedParentVersionId,
    required Map<String, dynamic> encryptedMetadata,
    required Map<String, dynamic> keyEnvelope,
    required String idempotencyKey,
  });

  /// Retrieves current session state.
  Future<UploadSession?> getSession(String sessionId);

  /// Cancels an active session.
  Future<void> cancelSession(String sessionId);

  /// Observes transfer progress for a specific session.
  Stream<UploadSessionProgress> watchProgress(String sessionId);
}
