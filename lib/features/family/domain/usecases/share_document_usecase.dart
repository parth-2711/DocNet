import 'package:uuid/uuid.dart';
import 'package:docnet/features/activity/domain/entities/activity_event.dart';
import 'package:docnet/features/activity/domain/repositories/activity_repository.dart';
import 'package:docnet/features/documents/domain/entities/key_envelope.dart';
import 'package:docnet/features/documents/domain/repositories/document_repository.dart';
import 'package:docnet/features/documents/domain/repositories/storage_repository.dart';
import '../entities/document_permission.dart';
import '../repositories/family_repository.dart';

/// Result returned after successfully creating a recipient key envelope and permission.
class ShareDocumentResult {
  final KeyEnvelope envelope;
  final DocumentPermission permission;

  const ShareDocumentResult({required this.envelope, required this.permission});
}

/// Use case implementing explicit per-user document sharing and key envelope generation
/// (ARCHITECTURE.md Section 6.3, PRD.md SHARE-001, SHARE-002, SHARE-003, Boundary C).
class ShareDocumentUseCase {
  final DocumentRepository documentRepository;
  final FamilyRepository familyRepository;
  final StorageRepository? storageRepository;
  final ActivityRepository? activityRepository;
  final Uuid uuid;

  ShareDocumentUseCase({
    required this.documentRepository,
    required this.familyRepository,
    this.storageRepository,
    this.activityRepository,
    this.uuid = const Uuid(),
  });

  /// Shares a document with an authorized recipient (by UID or email) using explicit
  /// least-privilege permissions and optional expiry.
  Future<ShareDocumentResult> execute({
    required String documentId,
    required String granterUid,
    required String recipientUid,
    String? recipientEmail,
    String? recipientDisplayName,
    bool canView = true,
    bool canDownload = false, // Least privilege default (SHARE-003)
    bool canEdit = false,
    bool canShare = false,
    DateTime? expiresAt,
  }) async {
    final normalizedEmail = recipientEmail?.trim().toLowerCase();

    // 1. Verify document existence and authorization
    final document = await documentRepository.getDocumentById(documentId);
    if (document == null) {
      throw StateError('Document not found: $documentId');
    }

    if (document.ownerUid != granterUid) {
      final existingPerm = await familyRepository.getPermission(
        documentId: documentId,
        granteeId: granterUid,
      );
      if (existingPerm == null ||
          !existingPerm.canShare ||
          existingPerm.isExpired) {
        throw StateError(
          'Access Denied: You do not have permission to share this document.',
        );
      }
    }

    if (recipientUid == document.ownerUid) {
      throw ArgumentError('Cannot share a document with its own owner.');
    }

    // 2. Fetch granter's key envelope to unwrap DEK
    final ownerEnvelope = await documentRepository.getKeyEnvelope(
      documentId: documentId,
      recipientId: granterUid,
    );
    if (ownerEnvelope == null) {
      throw StateError(
        'Cannot share: Granter does not possess a valid key envelope for document $documentId',
      );
    }

    final now = DateTime.now().toUtc();

    // 3. Ensure document metadata, versions & encrypted payload are synced for recipient access
    await documentRepository.saveDocument(document);
    final versions = await documentRepository.getVersions(documentId);
    for (final v in versions) {
      await documentRepository.saveVersion(v);
      if (storageRepository != null && v.versionId == document.currentVersionId) {
        await storageRepository!.syncObjectToCloud(v.storageObjectRef);
      }
    }

    // 4. Create or update Key Envelope wrapped for recipient (Boundary C & KEY-001)
    final existingEnv = await documentRepository.getKeyEnvelope(
      documentId: documentId,
      recipientId: recipientUid,
      recipientEmail: normalizedEmail,
    );

    final recipientEnvelope = KeyEnvelope(
      envelopeId: existingEnv?.envelopeId ?? uuid.v4(),
      documentId: documentId,
      recipientType: 'user',
      recipientId: recipientUid,
      recipientEmail: normalizedEmail ?? existingEnv?.recipientEmail,
      wrappedDek: ownerEnvelope.wrappedDek,
      wrappingAlgorithm: ownerEnvelope.wrappingAlgorithm,
      keyEpoch: document.keyEpoch,
      createdAt: now,
    );

    // 5. Create or update explicit permission record (SHARE-002, SHARE-003)
    final existingPerm = await familyRepository.getPermission(
      documentId: documentId,
      granteeId: recipientUid,
      granteeEmail: normalizedEmail,
    );

    final permission = DocumentPermission(
      permissionId: existingPerm?.permissionId ?? uuid.v4(),
      documentId: documentId,
      granteeType: 'user',
      granteeId: recipientUid,
      granteeEmail: normalizedEmail ?? existingPerm?.granteeEmail,
      granteeDisplayName:
          recipientDisplayName ?? existingPerm?.granteeDisplayName,
      canView: canView,
      canDownload: canDownload,
      canEdit: canEdit,
      canShare: canShare,
      grantedBy: granterUid,
      grantedAt: now,
      expiresAt: expiresAt,
    );

    // 6. Persist envelope and permission
    await documentRepository.saveKeyEnvelope(recipientEnvelope);
    await familyRepository.savePermission(permission);

    // 7. Record audit event (PRD.md 6.12, SHARE-009: record who shared without recording document contents)
    if (activityRepository != null) {
      await activityRepository!.logEvent(
        ActivityEvent(
          activityId: uuid.v4(),
          actorUid: granterUid,
          targetDocumentId: documentId,
          targetMemberUid: recipientUid,
          eventType: ActivityEventType.shareGranted,
          summary:
              'Document shared with ${canDownload ? "view & download" : "view-only"} permission',
          metadata: {
            'canView': canView,
            'canDownload': canDownload,
            'canEdit': canEdit,
            'canShare': canShare,
            'recipientEmail': ?normalizedEmail,
            if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
          },
          timestamp: now,
        ),
      );
    }

    return ShareDocumentResult(
      envelope: recipientEnvelope,
      permission: permission,
    );
  }
}
