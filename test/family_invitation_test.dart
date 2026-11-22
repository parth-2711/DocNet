import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/auth/data/repositories/mock_user_profile_repository.dart';
import 'package:docnet/features/auth/domain/entities/user_profile.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/documents/presentation/controllers/documents_controller.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_invitation_repository.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_repository.dart';
import 'package:docnet/features/family/domain/entities/family_invitation.dart';
import 'package:docnet/features/family/domain/entities/family_member.dart';
import 'package:docnet/features/family/domain/usecases/create_family_usecase.dart';
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

    test('Accepted member can access family documents while personal documents stay isolated', () async {
      final docRepo = InMemoryDocumentRepository();
      final syncQueue = MockSyncQueueRepository();
      final uploadUseCase = UploadDocumentUseCase(
        cryptoService: CryptographyCryptoService(),
        documentRepository: docRepo,
        syncQueueRepository: syncQueue,
      );

      // Alice uploads a private personal document AND a shared family document
      final aliceDocController = DocumentsController(
        docRepo: docRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: 'uid-user-1',
      );

      await aliceDocController.uploadDocument(
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'Alice_Private_Passport.pdf',
        category: 'Identity',
      );

      await aliceDocController.uploadDocument(
        fileBytes: Uint8List.fromList([4, 5, 6]),
        fileName: 'Shared_Family_HouseDeed.pdf',
        category: 'Family',
      );

      expect(aliceDocController.state.documents.length, equals(2));

      // Bob's documents controller
      final bobDocController = DocumentsController(
        docRepo: docRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: 'uid-user-2',
      );

      await bobDocController.loadDocuments();

      // Bob sees the shared Family document, but NOT Alice's private passport!
      expect(bobDocController.state.documents.length, equals(1));
      expect(
        bobDocController.state.documents.first.decryptedName,
        equals('Shared_Family_HouseDeed.pdf'),
      );
      expect(
        bobDocController.state.documents.any(
          (d) => d.decryptedName == 'Alice_Private_Passport.pdf',
        ),
        isFalse,
      );
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
