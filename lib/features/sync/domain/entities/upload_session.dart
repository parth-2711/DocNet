/// Lifecycle statuses for an upload session (DATABASE_SCHEMA.md Section 16 & API_SPECIFICATION.md).
enum UploadSessionStatus {
  created,
  uploading,
  uploaded,
  committed,
  expired,
  cancelled,
}

/// Represents an authorized, short-lived resumable upload session
/// (DATABASE_SCHEMA.md Section 16, API_SPECIFICATION.md Section 3, SYNC_ENGINE.md Section 6).
class UploadSession {
  final int schemaVersion;
  final String sessionId;
  final String ownerUid;
  final String documentId;
  final String versionId;
  final String? expectedParentVersionId;
  final String storageObjectPath;
  final int expectedEncryptedSize;
  final UploadSessionStatus status;
  final int uploadedBytes;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String idempotencyKey;

  const UploadSession({
    this.schemaVersion = 1,
    required this.sessionId,
    required this.ownerUid,
    required this.documentId,
    required this.versionId,
    this.expectedParentVersionId,
    required this.storageObjectPath,
    required this.expectedEncryptedSize,
    this.status = UploadSessionStatus.created,
    this.uploadedBytes = 0,
    required this.createdAt,
    required this.expiresAt,
    required this.idempotencyKey,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  double get progressFraction => expectedEncryptedSize > 0
      ? (uploadedBytes / expectedEncryptedSize).clamp(0.0, 1.0)
      : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'sessionId': sessionId,
      'ownerUid': ownerUid,
      'documentId': documentId,
      'versionId': versionId,
      'expectedParentVersionId': expectedParentVersionId,
      'storageObjectPath': storageObjectPath,
      'expectedEncryptedSize': expectedEncryptedSize,
      'status': status.name,
      'uploadedBytes': uploadedBytes,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'idempotencyKey': idempotencyKey,
    };
  }

  factory UploadSession.fromMap(Map<String, dynamic> map) {
    return UploadSession(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      sessionId: map['sessionId'] as String,
      ownerUid: map['ownerUid'] as String,
      documentId: map['documentId'] as String,
      versionId: map['versionId'] as String,
      expectedParentVersionId: map['expectedParentVersionId'] as String?,
      storageObjectPath: map['storageObjectPath'] as String,
      expectedEncryptedSize: map['expectedEncryptedSize'] as int,
      status: UploadSessionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => UploadSessionStatus.created,
      ),
      uploadedBytes: map['uploadedBytes'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      idempotencyKey: map['idempotencyKey'] as String,
    );
  }

  UploadSession copyWith({
    UploadSessionStatus? status,
    int? uploadedBytes,
    DateTime? expiresAt,
  }) {
    return UploadSession(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      ownerUid: ownerUid,
      documentId: documentId,
      versionId: versionId,
      expectedParentVersionId: expectedParentVersionId,
      storageObjectPath: storageObjectPath,
      expectedEncryptedSize: expectedEncryptedSize,
      status: status ?? this.status,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      idempotencyKey: idempotencyKey,
    );
  }
}
