import '../../domain/entities/document_record.dart';
import '../../domain/entities/document_version.dart';
import '../../domain/entities/key_envelope.dart';
import '../../domain/repositories/document_repository.dart';

/// In-memory implementation of DocumentRepository for local development, offline storage, and tests.
class InMemoryDocumentRepository implements DocumentRepository {
  final Map<String, DocumentRecord> _documents = {};
  final Map<String, List<DocumentVersion>> _versions = {};
  final Map<String, List<KeyEnvelope>> _envelopes = {};

  @override
  Future<List<DocumentRecord>> getDocuments({
    String? category,
    String? ownerUid,
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async {
    return _documents.values.where((doc) {
      if (!includeDeleted && doc.isDeleted) {
        return false;
      }
      if (!includeArchived && doc.isArchived) {
        return false;
      }
      if (category != null && category != 'All' && doc.category != category) {
        return false;
      }
      if (ownerUid != null && ownerUid.isNotEmpty && doc.ownerUid != ownerUid) {
        final envelopes = _envelopes[doc.documentId] ?? [];
        final isShared = envelopes.any((e) => e.recipientId == ownerUid);
        if (!isShared && doc.category != 'Family') return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<DocumentRecord?> getDocumentById(String documentId) async {
    return _documents[documentId];
  }

  @override
  Future<void> saveDocument(DocumentRecord document) async {
    _documents[document.documentId] = document;
  }

  @override
  Future<void> saveVersion(DocumentVersion version) async {
    _versions.putIfAbsent(version.documentId, () => []).add(version);
  }

  @override
  Future<List<DocumentVersion>> getVersions(String documentId) async {
    final list = _versions[documentId] ?? [];
    list.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return List.unmodifiable(list);
  }

  @override
  Future<void> saveKeyEnvelope(KeyEnvelope envelope) async {
    _envelopes.putIfAbsent(envelope.documentId, () => []).add(envelope);
  }

  @override
  Future<KeyEnvelope?> getKeyEnvelope({
    required String documentId,
    required String recipientId,
  }) async {
    final list = _envelopes[documentId] ?? [];
    if (list.isEmpty) return null;

    // Direct match
    for (final e in list) {
      if (e.recipientId == recipientId) return e;
    }

    // Normalized email match
    final cleanRecipient = recipientId.replaceFirst('uid-google-', 'uid-');
    for (final e in list) {
      final cleanEnv = e.recipientId.replaceFirst('uid-google-', 'uid-');
      if (cleanEnv == cleanRecipient) return e;
    }

    return null;
  }

  @override
  Future<void> softDeleteDocument(String documentId) async {
    final doc = _documents[documentId];
    if (doc != null) {
      _documents[documentId] = doc.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<void> toggleFavorite(String documentId) async {
    final doc = _documents[documentId];
    if (doc != null) {
      _documents[documentId] = doc.copyWith(isFavorite: !doc.isFavorite);
    }
  }

  @override
  Future<void> permanentlyDeleteDocument(String documentId) async {
    _documents.remove(documentId);
    _versions.remove(documentId);
    _envelopes.remove(documentId);
  }
}
