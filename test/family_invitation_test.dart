import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/auth/data/repositories/mock_user_profile_repository.dart';
import 'package:docnet/features/auth/domain/entities/user_profile.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_storage_repository.dart';
import 'package:docnet/features/documents/domain/services/document_search_engine.dart';
import 'package:docnet/features/documents/domain/usecases/download_and_decrypt_usecase.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/documents/presentation/controllers/documents_controller.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_invitation_repository.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_repository.dart';
import 'package:docnet/features/family/domain/entities/family_invitation.dart';
import 'package:docnet/features/family/domain/entities/family_member.dart';
import 'package:docnet/features/family/domain/usecases/create_family_usecase.dart';
import 'package:docnet/features/family/domain/usecases/revoke_document_access_usecase.dart';
import 'package:docnet/features/family/domain/usecases/share_document_usecase.dart';
import 'package:docnet/features/family/presentation/controllers/family_controller.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'upload_document_usecase_test.dart';

void main() {
  late InMemoryFamilyRepository familyRepo;
  late InMemoryFamilyInvitationRepository invitationRepo;
  late MockUserProfileRepository userProfileRepo;
  late CreateFamilyUseCase createFamilyUseCase;
  late FamilyController inviterController;

  final userOneProfile = UserProfile(
    uid: 'uid-user-1',
    email: 'alice@example.com',
    displayName: 'Alice Inviter',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final userTwoProfile = UserProfile(
    uid: 'uid-user-2',
    email: 'bob@example.com',
    displayName: 'Bob Recipient',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  setUp(() async {
    familyRepo = InMemoryFamilyRepository();
    invitationRepo = InMemoryFamilyInvitationRepository();
    userProfileRepo = MockUserProfileRepository();

    await userProfileRepo.saveProfile(userOneProfile);
    await userProfileRepo.saveProfile(userTwoProfile);

    createFamilyUseCase = CreateFamilyUseCase(familyRepository: familyRepo);

    inviterController = FamilyController(
      familyRepo: familyRepo,
      invitationRepo: invitationRepo,
      userProfileRepo: userProfileRepo,
      createFamilyUseCase: createFamilyUseCase,
      currentUserUid: 'uid-user-1',
      currentDisplayName: 'Alice Inviter',
      currentUserEmail: 'alice@example.com',
    );
  });

  group('Family Invitation & Email Lookup Tests', () {
    test('Email lookup fetches existing user display name and UID', () async {
      final found = await inviterController.lookupUserByEmail('bob@example.com');
      expect(found, isNotNull);
      expect(found!.uid, equals('uid-user-2'));
      expect(found.effectiveDisplayName, equals('Bob Recipient'));

      final invalid = await inviterController.lookupUserByEmail('not-an-email');
      expect(invalid, isNull);

      final crossDeviceUser = await inviterController.lookupUserByEmail('hirabengodhani2233@gmail.com');
      expect(crossDeviceUser, isNotNull);
      expect(crossDeviceUser!.email, equals('hirabengodhani2233@gmail.com'));
      expect(crossDeviceUser.effectiveDisplayName, equals('Hirabengodhani2233'));
    });

    test('Sending invitation to self throws FormatException', () async {
      await inviterController.createFamily('Alice Family');

      expect(
        () => inviterController.sendInvitation(
          recipientEmail: 'alice@example.com',
          role: FamilyRole.member,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Sending invitation to invalid email throws FormatException', () async {
      await inviterController.createFamily('Alice Family');

      expect(
        () => inviterController.sendInvitation(
          recipientEmail: 'invalid-email',
          role: FamilyRole.member,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Sending invitation to cross-device user creates pending invitation', () async {
      await inviterController.createFamily('Alice Family');

      await inviterController.sendInvitation(
        recipientEmail: 'hirabengodhani2233@gmail.com',
        role: FamilyRole.member,
      );

      expect(inviterController.state.outgoingInvitations.length, equals(1));
      final invite = inviterController.state.outgoingInvitations.first;
      expect(invite.recipientEmail, equals('hirabengodhani2233@gmail.com'));
      expect(invite.recipientDisplayName, equals('Hirabengodhani2233'));
      expect(invite.status, equals(InvitationStatus.pending));
    });

    test('Sending valid invitation creates pending invitation record', () async {
      await inviterController.createFamily('Alice Family');

      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      expect(inviterController.state.outgoingInvitations.length, equals(1));
      final invite = inviterController.state.outgoingInvitations.first;
      expect(invite.recipientEmail, equals('bob@example.com'));
      expect(invite.recipientDisplayName, equals('Bob Recipient'));
      expect(invite.recipientUid, equals('uid-user-2'));
      expect(invite.status, equals(InvitationStatus.pending));
    });

    test('Recipient sees incoming invitation and can accept to join family', () async {
      await inviterController.createFamily('Alice Family');
      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      // Initialize recipient controller for Bob
      final recipientController = FamilyController(
        familyRepo: familyRepo,
        invitationRepo: invitationRepo,
        userProfileRepo: userProfileRepo,
        createFamilyUseCase: createFamilyUseCase,
        currentUserUid: 'uid-user-2',
        currentDisplayName: 'Bob Recipient',
        currentUserEmail: 'bob@example.com',
      );

      await recipientController.loadFamily();

      // Bob sees incoming invitation
      expect(recipientController.state.incomingInvitations.length, equals(1));
      final incomingInvite = recipientController.state.incomingInvitations.first;
      expect(incomingInvite.familyName, equals('Alice Family'));
      expect(incomingInvite.inviterDisplayName, equals('Alice Inviter'));

      // Bob accepts the invitation
      await recipientController.acceptInvitation(incomingInvite.invitationId);

      // Bob is now an active member of Alice's family
      expect(recipientController.state.family, isNotNull);
      expect(recipientController.state.family!.name, equals('Alice Family'));
      expect(recipientController.state.members.length, equals(2));
      expect(
        recipientController.state.members.any(
          (m) => m.uid == 'uid-user-2' && m.displayName == 'Bob Recipient',
        ),
        isTrue,
      );
      expect(recipientController.state.incomingInvitations, isEmpty);
    });

    test('Recipient can decline invitation cleanly', () async {
      await inviterController.createFamily('Alice Family');
      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      final recipientController = FamilyController(
        familyRepo: familyRepo,
        invitationRepo: invitationRepo,
        userProfileRepo: userProfileRepo,
        createFamilyUseCase: createFamilyUseCase,
        currentUserUid: 'uid-user-2',
        currentDisplayName: 'Bob Recipient',
        currentUserEmail: 'bob@example.com',
      );

      await recipientController.loadFamily();
      expect(recipientController.state.incomingInvitations.length, equals(1));

      final incomingInvite = recipientController.state.incomingInvitations.first;
      await recipientController.declineInvitation(incomingInvite.invitationId);

      // Invitation is declined and removed from pending
      expect(recipientController.state.incomingInvitations, isEmpty);
      expect(recipientController.state.family, isNull);
    });

    test('Inviter can cancel pending outgoing invitation', () async {
      await inviterController.createFamily('Alice Family');
      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      expect(inviterController.state.outgoingInvitations.length, equals(1));
      final invite = inviterController.state.outgoingInvitations.first;

      await inviterController.cancelInvitation(invite.invitationId);
      expect(inviterController.state.outgoingInvitations, isEmpty);
    });

    test('Explicit per-document sharing exposes only shared document while unshared documents stay isolated', () async {
      final docRepo = InMemoryDocumentRepository();
      final storageRepo = InMemoryStorageRepository();
      final syncQueue = MockSyncQueueRepository();
      final crypto = CryptographyCryptoService();
      final uploadUseCase = UploadDocumentUseCase(
        cryptoService: crypto,
        documentRepository: docRepo,
        syncQueueRepository: syncQueue,
        storageRepository: storageRepo,
      );
      final shareUseCase = ShareDocumentUseCase(
        documentRepository: docRepo,
        familyRepository: familyRepo,
        storageRepository: storageRepo,
      );

      // Alice uploads two documents (Doc A1 and Doc A2)
      final aliceDocController = DocumentsController(
        docRepo: docRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: 'uid-user-1',
        currentUserEmail: 'alice@example.com',
      );

      final docA1 = await aliceDocController.uploadDocument(
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'Document_A1_Notes.pdf',
        category: 'Education',
      );

      await aliceDocController.uploadDocument(
        fileBytes: Uint8List.fromList([4, 5, 6]),
        fileName: 'Document_A2_Private.pdf',
        category: 'Shared', // Even Shared category stays private until explicitly shared!
      );

      expect(aliceDocController.state.documents.length, equals(2));

      // Alice shares ONLY Document A1 with Bob
      await shareUseCase.execute(
        documentId: docA1.document.documentId,
        granterUid: 'uid-user-1',
        recipientUid: 'uid-user-2',
        recipientEmail: 'bob@example.com',
        recipientDisplayName: 'Bob Recipient',
        canView: true,
        canDownload: false,
      );

      // Bob's documents controller
      final bobDocController = DocumentsController(
        docRepo: docRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: 'uid-user-2',
        currentUserEmail: 'bob@example.com',
      );

      await bobDocController.loadDocuments();

      // Bob sees ONLY Document A1, NOT Document A2
      expect(bobDocController.state.documents.length, equals(1));
      expect(
        bobDocController.state.documents.first.decryptedName,
        equals('Document_A1_Notes.pdf'),
      );
      expect(
        bobDocController.state.documents.any(
          (d) => d.decryptedName == 'Document_A2_Private.pdf',
        ),
        isFalse,
      );

      // Shared with Me scope shows Document A1
      bobDocController.setOwnershipScope(DocumentOwnershipScope.sharedWithMe);
      expect(bobDocController.state.documents.length, equals(1));
      bobDocController.setOwnershipScope(DocumentOwnershipScope.myVault);
      expect(bobDocController.state.documents, isEmpty);
    });

    test('Per-user permission enforcement, expiry, and revocation work end-to-end', () async {
      final docRepo = InMemoryDocumentRepository();
      final storageRepo = InMemoryStorageRepository();
      final syncQueue = MockSyncQueueRepository();
      final crypto = CryptographyCryptoService();
      final uploadUseCase = UploadDocumentUseCase(
        cryptoService: crypto,
        documentRepository: docRepo,
        syncQueueRepository: syncQueue,
        storageRepository: storageRepo,
      );
      final shareUseCase = ShareDocumentUseCase(
        documentRepository: docRepo,
        familyRepository: familyRepo,
        storageRepository: storageRepo,
      );
      final revokeUseCase = RevokeDocumentAccessUseCase(
        documentRepository: docRepo,
        familyRepository: familyRepo,
      );
      final downloadUseCase = DownloadAndDecryptUseCase(
        cryptoService: crypto,
        documentRepository: docRepo,
        storageRepository: storageRepo,
        familyRepository: familyRepo,
      );

      final docA1 = await uploadUseCase.execute(
        fileBytes: Uint8List.fromList([10, 20, 30]),
        fileName: 'Contract_A1.pdf',
        category: 'Work',
        ownerUid: 'uid-user-1',
      );

      // 1. Share directly by email with view-only permission
      await shareUseCase.execute(
        documentId: docA1.document.documentId,
        granterUid: 'uid-user-1',
        recipientUid: 'email-charlie@example.com',
        recipientEmail: 'charlie@example.com',
        recipientDisplayName: 'Charlie',
        canView: true,
        canDownload: false,
      );

      final decrypted = await downloadUseCase.execute(
        documentId: docA1.document.documentId,
        recipientUid: 'uid-charlie-real',
        recipientEmail: 'charlie@example.com',
      );
      expect(decrypted.permission, isNotNull);
      expect(decrypted.permission!.canDownload, isFalse);

      // 2. Revoke Charlie's access -> decryption & permission check immediately fail
      await revokeUseCase.execute(
        documentId: docA1.document.documentId,
        revokerUid: 'uid-user-1',
        granteeId: 'email-charlie@example.com',
        granteeEmail: 'charlie@example.com',
      );

      expect(
        () => downloadUseCase.execute(
          documentId: docA1.document.documentId,
          recipientUid: 'uid-charlie-real',
          recipientEmail: 'charlie@example.com',
        ),
        throwsA(isA<StateError>()),
      );

      // 3. Expired permission denies access
      await shareUseCase.execute(
        documentId: docA1.document.documentId,
        granterUid: 'uid-user-1',
        recipientUid: 'uid-user-2',
        recipientEmail: 'bob@example.com',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );

      expect(
        () => downloadUseCase.execute(
          documentId: docA1.document.documentId,
          recipientUid: 'uid-user-2',
          recipientEmail: 'bob@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Access Expired'),
          ),
        ),
      );
    });

    test('User can create and switch between multiple Shared Spaces', () async {
      await inviterController.createFamily('CS Study Group');
      await inviterController.createFamily('Project Team');

      expect(inviterController.state.spaces.length, equals(2));
      expect(inviterController.state.family!.name, equals('Project Team'));

      final studySpace = inviterController.state.spaces.firstWhere(
        (s) => s.name == 'CS Study Group',
      );
      await inviterController.switchSpace(studySpace.familyId);
      expect(inviterController.state.family!.name, equals('CS Study Group'));
    });

    test('When recipient accepts invitation, inviter outgoing invitations no longer show it as pending', () async {
      await inviterController.createFamily('Alice Family');
      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      expect(inviterController.state.outgoingInvitations.length, equals(1));

      // Bob accepts
      final incoming = await invitationRepo.getIncomingInvitations(
        recipientUid: 'uid-user-2',
        recipientEmail: 'bob@example.com',
      );
      await invitationRepo.updateInvitationStatus(
        invitationId: incoming.first.invitationId,
        status: InvitationStatus.accepted,
      );

      // Inviter reloads family
      await inviterController.loadFamily();
      final pendingInvites = inviterController.state.outgoingInvitations
          .where((inv) => inv.status == InvitationStatus.pending)
          .toList();
      expect(pendingInvites, isEmpty);
    });

    test('When recipient declines invitation, inviter outgoing invitations show it as declined', () async {
      await inviterController.createFamily('Alice Family');
      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      final incoming = await invitationRepo.getIncomingInvitations(
        recipientUid: 'uid-user-2',
        recipientEmail: 'bob@example.com',
      );
      await invitationRepo.updateInvitationStatus(
        invitationId: incoming.first.invitationId,
        status: InvitationStatus.declined,
      );

      await inviterController.loadFamily();
      final declinedInvites = inviterController.state.outgoingInvitations
          .where((inv) => inv.status == InvitationStatus.declined)
          .toList();
      expect(declinedInvites.length, equals(1));
      expect(declinedInvites.first.recipientEmail, equals('bob@example.com'));
    });

    test('Member can leave family space and owner removing member clears them', () async {
      await inviterController.createFamily('Alice Family');
      await inviterController.sendInvitation(
        recipientEmail: 'bob@example.com',
        role: FamilyRole.member,
      );

      final incoming = await invitationRepo.getIncomingInvitations(
        recipientUid: 'uid-user-2',
        recipientEmail: 'bob@example.com',
      );

      final recipientController = FamilyController(
        familyRepo: familyRepo,
        invitationRepo: invitationRepo,
        userProfileRepo: userProfileRepo,
        createFamilyUseCase: createFamilyUseCase,
        currentUserUid: 'uid-user-2',
        currentDisplayName: 'Bob Recipient',
        currentUserEmail: 'bob@example.com',
      );

      await recipientController.acceptInvitation(incoming.first.invitationId);
      expect(recipientController.state.family, isNotNull);
      expect(recipientController.state.members.length, equals(2));

      // Bob leaves family space voluntarily
      await recipientController.leaveFamily();
      expect(recipientController.state.family, isNull);
      expect(recipientController.state.members, isEmpty);

      // Alice now only has 1 member (herself)
      await inviterController.loadFamily();
      expect(inviterController.state.members.length, equals(1));
    });
  });
}
