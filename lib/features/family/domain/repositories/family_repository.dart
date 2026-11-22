import '../entities/document_permission.dart';
import '../entities/family_member.dart';
import '../entities/family_space.dart';

/// Repository contract for managing family spaces, members, and document permissions (DATABASE_SCHEMA.md).
abstract class FamilyRepository {
  /// Retrieves a family space by familyId.
  Future<FamilySpace?> getFamily(String familyId);

  /// Retrieves the active family space for a user.
  Future<FamilySpace?> getUserFamily(String uid);

  /// Saves or updates a family space.
  Future<void> saveFamily(FamilySpace family);

  /// Retrieves all members of a family space.
  Future<List<FamilyMember>> getMembers(String familyId);

  /// Adds a member to a family space.
  Future<void> addMember(FamilyMember member);

  /// Removes a member from a family space (FAM-008).
  Future<void> removeMember({required String familyId, required String uid});

  /// Saves a document-level permission.
  Future<void> savePermission(DocumentPermission permission);

  /// Retrieves all permissions granted on a document.
  Future<List<DocumentPermission>> getPermissions(String documentId);

  /// Retrieves permission for a specific user or family grantee.
  Future<DocumentPermission?> getPermission({
    required String documentId,
    required String granteeId,
  });
}
