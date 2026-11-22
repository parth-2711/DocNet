/// Represents an individual item in a sync manifest (SYNC_ENGINE.md Section 5).
class SyncManifestItem {
  final String documentId;
  final String vaultScope; // 'personal' or 'family'
  final String currentVersionId;
  final int versionNumber;
  final DateTime updatedAt;
  final String encryptedMetadataRef;
  final int keyEpoch;
  final bool isDeleted; // Tombstone status (SYNC_ENGINE.md Section 12)

  const SyncManifestItem({
    required this.documentId,
    required this.vaultScope,
    required this.currentVersionId,
    required this.versionNumber,
    required this.updatedAt,
    required this.encryptedMetadataRef,
    required this.keyEpoch,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'vaultScope': vaultScope,
      'currentVersionId': currentVersionId,
      'versionNumber': versionNumber,
      'updatedAt': updatedAt.toIso8601String(),
      'encryptedMetadataRef': encryptedMetadataRef,
      'keyEpoch': keyEpoch,
      'isDeleted': isDeleted,
    };
  }

  factory SyncManifestItem.fromMap(Map<String, dynamic> map) {
    return SyncManifestItem(
      documentId: map['documentId'] as String,
      vaultScope: map['vaultScope'] as String? ?? 'personal',
      currentVersionId: map['currentVersionId'] as String,
      versionNumber: map['versionNumber'] as int? ?? 1,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      encryptedMetadataRef: map['encryptedMetadataRef'] as String? ?? '',
      keyEpoch: map['keyEpoch'] as int? ?? 1,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }
}

/// Paginated cursor-based manifest container (SYNC_ENGINE.md Section 5).
class SyncManifest {
  final List<SyncManifestItem> items;
  final String? nextCursor;
  final bool hasMore;
  final DateTime timestamp;

  const SyncManifest({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((i) => i.toMap()).toList(),
      'nextCursor': nextCursor,
      'hasMore': hasMore,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SyncManifest.fromMap(Map<String, dynamic> map) {
    return SyncManifest(
      items:
          (map['items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    SyncManifestItem.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      nextCursor: map['nextCursor'] as String?,
      hasMore: map['hasMore'] as bool? ?? false,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
