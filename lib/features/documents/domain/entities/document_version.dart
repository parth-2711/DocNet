import 'package:docnet/features/security/domain/entities/encrypted_metadata.dart';

/// Immutable document version record matching DATABASE_SCHEMA.md Section 10.
class DocumentVersion {
  final int schemaVersion;
  final String documentId;
  final String versionId;
  final int versionNumber;
  final String? parentVersionId;
  final String ownerUid;
  final String storageObjectRef;
  final int storageObjectSize;
  final String sha256;
  final EncryptedMetadata encryptedMetadata;
  final DateTime createdAt;
  final String uploadedByUid;
  final DateTime? committedAt;

  const DocumentVersion({
    this.schemaVersion = 1,
    required this.documentId,
    required this.versionId,
    required this.versionNumber,
    this.parentVersionId,
    required this.ownerUid,
    required this.storageObjectRef,
    required this.storageObjectSize,
    required this.sha256,
    required this.encryptedMetadata,
    required this.createdAt,
    required this.uploadedByUid,
    this.committedAt,
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'schemaVersion': schemaVersion,
      'documentId': documentId,
      'versionId': versionId,
      'versionNumber': versionNumber,
      'parentVersionId': parentVersionId,
      'ownerUid': ownerUid,
      'storageObjectRef': storageObjectRef,
      'storageObjectSize': storageObjectSize,
      'sha256': sha256,
      'encryptedMetadata': encryptedMetadata.toFirestoreMap(),
      'createdAt': createdAt.toIso8601String(),
      'uploadedByUid': uploadedByUid,
      'committedAt': committedAt?.toIso8601String(),
    };
  }

  factory DocumentVersion.fromFirestoreMap(Map<String, dynamic> map) {
    return DocumentVersion(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      documentId: map['documentId'] as String,
      versionId: map['versionId'] as String,
      versionNumber: map['versionNumber'] as int,
      parentVersionId: map['parentVersionId'] as String?,
      ownerUid: map['ownerUid'] as String,
      storageObjectRef: map['storageObjectRef'] as String,
      storageObjectSize: map['storageObjectSize'] as int,
      sha256: map['sha256'] as String,
      encryptedMetadata: EncryptedMetadata.fromFirestoreMap(
        map['encryptedMetadata'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      uploadedByUid: map['uploadedByUid'] as String,
      committedAt: map['committedAt'] != null
          ? DateTime.parse(map['committedAt'] as String)
          : null,
    );
  }
}
