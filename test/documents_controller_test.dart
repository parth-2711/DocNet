import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/documents/presentation/controllers/documents_controller.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'upload_document_usecase_test.dart';

void main() {
  late InMemoryDocumentRepository documentRepo;
  late MockSyncQueueRepository syncQueue;
  late UploadDocumentUseCase uploadUseCase;
  late DocumentsController controller;

  setUp(() {
    documentRepo = InMemoryDocumentRepository();
    syncQueue = MockSyncQueueRepository();
    uploadUseCase = UploadDocumentUseCase(
      cryptoService: CryptographyCryptoService(),
      documentRepository: documentRepo,
      syncQueueRepository: syncQueue,
    );
    controller = DocumentsController(
      docRepo: documentRepo,
      uploadUseCase: uploadUseCase,
      currentUserUid: 'uid-test-1',
    );
  });

  group('DocumentsController Tests', () {
    test('Initial documents list is empty', () {
      expect(controller.state.documents, isEmpty);
      expect(controller.state.selectedCategory, equals('All'));
    });

    test('Uploads document and refreshes list', () async {
      final bytes = Uint8List.fromList(utf8.encode('PDF file sample'));

      await controller.uploadDocument(
        fileBytes: bytes,
        fileName: 'Degree.pdf',
        category: 'Education',
        description: 'University graduation degree',
      );

      expect(controller.state.documents.length, equals(1));
      expect(
        controller.state.documents.first.decryptedName,
        equals('Degree.pdf'),
      );
      expect(controller.state.documents.first.category, equals('Education'));
    });

    test('Filters documents by category', () async {
      final b1 = Uint8List.fromList(utf8.encode('doc1'));
      final b2 = Uint8List.fromList(utf8.encode('doc2'));

      await controller.uploadDocument(
        fileBytes: b1,
        fileName: 'Id.pdf',
        category: 'Identity',
      );
      await controller.uploadDocument(
        fileBytes: b2,
        fileName: 'Tax.pdf',
        category: 'Financial',
      );

      expect(controller.state.documents.length, equals(2));

      await controller.selectCategory('Identity');
      expect(controller.state.documents.length, equals(1));
      expect(controller.state.documents.first.category, equals('Identity'));

      await controller.selectCategory('Financial');
      expect(controller.state.documents.length, equals(1));
      expect(controller.state.documents.first.category, equals('Financial'));

      await controller.selectCategory('All');
      expect(controller.state.documents.length, equals(2));
    });

    test('getKeyEnvelope heals legacy demo and normalized UID mismatches', () async {
      final bytes = Uint8List.fromList(utf8.encode('PDF file sample'));
      final result = await controller.uploadDocument(
        fileBytes: bytes,
        fileName: 'Passport.pdf',
        category: 'Identity',
      );

      // Verify exact match
      final direct = await documentRepo.getKeyEnvelope(
        documentId: result.document.documentId,
        recipientId: 'uid-test-1',
      );
      expect(direct, isNotNull);

      // Verify normalized Google UID match
      final googleMatch = await documentRepo.getKeyEnvelope(
        documentId: result.document.documentId,
        recipientId: 'uid-google-test-1',
      );
      expect(googleMatch, isNotNull);
      expect(googleMatch!.wrappedDek, equals(direct!.wrappedDek));
    });

    test('deleteDocument soft deletes and removes from state, restoreDocument restores it', () async {
      final bytes = Uint8List.fromList(utf8.encode('PDF to delete'));
      final result = await controller.uploadDocument(
        fileBytes: bytes,
        fileName: 'OldBill.pdf',
        category: 'Financial',
      );

      expect(controller.state.documents.any((d) => d.documentId == result.document.documentId), isTrue);

      // Soft delete
      await controller.deleteDocument(documentId: result.document.documentId);
      expect(controller.state.documents.any((d) => d.documentId == result.document.documentId), isFalse);

      final repoDoc = await documentRepo.getDocumentById(result.document.documentId);
      expect(repoDoc, isNotNull);
      expect(repoDoc!.isDeleted, isTrue);

      // Undo / restore
      await controller.restoreDocument(result.document.documentId);
      expect(controller.state.documents.any((d) => d.documentId == result.document.documentId), isTrue);
    });

    test('Multi-account isolation: User B cannot see User A documents', () async {
      // User A uploads 2 documents
      final bytes1 = Uint8List.fromList(utf8.encode('User A Doc 1'));
      final bytes2 = Uint8List.fromList(utf8.encode('User A Doc 2'));

      await controller.uploadDocument(
        fileBytes: bytes1,
        fileName: 'UserA_Doc1.pdf',
        category: 'Identity',
      );
      await controller.uploadDocument(
        fileBytes: bytes2,
        fileName: 'UserA_Doc2.pdf',
        category: 'Financial',
      );

      expect(controller.state.documents.length, equals(2));

      // User B logs in with a different UID
      final controllerUserB = DocumentsController(
        docRepo: documentRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: 'uid-user-b-456',
      );
      await controllerUserB.loadDocuments();

      // User B must see 0 documents
      expect(controllerUserB.state.documents, isEmpty);
      expect(controllerUserB.state.rawDocuments, isEmpty);

      // User A logs back in
      final controllerUserAReturn = DocumentsController(
        docRepo: documentRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: 'uid-test-1',
      );
      await controllerUserAReturn.loadDocuments();

      // User A still sees their 2 documents
      expect(controllerUserAReturn.state.documents.length, equals(2));
    });
  });
}
