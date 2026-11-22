/// Activity event types matching PRD.md Section 6.12 & DATABASE_SCHEMA.md Section 3.
enum ActivityEventType {
  signIn,
  signOut,
  deviceEnrolled,
  deviceRevoked,
  documentCreated,
  documentReplaced,
  documentDeleted,
  documentRestored,
  documentExported,
  shareGranted,
  shareRevoked,
  familyCreated,
  familyInvitationSent,
  familyMemberJoined,
  familyMemberRemoved,
  familyRoleUpdated,
  recoveryPhraseGenerated,
  recoveryPhraseVerified,
}

/// Domain entity representing an immutable security/audit trail event (PRD.md 6.12, AUDIT-001, AUDIT-002).
///
/// Plaintext document names, file contents, identity numbers, keys, recovery phrases,
/// or decrypted OCR text must NEVER be recorded in this entity or logged.
class ActivityEvent {
  final int schemaVersion;
  final String activityId;
  final String? familyId;
  final ActivityEventType eventType;
  final String actorUid;
  final String? targetDocumentId;
  final String? targetMemberUid;
  final String summary;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const ActivityEvent({
    this.schemaVersion = 1,
    required this.activityId,
    this.familyId,
    required this.eventType,
    required this.actorUid,
    this.targetDocumentId,
    this.targetMemberUid,
    required this.summary,
    this.metadata = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'schemaVersion': schemaVersion,
      'activityId': activityId,
      'familyId': familyId,
      'eventType': eventType.name,
      'actorUid': actorUid,
      'targetDocumentId': targetDocumentId,
      'targetMemberUid': targetMemberUid,
      'summary': summary,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityEvent.fromFirestoreMap(Map<String, dynamic> map) {
    return ActivityEvent(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      activityId: map['activityId'] as String,
      familyId: map['familyId'] as String?,
      eventType: ActivityEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => ActivityEventType.documentCreated,
      ),
      actorUid: map['actorUid'] as String,
      targetDocumentId: map['targetDocumentId'] as String?,
      targetMemberUid: map['targetMemberUid'] as String?,
      summary: map['summary'] as String,
      metadata: Map<String, dynamic>.from(
        (map['metadata'] as Map?) ?? const {},
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
