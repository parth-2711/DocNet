import '../../../documents/domain/repositories/document_repository.dart';
import '../entities/sync_manifest.dart';
import '../entities/sync_operation.dart';
import '../repositories/sync_queue_repository.dart';

/// Result produced when reconciling an incoming remote manifest against local state.
class ManifestReconciliationResult {
  final List<SyncManifestItem> needsDownload;
  final List<String> tombstonesProcessed;
  final List<String> conflictsDetected;
  final int upToDateCount;

  const ManifestReconciliationResult({
    this.needsDownload = const [],
    this.tombstonesProcessed = const [],
    this.conflictsDetected = const [],
    this.upToDateCount = 0,
  });
}

/// Service that evaluates remote manifest items against the local repository and queue
/// (SYNC_ENGINE.md Section 5, 8, and 12).
class ManifestSyncService {
  final DocumentRepository documentRepository;
  final SyncQueueRepository syncQueueRepository;

  const ManifestSyncService({
    required this.documentRepository,
    required this.syncQueueRepository,
  });

  /// Reconciles an incoming paginated manifest against local state.
  Future<ManifestReconciliationResult> reconcileManifest(
    SyncManifest manifest,
  ) async {
    final needsDownload = <SyncManifestItem>[];
    final tombstonesProcessed = <String>[];
    final conflictsDetected = <String>[];
    var upToDateCount = 0;

    for (final remoteItem in manifest.items) {
      final localDoc = await documentRepository.getDocumentById(
        remoteItem.documentId,
      );

      // Check if there is an active/pending local operation on this document
      final pendingOps = await syncQueueRepository.getPendingOperations();
      final localOp = pendingOps
          .where((op) => op.documentId == remoteItem.documentId)
          .firstOrNull;

      // 1. Process Tombstones / Deletions (SYNC_ENGINE.md Section 12)
      if (remoteItem.isDeleted) {
        if (localDoc != null && !localDoc.isDeleted) {
          await documentRepository.softDeleteDocument(remoteItem.documentId);
          tombstonesProcessed.add(remoteItem.documentId);
        }
        continue;
      }

      // 2. Check for Concurrent Conflicts (SYNC_ENGINE.md Section 8)
      if (localOp != null &&
          localOp.status != SyncOperationStatus.completed &&
          localOp.status != SyncOperationStatus.cancelled) {
        if (localOp.expectedParentVersionId != null &&
            localOp.expectedParentVersionId != remoteItem.currentVersionId) {
          // Local operation expects an older parent, but remote has advanced!
          conflictsDetected.add(remoteItem.documentId);
          continue;
        }
      }

      // 3. New Document or Newer Version Available on Remote
      if (localDoc == null) {
        needsDownload.add(remoteItem);
      } else if (remoteItem.versionNumber > localDoc.versionCount ||
          remoteItem.currentVersionId != localDoc.currentVersionId) {
        needsDownload.add(remoteItem);
      } else {
        upToDateCount++;
      }
    }

    return ManifestReconciliationResult(
      needsDownload: List.unmodifiable(needsDownload),
      tombstonesProcessed: List.unmodifiable(tombstonesProcessed),
      conflictsDetected: List.unmodifiable(conflictsDetected),
      upToDateCount: upToDateCount,
    );
  }
}
