/// Document permission record matching DATABASE_SCHEMA.md Section 12.
/// Enforces explicit document-level permissions (PRD.md SHARE-002, SHARE-003).
class DocumentPermission {
  final int schemaVersion;
  final String permissionId;
  final String documentId;
  final String granteeType; // 'user' or 'family'
  final String granteeId; // UID or familyId
  final bool canView;
  final bool canDownload;
  final bool canEdit;
  final bool canShare;
  final String grantedBy;
  final DateTime grantedAt;
  final DateTime? expiresAt;

  const DocumentPermission({
    this.schemaVersion = 1,
    required this.permissionId,
    required this.documentId,
    required this.granteeType,
    required this.granteeId,
    this.canView = true,
    this.canDownload = false,
    this.canEdit = false,
    this.canShare = false,
    required this.grantedBy,
    required this.grantedAt,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'permissionId': permissionId,
      'documentId': documentId,
      'granteeType': granteeType,
      'granteeId': granteeId,
      'canView': canView,
      'canDownload': canDownload,
      'canEdit': canEdit,
      'canShare': canShare,
      'grantedBy': grantedBy,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory DocumentPermission.fromMap(Map<String, dynamic> map) {
    return DocumentPermission(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      permissionId: map['permissionId'] as String,
      documentId: map['documentId'] as String,
      granteeType: map['granteeType'] as String,
      granteeId: map['granteeId'] as String,
      canView: map['canView'] as bool? ?? true,
      canDownload: map['canDownload'] as bool? ?? false,
      canEdit: map['canEdit'] as bool? ?? false,
      canShare: map['canShare'] as bool? ?? false,
      grantedBy: map['grantedBy'] as String,
      grantedAt: DateTime.parse(map['grantedAt'] as String),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
    );
  }
}
