import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_storage_repository.dart';
import 'package:docnet/features/documents/domain/usecases/download_and_decrypt_usecase.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_repository.dart';
import 'package:docnet/features/family/domain/entities/family_member.dart';
import 'package:docnet/features/family/domain/usecases/create_family_usecase.dart';
import 'package:docnet/features/family/domain/usecases/share_document_usecase.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'upload_document_usecase_test.dart';

void main() {
  late CryptographyCryptoService cryptoService;
  late InMemoryDocumentRepository documentRepo;
  late InMemoryStorageRepository storageRepo;
  late InMemoryFamilyRepository familyRepo;
  late MockSyncQueueRepository syncQueue;
  late UploadDocumentUseCase uploadUseCase;
  late DownloadAndDecryptUseCase downloadUseCase;
  late CreateFamilyUseCase createFamilyUseCase;
  late ShareDocumentUseCase shareUseCase;

  setUp(() {
    cryptoService = CryptographyCryptoService();
    documentRepo = InMemoryDocumentRepository();
    storageRepo = InMemoryStorageRepository();
    familyRepo = InMemoryFamilyRepository();
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

    createFamilyUseCase = CreateFamilyUseCase(familyRepository: familyRepo);
    shareUseCase = ShareDocumentUseCase(
      documentRepository: documentRepo,
      familyRepository: familyRepo,
    );
  });

  group('Family & Key Envelope Sharing Tests', () {
    test(
      'CreateFamilyUseCase creates family space and adds owner as first member (FAM-001, FAM-007)',
      () async {
        final family = await createFamilyUseCase.execute(
          familyName: 'Godhani Family',
          ownerUid: 'uid-parth',
          ownerDisplayName: 'Parth Godhani',
          ownerEmail: 'parth@example.com',
        );

        expect(family.name, equals('Godhani Family'));
        expect(family.ownerUid, equals('uid-parth'));
        expect(family.memberCount, equals(1));

        final members = await familyRepo.getMembers(family.familyId);
        expect(members.length, equals(1));
        expect(members.first.uid, equals('uid-parth'));
        expect(members.first.role, equals(FamilyRole.owner));
      },
    );

    test(
      'Shares document via recipient KeyEnvelope with least-privilege defaults (SHARE-001, SHARE-002, SHARE-003)',
      () async {
        // 1. Owner uploads a document
        const docContent = 'Confidential Property Deed document content';
        final fileBytes = Uint8List.fromList(utf8.encode(docContent));

        final uploadResult = await uploadUseCase.execute(
          fileBytes: fileBytes,
          fileName: 'Property_Deed.pdf',
          category: 'Property',
          ownerUid: 'uid-owner',
        );

        // 2. Add family member
        await familyRepo.addMember(
          FamilyMember(
            uid: 'uid-member-alice',
            familyId: 'family-1',
            displayName: 'Alice',
            email: 'alice@example.com',
            role: FamilyRole.member,
            joinedAt: DateTime.now().toUtc(),
          ),
        );

        // 3. Share document with Alice
        final shareResult = await shareUseCase.execute(
          documentId: uploadResult.document.documentId,
          granterUid: 'uid-owner',
          recipientUid: 'uid-member-alice',
        );

        // Verify recipient envelope created
        expect(shareResult.envelope.recipientId, equals('uid-member-alice'));
        expect(
          shareResult.envelope.documentId,
          equals(uploadResult.document.documentId),
        );
        expect(shareResult.envelope.wrappedDek, isNotEmpty);

        // Verify least privilege defaults (SHARE-003)
        expect(shareResult.permission.canView, isTrue);
        expect(shareResult.permission.canDownload, isFalse);
        expect(shareResult.permission.canEdit, isFalse);
        expect(shareResult.permission.canShare, isFalse);

        // 4. Recipient (Alice) can now decrypt the document
        final decryptedForAlice = await downloadUseCase.execute(
          documentId: uploadResult.document.documentId,
          recipientUid: 'uid-member-alice',
        );

        expect(
          utf8.decode(decryptedForAlice.plaintextBytes),
          equals(docContent),
        );
        expect(decryptedForAlice.fileName, equals('Property_Deed.pdf'));
      },
    );

    test(
      'Family member cannot access non-shared personal documents (Boundary C)',
      () async {
        // 1. Owner uploads private document
        final fileBytes = Uint8List.fromList(
          utf8.encode('Private Medical Scan'),
        );
        final uploadResult = await uploadUseCase.execute(
          fileBytes: fileBytes,
          fileName: 'Medical_Scan.png',
          category: 'Medical',
          ownerUid: 'uid-owner',
        );

        // 2. Family member exists but document was NOT shared
        await familyRepo.addMember(
          FamilyMember(
            uid: 'uid-member-bob',
            familyId: 'family-1',
            displayName: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.member,
            joinedAt: DateTime.now().toUtc(),
          ),
        );

        // 3. Bob attempts to decrypt without a key envelope
        expect(
          () async => await downloadUseCase.execute(
            documentId: uploadResult.document.documentId,
            recipientUid: 'uid-member-bob',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Access Denied: No cryptographic key envelope found'),
            ),
          ),
        );
      },
    );
  });
}
