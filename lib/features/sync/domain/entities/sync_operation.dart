/// Permitted sync operation types defined in SYNC_ENGINE.md.
enum SyncOperationType { upload, replace, delete, share }

/// Sync operation states defined in the SYNC_ENGINE.md state machine.
enum SyncOperationStatus {
  queued,
  preparing,
  uploading,
  uploaded,
  committing,
  completed,
  retryWait,
  conflict,
  failedPermanent,
  cancelled,
}

/// Immutable record of an operation queued for synchronization.
class SyncOperation {
  final String operationId;
  final String userId;
  final String deviceId;
  final SyncOperationType operationType;
  final String documentId;
  final String versionId;
  final String? expectedParentVersionId;
  final String encryptedPayloadReference;
  final SyncOperationStatus status;
  final int retryCount;
  final DateTime? nextAttemptAt;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastErrorCode;

  const SyncOperation({
    required this.operationId,
    required this.userId,
    required this.deviceId,
    required this.operationType,
    required this.documentId,
    required this.versionId,
    this.expectedParentVersionId,
    required this.encryptedPayloadReference,
    required this.status,
    this.retryCount = 0,
    this.nextAttemptAt,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    this.lastErrorCode,
  });

  /// Validates if transition from current status to [next] is permissible
  /// under the state machine defined in SYNC_ENGINE.md Section 4.
  bool canTransitionTo(SyncOperationStatus next) {
    if (status == next) return true;

    // Terminal states cannot transition
    if (status == SyncOperationStatus.completed ||
        status == SyncOperationStatus.failedPermanent ||
        status == SyncOperationStatus.cancelled) {
      return false;
    }

    // Cancellation and Permanent Failure can be entered from any non-terminal state
    if (next == SyncOperationStatus.cancelled ||
        next == SyncOperationStatus.failedPermanent) {
      return true;
    }

    // Transient errors trigger retryWait from any active state
    if (next == SyncOperationStatus.retryWait) {
      return true;
    }

    switch (status) {
      case SyncOperationStatus.queued:
        return next == SyncOperationStatus.preparing;

      case SyncOperationStatus.preparing:
        return next == SyncOperationStatus.uploading ||
            next == SyncOperationStatus.conflict;

      case SyncOperationStatus.uploading:
        return next == SyncOperationStatus.uploaded;

      case SyncOperationStatus.uploaded:
        return next == SyncOperationStatus.committing;

      case SyncOperationStatus.committing:
        return next == SyncOperationStatus.completed ||
            next == SyncOperationStatus.conflict;

      case SyncOperationStatus.retryWait:
        // After exponential backoff, returns to queued
        return next == SyncOperationStatus.queued;

      case SyncOperationStatus.conflict:
        // A conflict may be resolved and re-queued
        return next == SyncOperationStatus.queued;

      case SyncOperationStatus.completed:
      case SyncOperationStatus.failedPermanent:
      case SyncOperationStatus.cancelled:
        return false;
    }
  }

  /// Produces a new SyncOperation updated to [next] status with timestamps and error codes.
  SyncOperation transitionTo(
    SyncOperationStatus next, {
    String? errorCode,
    DateTime? nextAttempt,
    int? incrementRetry,
  }) {
    if (!canTransitionTo(next)) {
      throw StateError('Illegal sync state transition from $status to $next');
    }

    return SyncOperation(
      operationId: operationId,
      userId: userId,
      deviceId: deviceId,
      operationType: operationType,
      documentId: documentId,
      versionId: versionId,
      expectedParentVersionId: expectedParentVersionId,
      encryptedPayloadReference: encryptedPayloadReference,
      status: next,
      retryCount: incrementRetry != null
          ? retryCount + incrementRetry
          : retryCount,
      nextAttemptAt: nextAttempt ?? nextAttemptAt,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
      lastErrorCode: errorCode ?? lastErrorCode,
    );
  }
}
