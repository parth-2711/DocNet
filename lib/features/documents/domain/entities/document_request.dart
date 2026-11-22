/// Status of a document request (PRD.md REQ-005 & DATABASE_SCHEMA.md Section 15).
enum DocumentRequestStatus { pending, fulfilled, declined, cancelled, expired }

/// Domain entity representing a formal document request between family members
/// (PRD.md Section 6.8, REQ-001 through REQ-005, DATABASE_SCHEMA.md Section 15).
class DocumentRequest {
  final int schemaVersion;
  final String requestId;
  final String familyId;
  final String requesterUid;
  final String recipientUid;
  final String title;
  final String? notes;
  final DocumentRequestStatus status;
  final String? fulfilledDocumentId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  const DocumentRequest({
    this.schemaVersion = 1,
    required this.requestId,
    required this.familyId,
    required this.requesterUid,
    required this.recipientUid,
    required this.title,
    this.notes,
    this.status = DocumentRequestStatus.pending,
    this.fulfilledDocumentId,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'requestId': requestId,
      'familyId': familyId,
      'requesterUid': requesterUid,
      'recipientUid': recipientUid,
      'title': title,
      'notes': notes,
      'status': status.name,
      'fulfilledDocumentId': fulfilledDocumentId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  factory DocumentRequest.fromMap(Map<String, dynamic> map) {
    return DocumentRequest(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      requestId: map['requestId'] as String,
      familyId: map['familyId'] as String,
      requesterUid: map['requesterUid'] as String,
      recipientUid: map['recipientUid'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      status: DocumentRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DocumentRequestStatus.pending,
      ),
      fulfilledDocumentId: map['fulfilledDocumentId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      respondedAt: map['respondedAt'] != null
          ? DateTime.parse(map['respondedAt'] as String)
          : null,
    );
  }

  DocumentRequest copyWith({
    DocumentRequestStatus? status,
    String? fulfilledDocumentId,
    DateTime? respondedAt,
  }) {
    return DocumentRequest(
      schemaVersion: schemaVersion,
      requestId: requestId,
      familyId: familyId,
      requesterUid: requesterUid,
      recipientUid: recipientUid,
      title: title,
      notes: notes,
      status: status ?? this.status,
      fulfilledDocumentId: fulfilledDocumentId ?? this.fulfilledDocumentId,
      createdAt: createdAt,
      expiresAt: expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}
