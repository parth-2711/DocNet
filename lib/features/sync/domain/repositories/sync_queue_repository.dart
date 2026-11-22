import '../entities/sync_operation.dart';

/// Repository contract for persisting and scheduling sync operations (SYNC_ENGINE.md).
abstract class SyncQueueRepository {
  /// Enqueues a new sync operation prior to initiating network transfer.
  Future<void> enqueue(SyncOperation operation);

  /// Retrieves an operation by ID.
  Future<SyncOperation?> getById(String operationId);

  /// Returns queued operations ready for execution, sorted by creation date.
  Future<List<SyncOperation>> getPendingOperations({int limit = 20});

  /// Updates status and metadata of an operation.
  Future<void> update(SyncOperation operation);

  /// Removes a completed or cancelled operation from the active queue.
  Future<void> delete(String operationId);

  /// Returns the count of pending (non-terminal) operations.
  Future<int> getPendingCount();

  /// Clears all queue records (e.g. on account reset).
  Future<void> clearAll();
}
