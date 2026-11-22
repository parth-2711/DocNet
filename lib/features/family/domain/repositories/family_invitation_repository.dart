import '../entities/family_invitation.dart';

/// Repository contract for managing family invitations.
abstract class FamilyInvitationRepository {
  /// Saves or updates an invitation.
  Future<void> saveInvitation(FamilyInvitation invitation);

  /// Retrieves an invitation by ID.
  Future<FamilyInvitation?> getInvitation(String invitationId);

  /// Retrieves incoming pending invitations for a user (by UID or email).
  Future<List<FamilyInvitation>> getIncomingInvitations({
    required String recipientUid,
    required String recipientEmail,
  });

  /// Retrieves all outgoing invitations sent from a family space.
  Future<List<FamilyInvitation>> getOutgoingInvitations(String familyId);

  /// Updates the status of an invitation (accepted, declined, canceled).
  Future<void> updateInvitationStatus({
    required String invitationId,
    required InvitationStatus status,
  });

  /// Deletes an invitation.
  Future<void> deleteInvitation(String invitationId);
}
