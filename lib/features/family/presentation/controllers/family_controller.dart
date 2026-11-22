import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../activity/domain/entities/activity_event.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../activity/presentation/controllers/activity_controller.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/domain/repositories/user_profile_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../../documents/presentation/controllers/documents_controller.dart';
import '../../data/repositories/in_memory_family_invitation_repository.dart';
import '../../data/repositories/persistent_family_invitation_repository.dart';
import '../../data/repositories/persistent_family_repository.dart';
import '../../domain/entities/family_invitation.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/entities/family_space.dart';
import '../../domain/repositories/family_invitation_repository.dart';
import '../../domain/repositories/family_repository.dart';
import '../../domain/usecases/create_family_usecase.dart';
import '../../domain/usecases/share_document_usecase.dart';

class FamilyState {
  final FamilySpace? family;
  final List<FamilyMember> members;
  final List<FamilyInvitation> incomingInvitations;
  final List<FamilyInvitation> outgoingInvitations;
  final bool isLoading;
  final String? errorMessage;

  const FamilyState({
    this.family,
    this.members = const [],
    this.incomingInvitations = const [],
    this.outgoingInvitations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  FamilyState copyWith({
    FamilySpace? family,
    List<FamilyMember>? members,
    List<FamilyInvitation>? incomingInvitations,
    List<FamilyInvitation>? outgoingInvitations,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FamilyState(
      family: family ?? this.family,
      members: members ?? this.members,
      incomingInvitations: incomingInvitations ?? this.incomingInvitations,
      outgoingInvitations: outgoingInvitations ?? this.outgoingInvitations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return PersistentFamilyRepository(storageService);
});

final familyInvitationRepositoryProvider =
    Provider<FamilyInvitationRepository>((ref) {
      final storageService = ref.watch(localVaultStorageServiceProvider);
      return PersistentFamilyInvitationRepository(storageService);
    });

final createFamilyUseCaseProvider = Provider<CreateFamilyUseCase>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return CreateFamilyUseCase(familyRepository: repo);
});

final shareDocumentUseCaseProvider = Provider<ShareDocumentUseCase>((ref) {
  final docRepo = ref.watch(documentRepositoryProvider);
  final familyRepo = ref.watch(familyRepositoryProvider);
  final activityRepo = ref.watch(activityRepositoryProvider);

  return ShareDocumentUseCase(
    documentRepository: docRepo,
    familyRepository: familyRepo,
    activityRepository: activityRepo,
  );
});

final familyControllerProvider =
    StateNotifierProvider<FamilyController, FamilyState>((ref) {
      final familyRepo = ref.watch(familyRepositoryProvider);
      final invitationRepo = ref.watch(familyInvitationRepositoryProvider);
      final userProfileRepo = ref.watch(userProfileRepositoryProvider);
      final createFamilyUseCase = ref.watch(createFamilyUseCaseProvider);
      final activityRepo = ref.watch(activityRepositoryProvider);
      final authState = ref.watch(authControllerProvider);
      final userProfile = authState.userProfile;

      return FamilyController(
        familyRepo: familyRepo,
        invitationRepo: invitationRepo,
        userProfileRepo: userProfileRepo,
        createFamilyUseCase: createFamilyUseCase,
        activityRepo: activityRepo,
        currentUserUid: userProfile?.uid ?? 'guest-uid',
        currentDisplayName: userProfile?.effectiveDisplayName ?? 'User',
        currentUserEmail: userProfile?.email ?? '',
      );
    });

class FamilyController extends StateNotifier<FamilyState> {
  final FamilyRepository familyRepo;
  final FamilyInvitationRepository invitationRepo;
  final UserProfileRepository? userProfileRepo;
  final CreateFamilyUseCase createFamilyUseCase;
  final ActivityRepository? activityRepo;
  final String currentUserUid;
  final String currentDisplayName;
  final String currentUserEmail;

  FamilyController({
    required this.familyRepo,
    FamilyInvitationRepository? invitationRepo,
    this.userProfileRepo,
    required this.createFamilyUseCase,
    this.activityRepo,
    required this.currentUserUid,
    required this.currentDisplayName,
    required this.currentUserEmail,
  }) : invitationRepo =
           invitationRepo ?? InMemoryFamilyInvitationRepository(),
       super(const FamilyState()) {
    loadFamily();
  }

  Future<void> loadFamily() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final family = await familyRepo.getUserFamily(currentUserUid);
      var members = <FamilyMember>[];

      if (family != null) {
        final rawMembers = await familyRepo.getMembers(family.familyId);
        final membersList = List<FamilyMember>.from(rawMembers);

        // Ensure the family space owner is always included in the members list
        if (!membersList.any((m) => m.uid == family.ownerUid)) {
          final ownerMember = FamilyMember(
            uid: family.ownerUid,
            familyId: family.familyId,
            displayName: (family.ownerUid == currentUserUid &&
                    currentDisplayName.isNotEmpty &&
                    currentDisplayName != 'User')
                ? currentDisplayName
                : 'Family Owner',
            email: (family.ownerUid == currentUserUid) ? currentUserEmail : '',
            role: FamilyRole.owner,
            joinedAt: family.createdAt,
          );
          await familyRepo.addMember(ownerMember);
          membersList.insert(0, ownerMember);
        }

        for (final m in membersList) {
          if (m.uid == currentUserUid) {
            final isDummyEmail =
                m.email.isEmpty ||
                m.email == 'user@familyvault.app' ||
                m.email == 'google.user@familyvault.app' ||
                m.email.endsWith('@familyvault.app') ||
                (currentUserEmail.isNotEmpty && m.email != currentUserEmail);
            final isDummyName =
                m.displayName.isEmpty ||
                m.displayName == 'Vault User' ||
                m.displayName == 'Google User' ||
                m.displayName == 'Google Account User' ||
                (currentDisplayName.isNotEmpty &&
                    currentDisplayName != 'User' &&
                    m.displayName != currentDisplayName);

            if ((isDummyEmail && currentUserEmail.isNotEmpty) ||
                (isDummyName &&
                    currentDisplayName.isNotEmpty &&
                    currentDisplayName != 'User')) {
              final healedMember = FamilyMember(
                uid: m.uid,
                familyId: m.familyId,
                displayName:
                    (currentDisplayName.isNotEmpty &&
                        currentDisplayName != 'User')
                    ? currentDisplayName
                    : m.displayName,
                email: currentUserEmail.isNotEmpty ? currentUserEmail : m.email,
                role: m.role,
                joinedAt: m.joinedAt,
                invitedBy: m.invitedBy,
              );
              await familyRepo.addMember(healedMember);
              members.add(healedMember);
              continue;
            }
          }
          members.add(m);
        }
      }

      // Load incoming invitations for current user
      final incoming = await invitationRepo.getIncomingInvitations(
        recipientUid: currentUserUid,
        recipientEmail: currentUserEmail,
      );

      // Load outgoing invitations if user is part of a family
      var outgoing = <FamilyInvitation>[];
      if (family != null) {
        outgoing = await invitationRepo.getOutgoingInvitations(family.familyId);
      }

      state = state.copyWith(
        family: family,
        members: members,
        incomingInvitations: incoming,
        outgoingInvitations: outgoing,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Looks up whether an account exists with the provided email, or synthesizes
  /// an invite profile if valid email format (supporting cloud/cross-device accounts).
  Future<UserProfile?> lookupUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@') || !normalized.contains('.')) {
      return null;
    }

    // 1. Check local profile repository
    if (userProfileRepo != null) {
      final local = await userProfileRepo!.getProfileByEmail(normalized);
      if (local != null) return local;
    }

    // 2. For any valid email address, synthesize a profile so cross-device/cloud users can be invited
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (emailRegex.hasMatch(normalized)) {
      final derivedName = AuthController.deriveDisplayName(normalized);
      return UserProfile(
        uid: 'user-${normalized.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
        email: normalized,
        displayName: derivedName,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    }

    return null;
  }

  Future<void> createFamily(String familyName) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final family = await createFamilyUseCase.execute(
        familyName: familyName,
        ownerUid: currentUserUid,
        ownerDisplayName: currentDisplayName,
        ownerEmail: currentUserEmail,
      );
      if (activityRepo != null) {
        await activityRepo!.logEvent(
          ActivityEvent(
            activityId: const Uuid().v4(),
            familyId: family.familyId,
            eventType: ActivityEventType.familyCreated,
            actorUid: currentUserUid,
            summary: 'Created family space "$familyName"',
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }
      state = state.copyWith(family: family, isLoading: false);
      await loadFamily();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Sends a pending invitation to an account verified by email.
  Future<void> sendInvitation({
    required String recipientEmail,
    FamilyRole role = FamilyRole.member,
  }) async {
    if (state.family == null) {
      throw const FormatException('You must have a family space to invite members.');
    }

    final normalizedEmail = recipientEmail.trim().toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (normalizedEmail.isEmpty || !emailRegex.hasMatch(normalizedEmail)) {
      throw const FormatException('Please enter a valid email address.');
    }

    if (normalizedEmail == currentUserEmail.trim().toLowerCase()) {
      throw const FormatException('You cannot invite your own account.');
    }

    // Check if user is already a member
    if (state.members.any(
      (m) => m.email.trim().toLowerCase() == normalizedEmail,
    )) {
      throw const FormatException('This user is already a member of this family space.');
    }

    // Check if an invitation is already pending
    if (state.outgoingInvitations.any(
      (inv) =>
          inv.recipientEmail.trim().toLowerCase() == normalizedEmail &&
          inv.status == InvitationStatus.pending,
    )) {
      throw const FormatException('An invitation is already pending for this user.');
    }

    // Verify or synthesize account profile
    UserProfile? profile;
    if (userProfileRepo != null) {
      profile = await userProfileRepo!.getProfileByEmail(normalizedEmail);
    }

    final effectiveDisplayName = profile?.effectiveDisplayName ??
        AuthController.deriveDisplayName(normalizedEmail);
    final targetUid = profile?.uid;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      const uuid = Uuid();
      final invitation = FamilyInvitation(
        invitationId: uuid.v4(),
        familyId: state.family!.familyId,
        familyName: state.family!.name,
        inviterUid: currentUserUid,
        inviterDisplayName: currentDisplayName,
        inviterEmail: currentUserEmail,
        recipientEmail: normalizedEmail,
        recipientUid: targetUid,
        recipientDisplayName: effectiveDisplayName,
        role: role,
        status: InvitationStatus.pending,
        createdAt: DateTime.now().toUtc(),
      );

      await invitationRepo.saveInvitation(invitation);

      // Cache synthesized profile if not in userProfileRepo
      if (profile == null && userProfileRepo != null) {
        final newProfile = UserProfile(
          uid: targetUid ?? 'user-${uuid.v4().substring(0, 8)}',
          email: normalizedEmail,
          displayName: effectiveDisplayName,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        try {
          await userProfileRepo!.saveProfile(newProfile);
        } catch (_) {}
      }

      if (activityRepo != null) {
        await activityRepo!.logEvent(
          ActivityEvent(
            activityId: uuid.v4(),
            familyId: state.family!.familyId,
            eventType: ActivityEventType.familyInvitationSent,
            actorUid: currentUserUid,
            targetMemberUid: targetUid,
            summary: 'Sent family invitation to $effectiveDisplayName ($normalizedEmail)',
            metadata: {'role': role.name, 'email': normalizedEmail},
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }

      await loadFamily();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Accepts an incoming family invitation and adds the user as an active member.
  Future<void> acceptInvitation(String invitationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final invitation = await invitationRepo.getInvitation(invitationId);
      if (invitation == null) {
        throw const FormatException('Invitation not found.');
      }

      final newMember = FamilyMember(
        uid: currentUserUid,
        familyId: invitation.familyId,
        displayName: currentDisplayName,
        email: currentUserEmail,
        role: invitation.role,
        joinedAt: DateTime.now().toUtc(),
        invitedBy: invitation.inviterUid,
        status: 'active',
      );

      // Ensure target family space exists locally
      var targetFamily = await familyRepo.getFamily(invitation.familyId);
      if (targetFamily == null) {
        targetFamily = FamilySpace(
          familyId: invitation.familyId,
          name: invitation.familyName,
          ownerUid: invitation.inviterUid,
          createdAt: invitation.createdAt,
          updatedAt: DateTime.now().toUtc(),
          memberCount: 2,
        );
        await familyRepo.saveFamily(targetFamily);
      }

      // If user had a solo placeholder family with 1 member, clear it
      if (state.family != null &&
          state.family!.familyId != invitation.familyId &&
          state.members.length <= 1) {
        try {
          await familyRepo.removeFamily(state.family!.familyId);
        } catch (_) {}
      }

      await familyRepo.addMember(newMember);
      await invitationRepo.updateInvitationStatus(
        invitationId: invitationId,
        status: InvitationStatus.accepted,
      );

      if (activityRepo != null) {
        await activityRepo!.logEvent(
          ActivityEvent(
            activityId: const Uuid().v4(),
            familyId: invitation.familyId,
            eventType: ActivityEventType.familyMemberJoined,
            actorUid: currentUserUid,
            summary: 'Joined family space "${invitation.familyName}" as ${invitation.role.name}',
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }

      await loadFamily();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Declines an incoming family invitation.
  Future<void> declineInvitation(String invitationId) async {
    try {
      await invitationRepo.updateInvitationStatus(
        invitationId: invitationId,
        status: InvitationStatus.declined,
      );
      await loadFamily();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// Cancels an outgoing pending invitation.
  Future<void> cancelInvitation(String invitationId) async {
    try {
      await invitationRepo.updateInvitationStatus(
        invitationId: invitationId,
        status: InvitationStatus.canceled,
      );
      await loadFamily();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// Allows the current user (if non-owner) to voluntarily leave their current family space.
  Future<void> leaveFamily() async {
    if (state.family == null) return;
    if (state.family!.ownerUid == currentUserUid) {
      throw const FormatException(
        'The owner cannot leave the family group. Delete the space or transfer ownership instead.',
      );
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await familyRepo.removeMember(
        familyId: state.family!.familyId,
        uid: currentUserUid,
      );

      if (activityRepo != null) {
        await activityRepo!.logEvent(
          ActivityEvent(
            activityId: const Uuid().v4(),
            familyId: state.family!.familyId,
            eventType: ActivityEventType.familyMemberRemoved,
            actorUid: currentUserUid,
            targetMemberUid: currentUserUid,
            summary: '$currentDisplayName left the family space "${state.family!.name}"',
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }

      state = const FamilyState();
      await loadFamily();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Legacy helper retained for direct member additions in tests.
  Future<void> inviteMember({
    required String email,
    required String displayName,
    FamilyRole role = FamilyRole.member,
  }) async {
    if (state.family == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      const uuid = Uuid();
      final newMember = FamilyMember(
        uid: uuid.v4(),
        familyId: state.family!.familyId,
        displayName: displayName,
        email: email,
        role: role,
        joinedAt: DateTime.now().toUtc(),
        invitedBy: currentUserUid,
      );

      await familyRepo.addMember(newMember);
      await loadFamily();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> removeMember(String memberUid) async {
    if (state.family == null) return;
    try {
      await familyRepo.removeMember(
        familyId: state.family!.familyId,
        uid: memberUid,
      );
      await loadFamily();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
