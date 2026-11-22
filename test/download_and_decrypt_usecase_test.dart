import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_storage_repository.dart';
import 'package:docnet/features/documents/domain/usecases/download_and_decrypt_usecase.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'upload_document_usecase_test.dart';

void main() {
  late CryptographyCryptoService cryptoService;
  late InMemoryDocumentRepository documentRepo;
  late InMemoryStorageRepository storageRepo;
  late MockSyncQueueRepository syncQueue;
  late UploadDocumentUseCase uploadUseCase;
  late DownloadAndDecryptUseCase downloadUseCase;

  setUp(() {
    cryptoService = CryptographyCryptoService();
    documentRepo = InMemoryDocumentRepository();
    storageRepo = InMemoryStorageRepository();
    syncQueue = MockSyncQueueRepository();

    uploadUseCase = UploadDocumentUseCase(
      cryptoService: cryptoService,
      documentRepository: documentRepo,
      syncQueueRepository: syncQueue,
      storageRepository: storageRepo,
    );

    downloadUseCase = DownloadAndDecryptUseCase(
      cryptoService: cryptoService,
      documentRepository: documentRepo,
      storageRepository: storageRepo,
    );
  });

  group('DownloadAndDecryptUseCase Tests', () {
    test(
      'Downloads, authenticates, and decrypts document successfully',
      () async {
        const originalText =
            'Highly confidential financial document: Tax Return 2026';
        final fileBytes = Uint8List.fromList(utf8.encode(originalText));

        final uploadResult = await uploadUseCase.execute(
          fileBytes: fileBytes,
          fileName: 'Tax_Return.pdf',
          category: 'Financial',
          ownerUid: 'user-parth',
          description: 'FY 2025-26 assessment copy',
        );

        final decryptedResult = await downloadUseCase.execute(
          documentId: uploadResult.document.documentId,
          recipientUid: 'user-parth',
        );

        // Verify decrypted plaintext
        expect(
          utf8.decode(decryptedResult.plaintextBytes),
          equals(originalText),
        );

        // Verify decrypted metadata
        expect(decryptedResult.fileName, equals('Tax_Return.pdf'));
        expect(decryptedResult.category, equals('Financial'));
        expect(
          decryptedResult.description,
          equals('FY 2025-26 assessment copy'),
        );
        expect(decryptedResult.version.versionNumber, equals(1));
      },
    );

    test(
      'Throws FormatException if ciphertext in storage is corrupted (VER-008)',
      () async {
        final fileBytes = Uint8List.fromList(utf8.encode('Original content'));

        final uploadResult = await uploadUseCase.execute(
          fileBytes: fileBytes,
          fileName: 'Medical.png',
          category: 'Medical',
          ownerUid: 'user-parth',
        );

        // Corrupt 1 byte in storage
        final storedObject = await storageRepo.getObject(
          uploadResult.version.storageObjectRef,
        );
        expect(storedObject, isNotNull);
        final corrupted = Uint8List.fromList(storedObject!);
        corrupted[10] ^= 0xFF; // Flip bits
        await storageRepo.putObject(
          objectRef: uploadResult.version.storageObjectRef,
          data: corrupted,
        );

        // Attempt to download and decrypt corrupted object
        expect(
          () async => await downloadUseCase.execute(
            documentId: uploadResult.document.documentId,
            recipientUid: 'user-parth',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Cryptographic integrity failure'),
            ),
          ),
        );
      },
    );

    test(
      'Access denied if recipient has no key envelope (Boundary C)',
      () async {
        final fileBytes = Uint8List.fromList(
          utf8.encode('Private user record'),
        );

        final uploadResult = await uploadUseCase.execute(
          fileBytes: fileBytes,
          fileName: 'Private.pdf',
          category: 'Identity',
          ownerUid: 'user-parth',
        );

        // Recipient 'unauthorized-user' has no key envelope
        expect(
          () async => await downloadUseCase.execute(
            documentId: uploadResult.document.documentId,
            recipientUid: 'unauthorized-user',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Access Denied'),
            ),
          ),
        );
      },
    );
  });
}
