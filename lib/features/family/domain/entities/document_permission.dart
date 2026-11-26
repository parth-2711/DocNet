/// Document permission record matching DATABASE_SCHEMA.md Section 12.
/// Enforces explicit document-level permissions (PRD.md SHARE-002, SHARE-003).
class DocumentPermission {
  final int schemaVersion;
  final String permissionId;
  final String documentId;
  final String granteeType; // 'user' or 'family'
  final String granteeId; // UID or familyId
  final String? granteeEmail; // Normalized email for cross-device matching
  final String? granteeDisplayName;
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
    this.granteeEmail,
    this.granteeDisplayName,
    this.canView = true,
    this.canDownload = false,
    this.canEdit = false,
    this.canShare = false,
    required this.grantedBy,
    required this.grantedAt,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!);

  bool matchesUser({required String uid, String? email}) {
    if (granteeId == uid) return true;
    final norm = email?.trim().toLowerCase();
    if (norm != null &&
        norm.isNotEmpty &&
        granteeEmail?.trim().toLowerCase() == norm) {
      return true;
    }
    return false;
  }

  DocumentPermission copyWith({
    String? granteeId,
    String? granteeEmail,
    String? granteeDisplayName,
    bool? canView,
    bool? canDownload,
    bool? canEdit,
    bool? canShare,
    DateTime? grantedAt,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) {
    return DocumentPermission(
      schemaVersion: schemaVersion,
      permissionId: permissionId,
      documentId: documentId,
      granteeType: granteeType,
      granteeId: granteeId ?? this.granteeId,
      granteeEmail: granteeEmail ?? this.granteeEmail,
      granteeDisplayName: granteeDisplayName ?? this.granteeDisplayName,
      canView: canView ?? this.canView,
      canDownload: canDownload ?? this.canDownload,
      canEdit: canEdit ?? this.canEdit,
      canShare: canShare ?? this.canShare,
      grantedBy: grantedBy,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'permissionId': permissionId,
      'documentId': documentId,
      'granteeType': granteeType,
      'granteeId': granteeId,
      if (granteeEmail != null) 'granteeEmail': granteeEmail,
      if (granteeDisplayName != null) 'granteeDisplayName': granteeDisplayName,
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
      granteeEmail: (map['granteeEmail'] as String?)?.toLowerCase(),
      granteeDisplayName: map['granteeDisplayName'] as String?,
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
