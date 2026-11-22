import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

import '../../../activity/domain/entities/activity_event.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../documents/domain/repositories/document_repository.dart';
import '../../../documents/domain/repositories/storage_repository.dart';
import '../entities/conflict_resolution.dart';
import '../entities/sync_operation.dart';
import '../repositories/sync_queue_repository.dart';
import 'resumable_transfer_adapter.dart';

/// Summary result after a sync worker batch cycle.
class SyncWorkerRunResult {
  final int processedCount;
  final int completedCount;
  final int retryWaitCount;
  final int conflictCount;
  final int failedCount;

  const SyncWorkerRunResult({
    this.processedCount = 0,
    this.completedCount = 0,
    this.retryWaitCount = 0,
    this.conflictCount = 0,
    this.failedCount = 0,
  });
}

/// Background synchronization worker executing the offline operation queue state machine
/// (SYNC_ENGINE.md Sections 3, 4, 6, 8, and 9).
class SyncWorker {
  final SyncQueueRepository syncQueueRepository;
  final DocumentRepository documentRepository;
  final StorageRepository storageRepository;
  final ResumableTransferAdapter? resumableTransferAdapter;
  final ActivityRepository? activityRepository;
  final int maxRetries;
  final int initialDelaySeconds;
  final int maxDelaySeconds;
  final Uuid uuid;

  SyncWorker({
    required this.syncQueueRepository,
    required this.documentRepository,
    required this.storageRepository,
    this.resumableTransferAdapter,
    this.activityRepository,
    this.maxRetries = 5,
    this.initialDelaySeconds = 2,
    this.maxDelaySeconds = 300,
    this.uuid = const Uuid(),
  });

  /// Computes exponential backoff delay with jitter (SYNC_ENGINE.md Section 9).
  Duration computeBackoffDelay(int retryCount) {
    final exponent = min(retryCount, 6);
    final delaySec = min(
      maxDelaySeconds,
      initialDelaySeconds * (1 << exponent),
    );
    // Apply 10% to 25% jitter
    final randomJitter = (Random().nextDouble() * 0.25) * delaySec;
    return Duration(seconds: (delaySec + randomJitter).round());
  }

  /// Processes all ready pending queue items in chronological order.
  Future<SyncWorkerRunResult> processPendingQueue() async {
    final operations = await syncQueueRepository.getPendingOperations();
    final now = DateTime.now().toUtc();

    var processed = 0;
    var completed = 0;
    var retryWait = 0;
    var conflicts = 0;
    var failed = 0;

    for (final op in operations) {
      // Check if item in retryWait is ready for execution
      if (op.status == SyncOperationStatus.retryWait) {
        if (op.nextAttemptAt != null && op.nextAttemptAt!.isAfter(now)) {
          continue; // Not yet time to retry
        }
      } else if (op.status != SyncOperationStatus.queued) {
        continue;
      }

      processed++;
      final resultStatus = await processOperation(op);
      switch (resultStatus) {
        case SyncOperationStatus.completed:
          completed++;
          break;
        case SyncOperationStatus.retryWait:
          retryWait++;
          break;
        case SyncOperationStatus.conflict:
          conflicts++;
          break;
        case SyncOperationStatus.failedPermanent:
          failed++;
          break;
        default:
          break;
      }
    }

    return SyncWorkerRunResult(
      processedCount: processed,
      completedCount: completed,
      retryWaitCount: retryWait,
      conflictCount: conflicts,
      failedCount: failed,
    );
  }

  /// Processes a single sync operation through the state machine.
  Future<SyncOperationStatus> processOperation(
    SyncOperation initialOp, {
    bool simulateTransientNetworkFailure = false,
  }) async {
    var op = initialOp;

    try {
      // Step 1: Queued -> Preparing
      if (op.status == SyncOperationStatus.retryWait) {
        op = op.transitionTo(SyncOperationStatus.queued);
        await syncQueueRepository.update(op);
      }

      if (op.canTransitionTo(SyncOperationStatus.preparing)) {
        op = op.transitionTo(SyncOperationStatus.preparing);
        await syncQueueRepository.update(op);
      }

      // Check for optimistic concurrency conflict before uploading (SYNC_ENGINE.md Section 8)
      if (op.expectedParentVersionId != null) {
        final currentDoc = await documentRepository.getDocumentById(
          op.documentId,
        );
        if (currentDoc != null &&
            currentDoc.currentVersionId != op.expectedParentVersionId) {
          // Parent version has already advanced remotely -> VERSION_CONFLICT
          op = op.transitionTo(
            SyncOperationStatus.conflict,
            errorCode: 'VERSION_CONFLICT',
          );
          await syncQueueRepository.update(op);
          return SyncOperationStatus.conflict;
        }
      }

      // Step 2: Preparing -> Uploading
      if (simulateTransientNetworkFailure) {
        throw StateError('Simulated network timeout');
      }

      op = op.transitionTo(SyncOperationStatus.uploading);
      await syncQueueRepository.update(op);

      // Verify payload exists in storage adapter
      final exists = await storageRepository.objectExists(
        op.encryptedPayloadReference,
      );
      if (!exists) {
        throw StateError(
          'Encrypted payload missing from local cache: ${op.encryptedPayloadReference}',
        );
      }

      // If resumable transfer adapter is configured, orchestrate chunked transfer
      if (resumableTransferAdapter != null &&
          op.operationType == SyncOperationType.upload) {
        final payloadData = await storageRepository.getObject(
          op.encryptedPayloadReference,
        );
        if (payloadData == null) {
          throw StateError(
            'Encrypted payload missing from local cache: ${op.encryptedPayloadReference}',
          );
        }
        final session = await resumableTransferAdapter!.requestUploadSession(
          ownerUid: op.userId,
          documentId: op.documentId,
          versionId: op.versionId,
          expectedParentVersionId: op.expectedParentVersionId,
          encryptedSize: payloadData.length,
          idempotencyKey: op.idempotencyKey,
        );

        if (session.uploadedBytes < session.expectedEncryptedSize) {
          await resumableTransferAdapter!.uploadChunk(
            sessionId: session.sessionId,
            chunkBytes: Uint8List.fromList(
              payloadData.sublist(session.uploadedBytes),
            ),
            offset: session.uploadedBytes,
          );
        }

        await resumableTransferAdapter!.completeUploadSession(
          sessionId: session.sessionId,
          versionId: op.versionId,
          expectedParentVersionId: op.expectedParentVersionId,
          encryptedMetadata: const {},
          keyEnvelope: const {},
          idempotencyKey: op.idempotencyKey,
        );
      }

      // Step 3: Uploading -> Uploaded
      op = op.transitionTo(SyncOperationStatus.uploaded);
      await syncQueueRepository.update(op);

      // Step 4: Uploaded -> Committing
      op = op.transitionTo(SyncOperationStatus.committing);
      await syncQueueRepository.update(op);

      // Step 5: Committing -> Completed
      op = op.transitionTo(SyncOperationStatus.completed);
      await syncQueueRepository.update(op);

      // Record zero-knowledge audit trail
      if (activityRepository != null) {
        await activityRepository!.logEvent(
          ActivityEvent(
            activityId: uuid.v4(),
            actorUid: op.userId,
            targetDocumentId: op.documentId,
            eventType: ActivityEventType.documentCreated,
            summary: 'Encrypted document sync completed',
            metadata: {
              'versionId': op.versionId,
              'operationType': op.operationType.name,
            },
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }

      return SyncOperationStatus.completed;
    } catch (e) {
      if (e.toString().contains('VERSION_CONFLICT')) {
        op = op.transitionTo(
          SyncOperationStatus.conflict,
          errorCode: 'VERSION_CONFLICT',
        );
        await syncQueueRepository.update(op);
        return SyncOperationStatus.conflict;
      }

      final isTransient = _isTransientError(e);

      if (isTransient && op.retryCount < maxRetries) {
        final delay = computeBackoffDelay(op.retryCount);
        final nextAttempt = DateTime.now().toUtc().add(delay);

        op = op.transitionTo(
          SyncOperationStatus.retryWait,
          errorCode: e.toString(),
          nextAttempt: nextAttempt,
          incrementRetry: 1,
        );
        await syncQueueRepository.update(op);
        return SyncOperationStatus.retryWait;
      } else {
        op = op.transitionTo(
          SyncOperationStatus.failedPermanent,
          errorCode: e.toString(),
        );
        await syncQueueRepository.update(op);
        return SyncOperationStatus.failedPermanent;
      }
    }
  }

  /// Resolves an existing conflict according to the requested strategy (SYNC_ENGINE.md Section 8).
  Future<void> resolveConflict({
    required String operationId,
    required ConflictResolutionStrategy strategy,
    String? newRemoteParentVersionId,
  }) async {
    final op = await syncQueueRepository.getById(operationId);
    if (op == null) {
      throw StateError('Sync operation not found: $operationId');
    }

    switch (strategy) {
      case ConflictResolutionStrategy.keepRemote:
        // Discard local change
        final cancelled = op.transitionTo(SyncOperationStatus.cancelled);
        await syncQueueRepository.update(cancelled);
        break;

      case ConflictResolutionStrategy.keepLocal:
        // Rebase with remote current version as new parent
        final rebased = SyncOperation(
          operationId: op.operationId,
          userId: op.userId,
          deviceId: op.deviceId,
          operationType: op.operationType,
          documentId: op.documentId,
          versionId: op.versionId,
          expectedParentVersionId: newRemoteParentVersionId,
          encryptedPayloadReference: op.encryptedPayloadReference,
          status: SyncOperationStatus.queued,
          retryCount: 0,
          idempotencyKey: '${op.idempotencyKey}_rebase',
          createdAt: op.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
        await syncQueueRepository.update(rebased);
        break;

      case ConflictResolutionStrategy.saveBoth:
        // Cancel conflicting op and fork as a new document
        final cancelled = op.transitionTo(SyncOperationStatus.cancelled);
        await syncQueueRepository.update(cancelled);

        final forkedDocId = uuid.v4();
        final forkedOp = SyncOperation(
          operationId: uuid.v4(),
          userId: op.userId,
          deviceId: op.deviceId,
          operationType: SyncOperationType.upload,
          documentId: forkedDocId,
          versionId: op.versionId,
          expectedParentVersionId: null,
          encryptedPayloadReference: op.encryptedPayloadReference,
          status: SyncOperationStatus.queued,
          retryCount: 0,
          idempotencyKey: '${forkedDocId}_${op.versionId}_fork',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await syncQueueRepository.enqueue(forkedOp);
        break;
    }
  }

  /// Cancels an active or pending operation.
  Future<void> cancelOperation(String operationId) async {
    final op = await syncQueueRepository.getById(operationId);
    if (op != null && op.canTransitionTo(SyncOperationStatus.cancelled)) {
      final cancelled = op.transitionTo(SyncOperationStatus.cancelled);
      await syncQueueRepository.update(cancelled);
    }
  }

  bool _isTransientError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('version_conflict')) {
      return false;
    }
    return str.contains('timeout') ||
        str.contains('network') ||
        str.contains('connection') ||
        str.contains('503') ||
        str.contains('429') ||
        str.contains('socket');
  }
}
