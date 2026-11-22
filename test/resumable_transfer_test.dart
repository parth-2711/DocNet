import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docnet/features/activity/data/repositories/in_memory_activity_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_storage_repository.dart';
import 'package:docnet/features/documents/domain/entities/document_record.dart';
import 'package:docnet/features/security/domain/entities/encrypted_metadata.dart';
import 'package:docnet/features/sync/data/adapters/resumable_cloud_storage_adapter.dart';
import 'package:docnet/features/sync/data/database/app_database.dart';
import 'package:docnet/features/sync/data/repositories/drift_sync_queue_repository.dart';
import 'package:docnet/features/sync/domain/entities/upload_session.dart';
import 'package:docnet/features/sync/domain/entities/sync_operation.dart';
import 'package:docnet/features/sync/domain/services/resumable_transfer_adapter.dart';
import 'package:docnet/features/sync/domain/services/sync_worker.dart';

DocumentRecord _createDoc({
  required String id,
  required String currentVersionId,
}) {
  final now = DateTime.now().toUtc();
  return DocumentRecord(
    documentId: id,
    ownerUid: 'user-alice',
    currentVersionId: currentVersionId,
    category: 'Finance',
    versionCount: 1,
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
    decryptedName: 'BankStatement.pdf',
  );
}

void main() {
  group(
    'UploadSession Entity & Serialization Tests (SYNC_ENGINE.md Section 6)',
    () {
      test('UploadSession converts to and from map with all fields intact', () {
        final now = DateTime.now().toUtc();
        final expires = now.add(const Duration(minutes: 15));
        final session = UploadSession(
          sessionId: 'sess-123',
          ownerUid: 'user-alice',
          documentId: 'doc-456',
          versionId: 'ver-789',
          expectedParentVersionId: 'ver-parent',
          storageObjectPath:
              'users/user-alice/documents/doc-456/versions/ver-789.bin',
          expectedEncryptedSize: 2048,
          status: UploadSessionStatus.uploading,
          uploadedBytes: 1024,
          createdAt: now,
          expiresAt: expires,
          idempotencyKey: 'idemp-key-1',
        );

        final map = session.toMap();
        expect(map['sessionId'], 'sess-123');
        expect(map['ownerUid'], 'user-alice');
        expect(map['documentId'], 'doc-456');
        expect(map['versionId'], 'ver-789');
        expect(map['expectedParentVersionId'], 'ver-parent');
        expect(map['expectedEncryptedSize'], 2048);
        expect(map['status'], 'uploading');
        expect(map['uploadedBytes'], 1024);
        expect(map['idempotencyKey'], 'idemp-key-1');

        final reconstituted = UploadSession.fromMap(map);
        expect(reconstituted.sessionId, session.sessionId);
        expect(reconstituted.ownerUid, session.ownerUid);
        expect(reconstituted.documentId, session.documentId);
        expect(reconstituted.versionId, session.versionId);
        expect(
          reconstituted.expectedParentVersionId,
          session.expectedParentVersionId,
        );
        expect(reconstituted.expectedEncryptedSize, 2048);
        expect(reconstituted.status, UploadSessionStatus.uploading);
        expect(reconstituted.uploadedBytes, 1024);
        expect(reconstituted.progressFraction, 0.5);
        expect(reconstituted.isExpired, isFalse);
      });

      test('isExpired detects expired sessions', () {
        final past = DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        );
        final session = UploadSession(
          sessionId: 'sess-expired',
          ownerUid: 'user-alice',
          documentId: 'doc-1',
          versionId: 'ver-1',
          storageObjectPath: 'path.bin',
          expectedEncryptedSize: 100,
          createdAt: past.subtract(const Duration(minutes: 15)),
          expiresAt: past,
          idempotencyKey: 'idemp-expired',
        );

        expect(session.isExpired, isTrue);
      });
    },
  );

  group(
    'ResumableCloudStorageAdapter Tests (SYNC_ENGINE.md Section 6, API_SPECIFICATION.md Section 3)',
    () {
      late InMemoryStorageRepository storageRepo;
      late InMemoryDocumentRepository docRepo;
      late ResumableCloudStorageAdapter adapter;

      setUp(() {
        storageRepo = InMemoryStorageRepository();
        docRepo = InMemoryDocumentRepository();
        adapter = ResumableCloudStorageAdapter(
          storageRepository: storageRepo,
          documentRepository: docRepo,
        );
      });

      tearDown(() {
        adapter.dispose();
      });

      test('requestUploadSession validates size and creates session', () async {
        expect(
          () => adapter.requestUploadSession(
            ownerUid: 'user-alice',
            documentId: 'doc-1',
            versionId: 'ver-1',
            encryptedSize: 0,
            idempotencyKey: 'idemp-0',
          ),
          throwsArgumentError,
        );

        final session = await adapter.requestUploadSession(
          ownerUid: 'user-alice',
          documentId: 'doc-1',
          versionId: 'ver-1',
          encryptedSize: 500,
          idempotencyKey: 'idemp-valid',
        );

        expect(session.sessionId, isNotEmpty);
        expect(session.ownerUid, 'user-alice');
        expect(session.documentId, 'doc-1');
        expect(session.versionId, 'ver-1');
        expect(session.expectedEncryptedSize, 500);
        expect(session.status, UploadSessionStatus.created);
        expect(
          session.storageObjectPath,
          'users/user-alice/documents/doc-1/versions/ver-1.bin',
        );

        // Idempotency: requesting with same key returns identical session
        final duplicate = await adapter.requestUploadSession(
          ownerUid: 'user-alice',
          documentId: 'doc-1',
          versionId: 'ver-1',
          encryptedSize: 500,
          idempotencyKey: 'idemp-valid',
        );
        expect(duplicate.sessionId, session.sessionId);
      });

      test('uploadChunk transfers chunks and emits progress events', () async {
        final session = await adapter.requestUploadSession(
          ownerUid: 'user-alice',
          documentId: 'doc-chunks',
          versionId: 'ver-1',
          encryptedSize: 10,
          idempotencyKey: 'idemp-chunks',
        );

        final progressEvents = <UploadSessionProgress>[];
        final subscription = adapter
            .watchProgress(session.sessionId)
            .listen(progressEvents.add);

        final chunk1 = Uint8List.fromList([1, 2, 3, 4]);
        final p1 = await adapter.uploadChunk(
          sessionId: session.sessionId,
          chunkBytes: chunk1,
          offset: 0,
        );
        expect(p1.bytesTransferred, 4);
        expect(p1.fraction, 0.4);
        expect(p1.status, UploadSessionStatus.uploading);

        final chunk2 = Uint8List.fromList([5, 6, 7, 8, 9, 10]);
        final p2 = await adapter.uploadChunk(
          sessionId: session.sessionId,
          chunkBytes: chunk2,
          offset: 4,
        );
        expect(p2.bytesTransferred, 10);
        expect(p2.fraction, 1.0);
        expect(p2.status, UploadSessionStatus.uploaded);

        // Verify streamed events
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(progressEvents.length, 2);
        expect(progressEvents.first.bytesTransferred, 4);
        expect(progressEvents.last.bytesTransferred, 10);

        await subscription.cancel();
      });

      test('uploadChunk rejects invalid offset', () async {
        final session = await adapter.requestUploadSession(
          ownerUid: 'user-alice',
          documentId: 'doc-offset',
          versionId: 'ver-1',
          encryptedSize: 10,
          idempotencyKey: 'idemp-offset',
        );

        expect(
          () => adapter.uploadChunk(
            sessionId: session.sessionId,
            chunkBytes: Uint8List.fromList([1, 2]),
            offset: 5, // Invalid offset: buffer is at 0
          ),
          throwsArgumentError,
        );
      });

      test(
        'completeUploadSession verifies size and commits payload to StorageRepository',
        () async {
          final payload = Uint8List.fromList(
            utf8.encode('Encrypted ciphertext payload content'),
          );
          final session = await adapter.requestUploadSession(
            ownerUid: 'user-alice',
            documentId: 'doc-commit',
            versionId: 'ver-1',
            encryptedSize: payload.length,
            idempotencyKey: 'idemp-commit',
          );

          await adapter.uploadChunk(
            sessionId: session.sessionId,
            chunkBytes: payload,
            offset: 0,
          );

          final committedVersionId = await adapter.completeUploadSession(
            sessionId: session.sessionId,
            versionId: 'ver-1',
            encryptedMetadata: const {},
            keyEnvelope: const {},
            idempotencyKey: 'idemp-commit',
          );

          expect(committedVersionId, 'ver-1');

          // Verify payload is now present in cloud storage
          final exists = await storageRepo.objectExists(
            session.storageObjectPath,
          );
          expect(exists, isTrue);

          final retrieved = await storageRepo.getObject(
            session.storageObjectPath,
          );
          expect(retrieved, payload);

          // Idempotency: repeating commit returns versionId safely without error
          final secondCommit = await adapter.completeUploadSession(
            sessionId: session.sessionId,
            versionId: 'ver-1',
            encryptedMetadata: const {},
            keyEnvelope: const {},
            idempotencyKey: 'idemp-commit',
          );
          expect(secondCommit, 'ver-1');
        },
      );

      test(
        'completeUploadSession enforces UPLOAD_SIZE_MISMATCH when incomplete',
        () async {
          final session = await adapter.requestUploadSession(
            ownerUid: 'user-alice',
            documentId: 'doc-size-err',
            versionId: 'ver-1',
            encryptedSize: 100,
            idempotencyKey: 'idemp-size-err',
          );

          // Upload only 50 bytes
          await adapter.uploadChunk(
            sessionId: session.sessionId,
            chunkBytes: Uint8List(50),
            offset: 0,
          );

          expect(
            () => adapter.completeUploadSession(
              sessionId: session.sessionId,
              versionId: 'ver-1',
              encryptedMetadata: const {},
              keyEnvelope: const {},
              idempotencyKey: 'idemp-size-err',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('UPLOAD_SIZE_MISMATCH'),
              ),
            ),
          );
        },
      );

      test(
        'completeUploadSession detects VERSION_CONFLICT against current document version',
        () async {
          await docRepo.saveDocument(
            _createDoc(id: 'doc-conflict', currentVersionId: 'ver-remote-2'),
          );

          final session = await adapter.requestUploadSession(
            ownerUid: 'user-alice',
            documentId: 'doc-conflict',
            versionId: 'ver-local-2',
            expectedParentVersionId: 'ver-remote-1', // Stale parent!
            encryptedSize: 10,
            idempotencyKey: 'idemp-confl',
          );

          await adapter.uploadChunk(
            sessionId: session.sessionId,
            chunkBytes: Uint8List(10),
            offset: 0,
          );

          expect(
            () => adapter.completeUploadSession(
              sessionId: session.sessionId,
              versionId: 'ver-local-2',
              expectedParentVersionId: 'ver-remote-1',
              encryptedMetadata: const {},
              keyEnvelope: const {},
              idempotencyKey: 'idemp-confl',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('VERSION_CONFLICT'),
              ),
            ),
          );
        },
      );

      test(
        'cancelSession terminates active session and frees buffers',
        () async {
          final session = await adapter.requestUploadSession(
            ownerUid: 'user-alice',
            documentId: 'doc-cancel',
            versionId: 'ver-1',
            encryptedSize: 50,
            idempotencyKey: 'idemp-cancel',
          );

          await adapter.cancelSession(session.sessionId);

          final updated = await adapter.getSession(session.sessionId);
          expect(updated!.status, UploadSessionStatus.cancelled);
        },
      );
    },
  );

  group('SyncWorker & ResumableTransferAdapter Integration Tests', () {
    late InMemoryDocumentRepository docRepo;
    late InMemoryStorageRepository storageRepo;
    late AppDatabase db;
    late DriftSyncQueueRepository syncRepo;
    late InMemoryActivityRepository activityRepo;
    late ResumableCloudStorageAdapter adapter;
    late SyncWorker worker;

    setUp(() {
      docRepo = InMemoryDocumentRepository();
      storageRepo = InMemoryStorageRepository();
      db = AppDatabase(NativeDatabase.memory());
      syncRepo = DriftSyncQueueRepository(db);
      activityRepo = InMemoryActivityRepository();
      adapter = ResumableCloudStorageAdapter(
        storageRepository: storageRepo,
        documentRepository: docRepo,
      );
      worker = SyncWorker(
        syncQueueRepository: syncRepo,
        documentRepository: docRepo,
        storageRepository: storageRepo,
        resumableTransferAdapter: adapter,
        activityRepository: activityRepo,
      );
    });

    tearDown(() async {
      adapter.dispose();
      activityRepo.dispose();
      await db.close();
    });

    test(
      'SyncWorker processes upload operation end-to-end via ResumableTransferAdapter',
      () async {
        final now = DateTime.now().toUtc();
        final payloadRef = 'users/user-alice/doc-1/ver-1.bin';
        final payloadData = Uint8List.fromList(
          utf8.encode('Encrypted content for resumable upload'),
        );

        // Put initial payload into storage repository (representing local device cache)
        await storageRepo.putObject(objectRef: payloadRef, data: payloadData);

        final op = SyncOperation(
          operationId: 'op-resumable-1',
          userId: 'user-alice',
          deviceId: 'device-1',
          operationType: SyncOperationType.upload,
          documentId: 'doc-1',
          versionId: 'ver-1',
          encryptedPayloadReference: payloadRef,
          status: SyncOperationStatus.queued,
          idempotencyKey: 'idemp-resumable-1',
          createdAt: now,
          updatedAt: now,
        );
        await syncRepo.enqueue(op);

        final resultStatus = await worker.processOperation(op);
        expect(resultStatus, SyncOperationStatus.completed);

        // Verify the session was created and committed into canonical cloud storage path
        final canonicalPath =
            'users/user-alice/documents/doc-1/versions/ver-1.bin';
        final exists = await storageRepo.objectExists(canonicalPath);
        expect(exists, isTrue);

        final storedData = await storageRepo.getObject(canonicalPath);
        expect(storedData, payloadData);
      },
    );

    test(
      'SyncWorker catches VERSION_CONFLICT thrown by ResumableTransferAdapter during commit',
      () async {
        final now = DateTime.now().toUtc();
        final payloadRef = 'users/user-alice/doc-conflict/ver-local.bin';
        await storageRepo.putObject(
          objectRef: payloadRef,
          data: Uint8List.fromList([1, 2, 3, 4]),
        );

        // Save document with already advanced version ver-remote-2
        await docRepo.saveDocument(
          _createDoc(id: 'doc-conflict', currentVersionId: 'ver-remote-2'),
        );

        final op = SyncOperation(
          operationId: 'op-conflict-1',
          userId: 'user-alice',
          deviceId: 'device-1',
          operationType: SyncOperationType.upload,
          documentId: 'doc-conflict',
          versionId: 'ver-local-2',
          expectedParentVersionId: 'ver-remote-1', // Outdated parent version
          encryptedPayloadReference: payloadRef,
          status: SyncOperationStatus.queued,
          idempotencyKey: 'idemp-conflict-1',
          createdAt: now,
          updatedAt: now,
        );
        await syncRepo.enqueue(op);

        final resultStatus = await worker.processOperation(op);
        expect(resultStatus, SyncOperationStatus.conflict);

        final updatedOp = await syncRepo.getById('op-conflict-1');
        expect(updatedOp!.status, SyncOperationStatus.conflict);
        expect(updatedOp.lastErrorCode, 'VERSION_CONFLICT');
      },
    );
  });
}
