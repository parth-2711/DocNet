import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/core/constants/app_constants.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'package:docnet/features/sync/domain/entities/sync_operation.dart';
import 'package:docnet/features/sync/domain/repositories/sync_queue_repository.dart';

class MockSyncQueueRepository implements SyncQueueRepository {
  final List<SyncOperation> queue = [];

  @override
  Future<void> enqueue(SyncOperation operation) async {
    queue.add(operation);
  }

  @override
  Future<void> clearAll() async => queue.clear();
  @override
  Future<void> delete(String operationId) async =>
      queue.removeWhere((o) => o.operationId == operationId);
  @override
  Future<SyncOperation?> getById(String operationId) async =>
      queue.firstWhere((o) => o.operationId == operationId);
  @override
  Future<int> getPendingCount() async => queue.length;
  @override
  Future<List<SyncOperation>> getPendingOperations({int limit = 20}) async =>
      queue;
  @override
  Future<void> update(SyncOperation operation) async {}
}

void main() {
  late CryptographyCryptoService cryptoService;
  late InMemoryDocumentRepository documentRepo;
  late MockSyncQueueRepository syncQueue;
  late UploadDocumentUseCase uploadUseCase;

  setUp(() {
    cryptoService = CryptographyCryptoService();
    documentRepo = InMemoryDocumentRepository();
    syncQueue = MockSyncQueueRepository();
    uploadUseCase = UploadDocumentUseCase(
      cryptoService: cryptoService,
      documentRepository: documentRepo,
      syncQueueRepository: syncQueue,
    );
  });

  group('UploadDocumentUseCase Tests', () {
    test(
      'Rejects unsupported file format with clear error (DOC-002)',
      () async {
        final bytes = Uint8List.fromList(
          utf8.encode('malicious script or executable'),
        );

        expect(
          () async => await uploadUseCase.execute(
            fileBytes: bytes,
            fileName: 'malicious.exe',
            category: 'Identity',
            ownerUid: 'uid-parth',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unsupported file type'),
            ),
          ),
        );
      },
    );

    test('Rejects files exceeding 25 MB size limit (DOC-003)', () async {
      // 26 MB dummy representation
      final oversizedBytes = Uint8List(AppConstants.maxFileSizeBytes + 1024);

      expect(
        () async => await uploadUseCase.execute(
          fileBytes: oversizedBytes,
          fileName: 'large_scan.pdf',
          category: 'Identity',
          ownerUid: 'uid-parth',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('exceeds the 25 MB maximum limit'),
          ),
        ),
      );
    });

    test('Encrypts and enqueues valid PDF document upload', () async {
      final plainText = Uint8List.fromList(
        utf8.encode('Confidential Identity Document PDF Content'),
      );

      final result = await uploadUseCase.execute(
        fileBytes: plainText,
        fileName: 'Aadhaar_Card.pdf',
        category: 'Identity',
        ownerUid: 'uid-parth',
        description: 'Verified e-Aadhaar card copy',
      );

      // 1. Verify Document Record
      expect(result.document.category, equals('Identity'));
      expect(result.document.decryptedName, equals('Aadhaar_Card.pdf'));
      expect(
        result.document.decryptedDescription,
        equals('Verified e-Aadhaar card copy'),
      );
      expect(result.document.originalSizeBytes, equals(plainText.length));
      expect(result.document.encryptedSizeBytes, greaterThan(plainText.length));

      // 2. Verify Immutable Version Record (VER-002)
      expect(result.version.versionNumber, equals(1));
      expect(result.version.sha256, isNotEmpty);
      expect(
        result.version.storageObjectRef,
        contains(result.document.documentId),
      );
      expect(
        result.version.storageObjectRef,
        contains(result.version.versionId),
      );
      expect(result.version.storageObjectRef, isNot(contains('Aadhaar_Card')));

      // 3. Verify Key Envelope (KEY-001, ENCRYPTION.md Section 7)
      expect(result.envelope.recipientId, equals('uid-parth'));
      expect(result.envelope.wrappedDek, isNotEmpty);

      // 4. Verify Operation was enqueued to SyncQueue (SYNC_ENGINE.md Section 3)
      expect(syncQueue.queue.length, equals(1));
      expect(
        syncQueue.queue.first.operationType,
        equals(SyncOperationType.upload),
      );
      expect(syncQueue.queue.first.status, equals(SyncOperationStatus.queued));

      // 5. Verify Repository persistence
      final fromRepo = await documentRepo.getDocumentById(
        result.document.documentId,
      );
      expect(fromRepo, isNotNull);
      expect(fromRepo!.documentId, equals(result.document.documentId));
    });

    test(
      'Replacing document increments version and sets parentVersionId (VER-002, VER-003)',
      () async {
        final v1Bytes = Uint8List.fromList(utf8.encode('Version 1 Content'));
        final v2Bytes = Uint8List.fromList(
          utf8.encode('Version 2 Updated Content'),
        );

        // Upload Version 1
        final v1Result = await uploadUseCase.execute(
          fileBytes: v1Bytes,
          fileName: 'License.png',
          category: 'Driving',
          ownerUid: 'uid-parth',
        );

        // Upload Version 2 (Replacement)
        final v2Result = await uploadUseCase.execute(
          fileBytes: v2Bytes,
          fileName: 'License.png',
          category: 'Driving',
          ownerUid: 'uid-parth',
          existingDocumentId: v1Result.document.documentId,
          expectedParentVersionId: v1Result.version.versionId,
        );

        expect(
          v2Result.document.documentId,
          equals(v1Result.document.documentId),
        );
        expect(v2Result.version.versionNumber, equals(2));
        expect(
          v2Result.version.parentVersionId,
          equals(v1Result.version.versionId),
        );

        final allVersions = await documentRepo.getVersions(
          v1Result.document.documentId,
        );
        expect(allVersions.length, equals(2));
        expect(allVersions[0].versionNumber, equals(2));
        expect(allVersions[1].versionNumber, equals(1));
      },
    );
  });
}
