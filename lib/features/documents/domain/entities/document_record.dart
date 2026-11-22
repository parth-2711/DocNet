import 'package:docnet/features/security/domain/entities/encrypted_metadata.dart';

/// Document metadata record matching DATABASE_SCHEMA.md Section 9.
class DocumentRecord {
  final int schemaVersion;
  final String documentId;
  final String ownerUid;
  final String currentVersionId;
  final String category;
  final String? folderId;
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final DateTime? deletedAt;
  final EncryptedMetadata encryptedMetadata;
  final String mimeType;
  final int originalSizeBytes;
  final int encryptedSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int keyEpoch;
  final int versionCount;

  // Decrypted plaintext metadata (only present locally in-memory on authorized clients)
  final String? decryptedName;
  final String? decryptedDescription;
  final List<String> decryptedTags;

  const DocumentRecord({
    this.schemaVersion = 1,
    required this.documentId,
    required this.ownerUid,
    required this.currentVersionId,
    required this.category,
    this.folderId,
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.deletedAt,
    required this.encryptedMetadata,
    required this.mimeType,
    required this.originalSizeBytes,
    required this.encryptedSizeBytes,
    required this.createdAt,
    required this.updatedAt,
    this.keyEpoch = 1,
    this.versionCount = 1,
    this.decryptedName,
    this.decryptedDescription,
    this.decryptedTags = const [],
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'schemaVersion': schemaVersion,
      'documentId': documentId,
      'ownerUid': ownerUid,
      'currentVersionId': currentVersionId,
      'category': category,
      'folderId': folderId,
      'isFavorite': isFavorite,
      'isArchived': isArchived,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'encryptedMetadata': encryptedMetadata.toFirestoreMap(),
      'mimeType': mimeType,
      'originalSizeBytes': originalSizeBytes,
      'encryptedSizeBytes': encryptedSizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'keyEpoch': keyEpoch,
      'versionCount': versionCount,
    };
  }

  factory DocumentRecord.fromFirestoreMap(
    Map<String, dynamic> map, {
    String? decryptedName,
    String? decryptedDesc,
    List<String>? decryptedTags,
  }) {
    return DocumentRecord(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      documentId: map['documentId'] as String,
      ownerUid: map['ownerUid'] as String,
      currentVersionId: map['currentVersionId'] as String,
      category: map['category'] as String,
      folderId: map['folderId'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      encryptedMetadata: EncryptedMetadata.fromFirestoreMap(
        map['encryptedMetadata'] as Map<String, dynamic>,
      ),
      mimeType: map['mimeType'] as String,
      originalSizeBytes: map['originalSizeBytes'] as int,
      encryptedSizeBytes: map['encryptedSizeBytes'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      keyEpoch: map['keyEpoch'] as int? ?? 1,
      versionCount: map['versionCount'] as int? ?? 1,
      decryptedName: decryptedName,
      decryptedDescription: decryptedDesc,
      decryptedTags: decryptedTags ?? const [],
    );
  }

  DocumentRecord copyWith({
    String? ownerUid,
    String? currentVersionId,
    String? category,
    String? folderId,
    bool? isFavorite,
    bool? isArchived,
    bool? isDeleted,
    DateTime? deletedAt,
    EncryptedMetadata? encryptedMetadata,
    int? originalSizeBytes,
    int? encryptedSizeBytes,
    DateTime? updatedAt,
    int? keyEpoch,
    int? versionCount,
    String? decryptedName,
    String? decryptedDescription,
    List<String>? decryptedTags,
  }) {
    return DocumentRecord(
      schemaVersion: schemaVersion,
      documentId: documentId,
      ownerUid: ownerUid ?? this.ownerUid,
      currentVersionId: currentVersionId ?? this.currentVersionId,
      category: category ?? this.category,
      folderId: folderId ?? this.folderId,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      encryptedMetadata: encryptedMetadata ?? this.encryptedMetadata,
      mimeType: mimeType,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      encryptedSizeBytes: encryptedSizeBytes ?? this.encryptedSizeBytes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      keyEpoch: keyEpoch ?? this.keyEpoch,
      versionCount: versionCount ?? this.versionCount,
      decryptedName: decryptedName ?? this.decryptedName,
      decryptedDescription: decryptedDescription ?? this.decryptedDescription,
      decryptedTags: decryptedTags ?? this.decryptedTags,
    );
  }
}
