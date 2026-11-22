import 'package:drift/drift.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../database/app_database.dart';

/// Drift-backed implementation of SyncQueueRepository (SYNC_ENGINE.md Section 3).
class DriftSyncQueueRepository implements SyncQueueRepository {
  final AppDatabase _db;

  DriftSyncQueueRepository(this._db);

  SyncOperation _toDomain(SyncOperationsTableData row) {
    return SyncOperation(
      operationId: row.operationId,
      userId: row.userId,
      deviceId: row.deviceId,
      operationType: SyncOperationType.values.byName(row.operationType),
      documentId: row.documentId,
      versionId: row.versionId,
      expectedParentVersionId: row.expectedParentVersionId,
      encryptedPayloadReference: row.encryptedPayloadReference,
      status: SyncOperationStatus.values.byName(row.status),
      retryCount: row.retryCount,
      nextAttemptAt: row.nextAttemptAt,
      idempotencyKey: row.idempotencyKey,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastErrorCode: row.lastErrorCode,
    );
  }

  SyncOperationsTableCompanion _toCompanion(SyncOperation op) {
    return SyncOperationsTableCompanion(
      operationId: Value(op.operationId),
      userId: Value(op.userId),
      deviceId: Value(op.deviceId),
      operationType: Value(op.operationType.name),
      documentId: Value(op.documentId),
      versionId: Value(op.versionId),
      expectedParentVersionId: Value(op.expectedParentVersionId),
      encryptedPayloadReference: Value(op.encryptedPayloadReference),
      status: Value(op.status.name),
      retryCount: Value(op.retryCount),
      nextAttemptAt: Value(op.nextAttemptAt),
      idempotencyKey: Value(op.idempotencyKey),
      createdAt: Value(op.createdAt),
      updatedAt: Value(op.updatedAt),
      lastErrorCode: Value(op.lastErrorCode),
    );
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    await _db
        .into(_db.syncOperationsTable)
        .insertOnConflictUpdate(_toCompanion(operation));
  }

  @override
  Future<SyncOperation?> getById(String operationId) async {
    final query = _db.select(_db.syncOperationsTable)
      ..where((tbl) => tbl.operationId.equals(operationId));
    final row = await query.getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<List<SyncOperation>> getPendingOperations({int limit = 20}) async {
    final terminalStatuses = [
      SyncOperationStatus.completed.name,
      SyncOperationStatus.cancelled.name,
      SyncOperationStatus.failedPermanent.name,
    ];

    final query = _db.select(_db.syncOperationsTable)
      ..where((tbl) => tbl.status.isNotIn(terminalStatuses))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> update(SyncOperation operation) async {
    await _db.update(_db.syncOperationsTable).replace(_toCompanion(operation));
  }

  @override
  Future<void> delete(String operationId) async {
    await (_db.delete(
      _db.syncOperationsTable,
    )..where((tbl) => tbl.operationId.equals(operationId))).go();
  }

  @override
  Future<int> getPendingCount() async {
    final terminalStatuses = [
      SyncOperationStatus.completed.name,
      SyncOperationStatus.cancelled.name,
      SyncOperationStatus.failedPermanent.name,
    ];

    final countExp = _db.syncOperationsTable.operationId.count();
    final query = _db.selectOnly(_db.syncOperationsTable)
      ..addColumns([countExp])
      ..where(_db.syncOperationsTable.status.isNotIn(terminalStatuses));

    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<void> clearAll() async {
    await _db.delete(_db.syncOperationsTable).go();
  }
}
