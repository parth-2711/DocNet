import 'package:uuid/uuid.dart';
import 'package:docnet/features/activity/domain/entities/activity_event.dart';
import 'package:docnet/features/activity/domain/repositories/activity_repository.dart';
import 'package:docnet/features/documents/domain/repositories/document_repository.dart';
import '../repositories/family_repository.dart';

/// Use case for immediately revoking a specific user's permission and cryptographic
/// key envelope on a shared document (PRD.md SHARE-006, SHARE-009).
class RevokeDocumentAccessUseCase {
  final DocumentRepository documentRepository;
  final FamilyRepository familyRepository;
  final ActivityRepository? activityRepository;
  final Uuid uuid;

  RevokeDocumentAccessUseCase({
    required this.documentRepository,
    required this.familyRepository,
    this.activityRepository,
    this.uuid = const Uuid(),
  });

  Future<void> execute({
    required String documentId,
    required String revokerUid,
    required String granteeId,
    String? granteeEmail,
  }) async {
    final document = await documentRepository.getDocumentById(documentId);
    if (document == null) {
      throw StateError('Document not found: $documentId');
    }

    if (document.ownerUid != revokerUid) {
      final revokerPerm = await familyRepository.getPermission(
        documentId: documentId,
        granteeId: revokerUid,
      );
      if (revokerPerm == null || !revokerPerm.canShare || revokerPerm.isExpired) {
        throw StateError(
          'Access Denied: Only the document owner or co-sharer can revoke access.',
        );
      }
    }

    await documentRepository.deleteKeyEnvelope(
      documentId: documentId,
      recipientId: granteeId,
      recipientEmail: granteeEmail,
    );
    await familyRepository.revokePermission(
      documentId: documentId,
      granteeId: granteeId,
      granteeEmail: granteeEmail,
    );

    if (activityRepository != null) {
      await activityRepository!.logEvent(
        ActivityEvent(
          activityId: uuid.v4(),
          actorUid: revokerUid,
          targetDocumentId: documentId,
          targetMemberUid: granteeId,
          eventType: ActivityEventType.shareRevoked,
          summary: 'Revoked document access for ${granteeEmail ?? granteeId}',
          metadata: {
            'granteeEmail': ?granteeEmail,
          },
          timestamp: DateTime.now().toUtc(),
        ),
      );
    }
  }
}
