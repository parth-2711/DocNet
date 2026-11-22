import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:docnet/features/activity/data/repositories/in_memory_activity_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_storage_repository.dart';
import 'package:docnet/features/documents/domain/entities/document_record.dart';
import 'package:docnet/features/documents/presentation/controllers/documents_controller.dart';
import 'package:docnet/features/documents/presentation/documents_screen.dart';
import 'package:docnet/features/home/presentation/home_screen.dart';
import 'package:docnet/features/security/domain/entities/encrypted_metadata.dart';
import 'package:docnet/features/sync/data/database/app_database.dart';
import 'package:docnet/features/sync/data/repositories/drift_sync_queue_repository.dart';
import 'package:docnet/features/sync/domain/entities/conflict_resolution.dart';
import 'package:docnet/features/sync/domain/entities/sync_manifest.dart';
import 'package:docnet/features/sync/domain/entities/sync_operation.dart';
import 'package:docnet/features/sync/domain/services/manifest_sync_service.dart';
import 'package:docnet/features/sync/domain/services/sync_worker.dart';

DocumentRecord _createDoc({
  required String id,
  required String currentVersionId,
  int versionCount = 1,
  bool isDeleted = false,
}) {
  final now = DateTime.now().toUtc();
  return DocumentRecord(
    documentId: id,
    ownerUid: 'user-1',
    currentVersionId: currentVersionId,
    category: 'Finance',
    versionCount: versionCount,
    isDeleted: isDeleted,
    encryptedMetadata: EncryptedMetadata(
      nonce: Uint8List(12),
      cipherText: Uint8List(16),
      macTag: Uint8List(16),
    ),
    mimeType: 'application/pdf',
    originalSizeBytes: 1024,
    encryptedSizeBytes: 1052,
    createdAt: now,
    updatedAt: now,
    decryptedName: 'Document.pdf',
  );
}

void main() {
  group(
    'SyncManifest & Item Serialization Tests (SYNC_ENGINE.md Section 5)',
    () {
      test('Manifest item converts to and from map with tombstone support', () {
        final now = DateTime.utc(2026, 11, 6, 15, 30);
        final item = SyncManifestItem(
          documentId: 'doc-100',
          vaultScope: 'personal',
          currentVersionId: 'ver-2',
          versionNumber: 2,
          updatedAt: now,
          encryptedMetadataRef: 'users/user-1/doc-100/meta.bin',
          keyEpoch: 1,
          isDeleted: true,
        );

        final map = item.toMap();
        expect(map['documentId'], 'doc-100');
        expect(map['isDeleted'], isTrue);
        expect(map['versionNumber'], 2);

        final reconstituted = SyncManifestItem.fromMap(map);
        expect(reconstituted.documentId, item.documentId);
        expect(reconstituted.isDeleted, isTrue);
        expect(reconstituted.versionNumber, 2);
      });

      test('SyncManifest converts to and from map', () {
        final now = DateTime.utc(2026, 11, 6, 15, 30);
        final manifest = SyncManifest(
          items: [
            SyncManifestItem(
              documentId: 'doc-1',
              vaultScope: 'personal',
              currentVersionId: 'ver-1',
              versionNumber: 1,
              updatedAt: now,
              encryptedMetadataRef: 'meta.bin',
              keyEpoch: 1,
            ),
          ],
          nextCursor: 'cursor-abc',
          hasMore: false,
          timestamp: now,
        );

        final map = manifest.toMap();
        final reconstituted = SyncManifest.fromMap(map);
        expect(reconstituted.items.length, 1);
        expect(reconstituted.nextCursor, 'cursor-abc');
        expect(reconstituted.hasMore, isFalse);
      });
    },
  );

  group('ManifestSyncService Tests (SYNC_ENGINE.md Section 5, 8 & 12)', () {
    late InMemoryDocumentRepository docRepo;
    late AppDatabase db;
    late DriftSyncQueueRepository syncRepo;
    late ManifestSyncService service;

    setUp(() {
      docRepo = InMemoryDocumentRepository();
      db = AppDatabase(NativeDatabase.memory());
      syncRepo = DriftSyncQueueRepository(db);
      service = ManifestSyncService(
        documentRepository: docRepo,
        syncQueueRepository: syncRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'reconcileManifest flags items needing download when remote is newer',
      () async {
        await docRepo.saveDocument(
          _createDoc(
            id: 'doc-local',
            currentVersionId: 'ver-1',
            versionCount: 1,
          ),
        );

        final manifest = SyncManifest(
          items: [
            SyncManifestItem(
              documentId: 'doc-local',
              vaultScope: 'personal',
              currentVersionId: 'ver-2',
              versionNumber: 2,
              updatedAt: DateTime.now().toUtc(),
              encryptedMetadataRef: 'meta.bin',
              keyEpoch: 1,
            ),
          ],
          timestamp: DateTime.now().toUtc(),
        );

        final result = await service.reconcileManifest(manifest);
        expect(result.needsDownload.length, 1);
        expect(result.needsDownload.first.documentId, 'doc-local');
        expect(result.upToDateCount, 0);
      },
    );

    test(
      'reconcileManifest processes remote tombstones and marks local document deleted',
      () async {
        await docRepo.saveDocument(
          _createDoc(
            id: 'doc-deleted',
            currentVersionId: 'ver-1',
            isDeleted: false,
          ),
        );

        final manifest = SyncManifest(
          items: [
            SyncManifestItem(
              documentId: 'doc-deleted',
              vaultScope: 'personal',
              currentVersionId: 'ver-1',
              versionNumber: 1,
              updatedAt: DateTime.now().toUtc(),
              encryptedMetadataRef: 'meta.bin',
              keyEpoch: 1,
              isDeleted: true,
            ),
          ],
          timestamp: DateTime.now().toUtc(),
        );

        final result = await service.reconcileManifest(manifest);
        expect(result.tombstonesProcessed, contains('doc-deleted'));

        final localDoc = await docRepo.getDocumentById('doc-deleted');
        expect(localDoc!.isDeleted, isTrue);
      },
    );

    test(
      'reconcileManifest detects concurrent conflict when local operation has stale parent',
      () async {
        final now = DateTime.now().toUtc();
        await docRepo.saveDocument(
          _createDoc(
            id: 'doc-conflict',
            currentVersionId: 'ver-1',
            versionCount: 1,
          ),
        );

        // Local device prepared a replacement based on ver-1
        await syncRepo.enqueue(
          SyncOperation(
            operationId: 'op-local',
            userId: 'user-1',
            deviceId: 'device-1',
            operationType: SyncOperationType.replace,
            documentId: 'doc-conflict',
            versionId: 'ver-local-2',
            expectedParentVersionId: 'ver-1',
            encryptedPayloadReference: 'payload.bin',
            status: SyncOperationStatus.queued,
            idempotencyKey: 'idemp-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Meanwhile, remote manifest announces ver-remote-2
        final manifest = SyncManifest(
          items: [
            SyncManifestItem(
              documentId: 'doc-conflict',
              vaultScope: 'personal',
              currentVersionId: 'ver-remote-2',
              versionNumber: 2,
              updatedAt: now,
              encryptedMetadataRef: 'meta.bin',
              keyEpoch: 1,
            ),
          ],
          timestamp: now,
        );

        final result = await service.reconcileManifest(manifest);
        expect(result.conflictsDetected, contains('doc-conflict'));
      },
    );
  });

  group(
    'SyncWorker Pipeline & Concurrency Tests (SYNC_ENGINE.md Sections 4, 8 & 9)',
    () {
      late InMemoryDocumentRepository docRepo;
      late InMemoryStorageRepository storageRepo;
      late AppDatabase db;
      late DriftSyncQueueRepository syncRepo;
      late InMemoryActivityRepository activityRepo;
      late SyncWorker worker;

      setUp(() {
        docRepo = InMemoryDocumentRepository();
        storageRepo = InMemoryStorageRepository();
        db = AppDatabase(NativeDatabase.memory());
        syncRepo = DriftSyncQueueRepository(db);
        activityRepo = InMemoryActivityRepository();
        worker = SyncWorker(
          syncQueueRepository: syncRepo,
          documentRepository: docRepo,
          storageRepository: storageRepo,
          activityRepository: activityRepo,
          initialDelaySeconds: 1,
          maxDelaySeconds: 10,
        );
      });

      tearDown(() async {
        activityRepo.dispose();
        await db.close();
      });

      test(
        'processes queued operation to completed state and logs activity',
        () async {
          final now = DateTime.now().toUtc();
          final payloadRef = 'users/user-1/doc-1/ver-1.bin';
          await storageRepo.putObject(
            objectRef: payloadRef,
            data: Uint8List.fromList(utf8.encode('Encrypted content')),
          );

          final op = SyncOperation(
            operationId: 'op-upload-1',
            userId: 'user-1',
            deviceId: 'device-1',
            operationType: SyncOperationType.upload,
            documentId: 'doc-1',
            versionId: 'ver-1',
            encryptedPayloadReference: payloadRef,
            status: SyncOperationStatus.queued,
            idempotencyKey: 'idemp-upload-1',
            createdAt: now,
            updatedAt: now,
          );
          await syncRepo.enqueue(op);

          final resultStatus = await worker.processOperation(op);
          expect(resultStatus, equals(SyncOperationStatus.completed));

          final storedOp = await syncRepo.getById('op-upload-1');
          expect(storedOp!.status, equals(SyncOperationStatus.completed));

          // Audit event was recorded
          final events = await activityRepo.getEvents();
          expect(events.length, 1);
          expect(events.first.summary, 'Encrypted document sync completed');
        },
      );

      test(
        'detects optimistic concurrency conflict and flags VERSION_CONFLICT',
        () async {
          final now = DateTime.now().toUtc();
          // Document in repo already advanced to ver-2
          await docRepo.saveDocument(
            _createDoc(
              id: 'doc-stale',
              currentVersionId: 'ver-2',
              versionCount: 2,
            ),
          );

          final payloadRef = 'users/user-1/doc-stale/ver-3.bin';
          await storageRepo.putObject(
            objectRef: payloadRef,
            data: Uint8List.fromList(utf8.encode('Encrypted content')),
          );

          // Operation expected ver-1 as parent
          final op = SyncOperation(
            operationId: 'op-conflict-1',
            userId: 'user-1',
            deviceId: 'device-1',
            operationType: SyncOperationType.replace,
            documentId: 'doc-stale',
            versionId: 'ver-3',
            expectedParentVersionId: 'ver-1',
            encryptedPayloadReference: payloadRef,
            status: SyncOperationStatus.queued,
            idempotencyKey: 'idemp-conflict-1',
            createdAt: now,
            updatedAt: now,
          );
          await syncRepo.enqueue(op);

          final resultStatus = await worker.processOperation(op);
          expect(resultStatus, equals(SyncOperationStatus.conflict));

          final storedOp = await syncRepo.getById('op-conflict-1');
          expect(storedOp!.status, equals(SyncOperationStatus.conflict));
          expect(storedOp.lastErrorCode, equals('VERSION_CONFLICT'));
        },
      );

      test(
        'handles transient network error with exponential backoff retryWait',
        () async {
          final now = DateTime.now().toUtc();
          final payloadRef = 'users/user-1/doc-retry/ver-1.bin';
          await storageRepo.putObject(
            objectRef: payloadRef,
            data: Uint8List.fromList(utf8.encode('Encrypted content')),
          );

          final op = SyncOperation(
            operationId: 'op-retry-1',
            userId: 'user-1',
            deviceId: 'device-1',
            operationType: SyncOperationType.upload,
            documentId: 'doc-retry',
            versionId: 'ver-1',
            encryptedPayloadReference: payloadRef,
            status: SyncOperationStatus.queued,
            idempotencyKey: 'idemp-retry-1',
            createdAt: now,
            updatedAt: now,
          );
          await syncRepo.enqueue(op);

          final resultStatus = await worker.processOperation(
            op,
            simulateTransientNetworkFailure: true,
          );
          expect(resultStatus, equals(SyncOperationStatus.retryWait));

          final storedOp = await syncRepo.getById('op-retry-1');
          expect(storedOp!.status, equals(SyncOperationStatus.retryWait));
          expect(storedOp.retryCount, equals(1));
          expect(storedOp.nextAttemptAt, isNotNull);
        },
      );

      test(
        'resolves conflict using keepRemote, keepLocal, and saveBoth',
        () async {
          final now = DateTime.now().toUtc();
          final op = SyncOperation(
            operationId: 'op-resolve-1',
            userId: 'user-1',
            deviceId: 'device-1',
            operationType: SyncOperationType.replace,
            documentId: 'doc-resolve',
            versionId: 'ver-local',
            expectedParentVersionId: 'ver-old',
            encryptedPayloadReference: 'payload.bin',
            status: SyncOperationStatus.conflict,
            idempotencyKey: 'idemp-resolve',
            createdAt: now,
            updatedAt: now,
          );
          await syncRepo.enqueue(op);

          // 1. Keep Remote: cancels local op
          await worker.resolveConflict(
            operationId: 'op-resolve-1',
            strategy: ConflictResolutionStrategy.keepRemote,
          );
          var retrieved = await syncRepo.getById('op-resolve-1');
          expect(retrieved!.status, equals(SyncOperationStatus.cancelled));

          // 2. Keep Local: rebases with remote current version
          await worker.resolveConflict(
            operationId: 'op-resolve-1',
            strategy: ConflictResolutionStrategy.keepLocal,
            newRemoteParentVersionId: 'ver-remote-latest',
          );
          retrieved = await syncRepo.getById('op-resolve-1');
          expect(retrieved!.status, equals(SyncOperationStatus.queued));
          expect(
            retrieved.expectedParentVersionId,
            equals('ver-remote-latest'),
          );

          // 3. Save Both: forks new operation with new documentId
          await worker.resolveConflict(
            operationId: 'op-resolve-1',
            strategy: ConflictResolutionStrategy.saveBoth,
          );
          final allPending = await syncRepo.getPendingOperations();
          expect(
            allPending.any((o) => o.operationId != 'op-resolve-1'),
            isTrue,
          );
        },
      );
    },
  );

  group('Sync UI & Controller Tests', () {
    testWidgets(
      'HomeScreen displays live sync state and triggers syncNow on tap',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final syncRepo = DriftSyncQueueRepository(db);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncQueueRepositoryProvider.overrideWithValue(syncRepo),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('This device is up to date.'), findsOneWidget);

        // Tap sync banner to trigger sync
        await tester.tap(find.text('This device is up to date.'));
        await tester.pumpAndSettle();

        expect(find.text('This device is up to date.'), findsOneWidget);
        await db.close();
      },
    );

    testWidgets(
      'DocumentsScreen displays conflict banner and opens resolution dialog',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final syncRepo = DriftSyncQueueRepository(db);
        final now = DateTime.now().toUtc();

        await syncRepo.enqueue(
          SyncOperation(
            operationId: 'op-conflict-ui',
            userId: 'user-1',
            deviceId: 'device-1',
            operationType: SyncOperationType.replace,
            documentId: 'doc-conflict-1234',
            versionId: 'ver-2',
            expectedParentVersionId: 'ver-1',
            encryptedPayloadReference: 'payload.bin',
            status: SyncOperationStatus.conflict,
            idempotencyKey: 'idemp-conflict-ui',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncQueueRepositoryProvider.overrideWithValue(syncRepo),
            ],
            child: const MaterialApp(home: DocumentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 conflict(s) need attention.'), findsOneWidget);

        // Tap "Resolve" button
        await tester.tap(find.text('Resolve'));
        await tester.pumpAndSettle();

        expect(find.text('Version Conflict'), findsOneWidget);
        expect(find.text('Keep Remote'), findsOneWidget);
        expect(find.text('Save Both'), findsOneWidget);
        expect(find.text('Keep Local as New Version'), findsOneWidget);

        // Tap "Keep Remote"
        await tester.tap(find.text('Keep Remote'));
        await tester.pumpAndSettle();

        final op = await syncRepo.getById('op-conflict-ui');
        expect(op!.status, equals(SyncOperationStatus.cancelled));

        await db.close();
      },
    );
  });
}
