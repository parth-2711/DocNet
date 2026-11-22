import '../../domain/entities/family_invitation.dart';
import '../../domain/repositories/family_invitation_repository.dart';

/// In-memory implementation of FamilyInvitationRepository for unit tests and offline mock testing.
class InMemoryFamilyInvitationRepository implements FamilyInvitationRepository {
  final Map<String, FamilyInvitation> _invitations = {};

  @override
  Future<void> saveInvitation(FamilyInvitation invitation) async {
    _invitations[invitation.invitationId] = invitation;
  }

  @override
  Future<FamilyInvitation?> getInvitation(String invitationId) async {
    return _invitations[invitationId];
  }

  @override
  Future<List<FamilyInvitation>> getIncomingInvitations({
    required String recipientUid,
    required String recipientEmail,
  }) async {
    final normalizedEmail = recipientEmail.trim().toLowerCase();

    final results = _invitations.values.where((inv) {
      if (inv.status != InvitationStatus.pending) return false;
      final matchesUid =
          inv.recipientUid != null &&
          inv.recipientUid!.isNotEmpty &&
          inv.recipientUid == recipientUid;
      final matchesEmail =
          normalizedEmail.isNotEmpty &&
          inv.recipientEmail.trim().toLowerCase() == normalizedEmail;
      return matchesUid || matchesEmail;
    }).toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<List<FamilyInvitation>> getOutgoingInvitations(String familyId) async {
    final results = _invitations.values.where((inv) {
      return inv.familyId == familyId &&
          (inv.status == InvitationStatus.pending ||
           inv.status == InvitationStatus.declined);
    }).toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<void> updateInvitationStatus({
    required String invitationId,
    required InvitationStatus status,
  }) async {
    final existing = _invitations[invitationId];
    if (existing != null) {
      _invitations[invitationId] = existing.copyWith(
        status: status,
        respondedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<void> deleteInvitation(String invitationId) async {
    _invitations.remove(invitationId);
  }
}
