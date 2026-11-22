/// Strategies for resolving concurrent modification conflicts (SYNC_ENGINE.md Section 8).
enum ConflictResolutionStrategy {
  /// Discard local pending changes and keep the remote version as authoritative.
  keepRemote,

  /// Rebase the local change so it becomes a new version with the remote version as parent.
  keepLocal,

  /// Save local changes as a separate new document with a new documentId, preserving both.
  saveBoth,
}

/// Domain entity representing a conflict needing user attention (SYNC_ENGINE.md Section 8 & 15).
class DocumentConflict {
  final String documentId;
  final String localVersionId;
  final String? localExpectedParentId;
  final DateTime localUpdatedAt;
  final String remoteVersionId;
  final int remoteVersionNumber;
  final DateTime remoteUpdatedAt;

  const DocumentConflict({
    required this.documentId,
    required this.localVersionId,
    this.localExpectedParentId,
    required this.localUpdatedAt,
    required this.remoteVersionId,
    required this.remoteVersionNumber,
    required this.remoteUpdatedAt,
  });
}
