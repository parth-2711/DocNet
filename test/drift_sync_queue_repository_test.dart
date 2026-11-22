import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/sync/data/database/app_database.dart';
import 'package:docnet/features/sync/data/repositories/drift_sync_queue_repository.dart';
import 'package:docnet/features/sync/domain/entities/sync_operation.dart';

void main() {
  late AppDatabase db;
  late DriftSyncQueueRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftSyncQueueRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  SyncOperation makeOperation({
    required String id,
    SyncOperationStatus status = SyncOperationStatus.queued,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now().toUtc();
    return SyncOperation(
      operationId: id,
      userId: 'user-parth',
      deviceId: 'device-win-1',
      operationType: SyncOperationType.upload,
      documentId: 'doc-$id',
      versionId: 'ver-1',
      encryptedPayloadReference: '/cache/doc-$id.bin',
      status: status,
      idempotencyKey: 'idemp-$id',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('DriftSyncQueueRepository Tests', () {
    test('Enqueues and retrieves sync operation by ID', () async {
      final op = makeOperation(id: 'op-101');
      await repository.enqueue(op);

      final retrieved = await repository.getById('op-101');
      expect(retrieved, isNotNull);
      expect(retrieved!.operationId, equals('op-101'));
      expect(retrieved.userId, equals('user-parth'));
      expect(retrieved.documentId, equals('doc-op-101'));
      expect(retrieved.status, equals(SyncOperationStatus.queued));
    });

    test(
      'getPendingOperations orders by creation and excludes terminal states',
      () async {
        final t1 = DateTime.utc(2026, 1, 1, 10, 0);
        final t2 = DateTime.utc(2026, 1, 1, 11, 0);
        final t3 = DateTime.utc(2026, 1, 1, 12, 0);

        // Enqueue 1 completed (terminal), 2 pending with different timestamps
        await repository.enqueue(makeOperation(id: 'op-late', createdAt: t2));
        await repository.enqueue(makeOperation(id: 'op-early', createdAt: t1));
        await repository.enqueue(
          makeOperation(
            id: 'op-done',
            status: SyncOperationStatus.completed,
            createdAt: t3,
          ),
        );

        final pending = await repository.getPendingOperations();
        expect(pending.length, equals(2));
        expect(pending[0].operationId, equals('op-early'));
        expect(pending[1].operationId, equals('op-late'));
      },
    );

    test(
      'update modifies operation status and error code in database',
      () async {
        final op = makeOperation(id: 'op-202');
        await repository.enqueue(op);

        final updated = op.transitionTo(
          SyncOperationStatus.retryWait,
          errorCode: 'STORAGE_UNAVAILABLE',
          incrementRetry: 1,
        );
        await repository.update(updated);

        final fromDb = await repository.getById('op-202');
        expect(fromDb, isNotNull);
        expect(fromDb!.status, equals(SyncOperationStatus.retryWait));
        expect(fromDb.retryCount, equals(1));
        expect(fromDb.lastErrorCode, equals('STORAGE_UNAVAILABLE'));
      },
    );

    test('delete removes operation from database', () async {
      final op = makeOperation(id: 'op-303');
      await repository.enqueue(op);
      expect(await repository.getPendingCount(), equals(1));

      await repository.delete('op-303');
      expect(await repository.getPendingCount(), equals(0));
      expect(await repository.getById('op-303'), isNull);
    });

    test('clearAll wipes the entire table', () async {
      await repository.enqueue(makeOperation(id: 'op-a'));
      await repository.enqueue(makeOperation(id: 'op-b'));
      expect(await repository.getPendingCount(), equals(2));

      await repository.clearAll();
      expect(await repository.getPendingCount(), equals(0));
    });
  });
}
