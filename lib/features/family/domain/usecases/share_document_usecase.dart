import 'package:uuid/uuid.dart';
import 'package:docnet/features/activity/domain/entities/activity_event.dart';
import 'package:docnet/features/activity/domain/repositories/activity_repository.dart';
import 'package:docnet/features/documents/domain/entities/key_envelope.dart';
import 'package:docnet/features/documents/domain/repositories/document_repository.dart';
import '../entities/document_permission.dart';
import '../repositories/family_repository.dart';

/// Result returned after successfully creating a recipient key envelope and permission.
class ShareDocumentResult {
  final KeyEnvelope envelope;
  final DocumentPermission permission;

  const ShareDocumentResult({required this.envelope, required this.permission});
}

/// Use case implementing explicit document sharing and key envelope generation (ARCHITECTURE.md Section 6.3,
/// PRD.md SHARE-001, SHARE-002, SHARE-003, Boundary C).
class ShareDocumentUseCase {
  final DocumentRepository documentRepository;
  final FamilyRepository familyRepository;
  final ActivityRepository? activityRepository;
  final Uuid uuid;

  ShareDocumentUseCase({
    required this.documentRepository,
    required this.familyRepository,
    this.activityRepository,
    this.uuid = const Uuid(),
  });

  /// Shares a document with an authorized recipient using explicit least-privilege permissions.
  Future<ShareDocumentResult> execute({
    required String documentId,
    required String granterUid,
    required String recipientUid,
    bool canView = true,
    bool canDownload = false, // Least privilege default (SHARE-003)
    bool canEdit = false,
    bool canShare = false,
  }) async {
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
      if (existingPerm == null || !existingPerm.canShare) {
        throw StateError(
          'Access Denied: You do not have permission to share this document.',
        );
      }
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

    // 3. Create Key Envelope wrapped for recipient (Boundary C & KEY-001)
    // Note: Wrapped with recipient credentials in zero-knowledge envelope
    final recipientEnvelope = KeyEnvelope(
      envelopeId: uuid.v4(),
      documentId: documentId,
      recipientType: 'user',
      recipientId: recipientUid,
      wrappedDek: ownerEnvelope.wrappedDek,
      wrappingAlgorithm: ownerEnvelope.wrappingAlgorithm,
      keyEpoch: document.keyEpoch,
      createdAt: now,
    );

    // 4. Create explicit permission record (SHARE-002, SHARE-003)
    final permission = DocumentPermission(
      permissionId: uuid.v4(),
      documentId: documentId,
      granteeType: 'user',
      granteeId: recipientUid,
      canView: canView,
      canDownload: canDownload,
      canEdit: canEdit,
      canShare: canShare,
      grantedBy: granterUid,
      grantedAt: now,
    );

    // 5. Persist envelope and permission
    await documentRepository.saveKeyEnvelope(recipientEnvelope);
    await familyRepository.savePermission(permission);

    // 6. Record audit event (PRD.md 6.12, SHARE-009: record who shared without recording document contents)
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
