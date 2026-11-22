import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activity/presentation/controllers/activity_controller.dart';
import '../../../documents/presentation/controllers/documents_controller.dart';
import '../../data/adapters/resumable_cloud_storage_adapter.dart';
import '../../domain/entities/conflict_resolution.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/services/manifest_sync_service.dart';
import '../../domain/services/resumable_transfer_adapter.dart';
import '../../domain/services/sync_worker.dart';

/// Sync UI status states defined in SYNC_ENGINE.md Section 15.
enum SyncStatus {
  upToDate,
  syncing,
  waitingForConnection,
  uploadPending,
  downloadPending,
  conflictNeedsAttention,
  syncFailed,
}

class SyncState {
  final SyncStatus status;
  final int pendingUploadCount;
  final List<SyncOperation> conflicts;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.upToDate,
    this.pendingUploadCount = 0,
    this.conflicts = const [],
    this.isSyncing = false,
    this.lastSyncTime,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingUploadCount,
    List<SyncOperation>? conflicts,
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingUploadCount: pendingUploadCount ?? this.pendingUploadCount,
      conflicts: conflicts ?? this.conflicts,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage,
    );
  }
}

final resumableTransferAdapterProvider = Provider<ResumableTransferAdapter>((
  ref,
) {
  final storageRepo = ref.watch(storageRepositoryProvider);
  final docRepo = ref.watch(documentRepositoryProvider);

  return ResumableCloudStorageAdapter(
    storageRepository: storageRepo,
    documentRepository: docRepo,
  );
});

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final syncQueue = ref.watch(syncQueueRepositoryProvider);
  final docRepo = ref.watch(documentRepositoryProvider);
  final storageRepo = ref.watch(storageRepositoryProvider);
  final activityRepo = ref.watch(activityRepositoryProvider);
  final resumableAdapter = ref.watch(resumableTransferAdapterProvider);

  return SyncWorker(
    syncQueueRepository: syncQueue,
    documentRepository: docRepo,
    storageRepository: storageRepo,
    resumableTransferAdapter: resumableAdapter,
    activityRepository: activityRepo,
  );
});

final manifestSyncServiceProvider = Provider<ManifestSyncService>((ref) {
  final docRepo = ref.watch(documentRepositoryProvider);
  final syncQueue = ref.watch(syncQueueRepositoryProvider);

  return ManifestSyncService(
    documentRepository: docRepo,
    syncQueueRepository: syncQueue,
  );
});

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) {
    final worker = ref.watch(syncWorkerProvider);
    final syncQueue = ref.watch(syncQueueRepositoryProvider);

    return SyncController(syncWorker: worker, syncQueueRepository: syncQueue);
  },
);

class SyncController extends StateNotifier<SyncState> {
  final SyncWorker syncWorker;
  final dynamic syncQueueRepository;

  SyncController({required this.syncWorker, required this.syncQueueRepository})
    : super(const SyncState()) {
    checkQueueState();
  }

  /// Checks the current queue state and updates UI status.
  Future<void> checkQueueState() async {
    try {
      final pendingCount = await syncQueueRepository.getPendingCount();
      final allPending = await syncQueueRepository.getPendingOperations();
      final conflicts = allPending
          .where((op) => op.status == SyncOperationStatus.conflict)
          .toList();

      SyncStatus status = SyncStatus.upToDate;
      if (conflicts.isNotEmpty) {
        status = SyncStatus.conflictNeedsAttention;
      } else if (state.isSyncing) {
        status = SyncStatus.syncing;
      } else if (pendingCount > 0) {
        status = SyncStatus.uploadPending;
      }

      state = state.copyWith(
        status: status,
        pendingUploadCount: pendingCount,
        conflicts: conflicts,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.syncFailed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Initiates an on-demand sync cycle.
  Future<void> syncNow() async {
    if (state.isSyncing) return;

    state = state.copyWith(
      isSyncing: true,
      status: SyncStatus.syncing,
      errorMessage: null,
    );

    try {
      final runResult = await syncWorker.processPendingQueue();

      final now = DateTime.now().toUtc();
      await checkQueueState();

      SyncStatus finalStatus = SyncStatus.upToDate;
      if (runResult.conflictCount > 0 || state.conflicts.isNotEmpty) {
        finalStatus = SyncStatus.conflictNeedsAttention;
      } else if (runResult.retryWaitCount > 0) {
        finalStatus = SyncStatus.waitingForConnection;
      } else if (runResult.failedCount > 0) {
        finalStatus = SyncStatus.syncFailed;
      }

      state = state.copyWith(
        isSyncing: false,
        status: finalStatus,
        lastSyncTime: now,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        status: SyncStatus.syncFailed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Resolves an identified version conflict.
  Future<void> resolveConflict({
    required String operationId,
    required ConflictResolutionStrategy strategy,
    String? newRemoteParentVersionId,
  }) async {
    try {
      await syncWorker.resolveConflict(
        operationId: operationId,
        strategy: strategy,
        newRemoteParentVersionId: newRemoteParentVersionId,
      );
      await syncNow();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Cancels a pending or conflicted sync operation.
  Future<void> cancelOperation(String operationId) async {
    try {
      await syncWorker.cancelOperation(operationId);
      await checkQueueState();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
