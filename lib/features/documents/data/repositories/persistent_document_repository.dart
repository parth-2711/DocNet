import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/entities/document_version.dart';
import '../../domain/entities/key_envelope.dart';
import '../../domain/repositories/document_repository.dart';

/// Persistent implementation of DocumentRepository saving document metadata,
/// version histories, and key envelopes directly to persistent device storage
/// (PRD.md DOC-017, SYNC_ENGINE.md Section 6).
class PersistentDocumentRepository implements DocumentRepository {
  final LocalVaultStorageService storageService;

  final Map<String, DocumentRecord> _documents = {};
  final Map<String, List<DocumentVersion>> _versions = {};
  final Map<String, List<KeyEnvelope>> _envelopes = {};
  bool _loaded = false;

  PersistentDocumentRepository(this.storageService);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final docData = await storageService.readJson('documents');
      if (docData is Map<String, dynamic>) {
        // Load documents
        if (docData['documents'] is List) {
          for (final item in docData['documents']) {
            if (item is Map<String, dynamic>) {
              final doc = DocumentRecord.fromFirestoreMap(
                item,
                decryptedName: item['decryptedName'] as String?,
                decryptedDesc: item['decryptedDescription'] as String?,
                decryptedTags: (item['decryptedTags'] as List?)?.cast<String>(),
              );
              _documents[doc.documentId] = doc;
            }
          }
        }

        // Load versions
        if (docData['versions'] is Map<String, dynamic>) {
          final verMap = docData['versions'] as Map<String, dynamic>;
          verMap.forEach((docId, verList) {
            if (verList is List) {
              _versions[docId] = verList
                  .whereType<Map<String, dynamic>>()
                  .map((m) => DocumentVersion.fromFirestoreMap(m))
                  .toList();
            }
          });
        }

        // Load envelopes
        if (docData['envelopes'] is Map<String, dynamic>) {
          final envMap = docData['envelopes'] as Map<String, dynamic>;
          envMap.forEach((docId, envList) {
            if (envList is List) {
              _envelopes[docId] = envList
                  .whereType<Map<String, dynamic>>()
                  .map((m) => KeyEnvelope.fromFirestoreMap(m))
                  .toList();
            }
          });
        }
      }
    } catch (_) {
      // Ignore initial missing file
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final docsList = _documents.values.map((doc) {
      final map = doc.toFirestoreMap();
      if (doc.decryptedName != null) {
        map['decryptedName'] = doc.decryptedName;
      }
      if (doc.decryptedDescription != null) {
        map['decryptedDescription'] = doc.decryptedDescription;
      }
      map['decryptedTags'] = doc.decryptedTags;
      return map;
    }).toList();

    final versionsMap = <String, dynamic>{};
    _versions.forEach((docId, list) {
      versionsMap[docId] = list.map((v) => v.toFirestoreMap()).toList();
    });

    final envelopesMap = <String, dynamic>{};
    _envelopes.forEach((docId, list) {
      envelopesMap[docId] = list.map((e) => e.toFirestoreMap()).toList();
    });

    await storageService.saveJson('documents', {
      'documents': docsList,
      'versions': versionsMap,
      'envelopes': envelopesMap,
    });
  }

  @override
  Future<List<DocumentRecord>> getDocuments({
    String? category,
    String? ownerUid,
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async {
    await _ensureLoaded();

    return _documents.values.where((doc) {
      if (!includeDeleted && doc.isDeleted) return false;
      if (!includeArchived && doc.isArchived) return false;
      if (category != null && category != 'All' && doc.category != category) {
        return false;
      }
      if (ownerUid != null && ownerUid.isNotEmpty) {
        if (doc.ownerUid != ownerUid) {
          final envelopes = _envelopes[doc.documentId] ?? [];
          final isShared = envelopes.any((e) => e.recipientId == ownerUid);
          if (!isShared && doc.category != 'Family') return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Future<DocumentRecord?> getDocumentById(String documentId) async {
    await _ensureLoaded();
    return _documents[documentId];
  }

  @override
  Future<void> saveDocument(DocumentRecord document) async {
    await _ensureLoaded();
    _documents[document.documentId] = document;
    await _persist();
  }

  @override
  Future<void> saveVersion(DocumentVersion version) async {
    await _ensureLoaded();
    _versions.putIfAbsent(version.documentId, () => []).add(version);
    await _persist();
  }

  @override
  Future<List<DocumentVersion>> getVersions(String documentId) async {
    await _ensureLoaded();
    final list = _versions[documentId] ?? [];
    list.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return List.unmodifiable(list);
  }

  @override
  Future<void> saveKeyEnvelope(KeyEnvelope envelope) async {
    await _ensureLoaded();
    _envelopes.putIfAbsent(envelope.documentId, () => []).add(envelope);
    await _persist();
  }

  @override
  Future<KeyEnvelope?> getKeyEnvelope({
    required String documentId,
    required String recipientId,
  }) async {
    await _ensureLoaded();
    final list = _envelopes[documentId] ?? [];
    if (list.isEmpty) return null;

    // 1. Direct exact match
    for (final e in list) {
      if (e.recipientId == recipientId) {
        return e;
      }
    }

    // 2. Normalized email match (e.g. uid-google-user-gmail-com vs uid-user-gmail-com)
    final cleanRecipient = recipientId.replaceFirst('uid-google-', 'uid-');
    for (final e in list) {
      final cleanEnvRecipient =
          e.recipientId.replaceFirst('uid-google-', 'uid-');
      if (cleanEnvRecipient == cleanRecipient) {
        final healed = KeyEnvelope(
          schemaVersion: e.schemaVersion,
          envelopeId: e.envelopeId,
          documentId: e.documentId,
          recipientType: e.recipientType,
          recipientId: recipientId,
          wrappedDek: e.wrappedDek,
          wrappingAlgorithm: e.wrappingAlgorithm,
          keyEpoch: e.keyEpoch,
          createdAt: e.createdAt,
        );
        list.add(healed);
        await _persist();
        return healed;
      }
    }

    // 3. Legacy demo/test account healing (uid-test-familyvault-app / guest-uid)
    final legacyIndex = list.indexWhere(
      (e) =>
          e.recipientId == 'uid-test-familyvault-app' ||
          e.recipientId == 'guest-uid',
    );
    if (legacyIndex != -1) {
      final legacyEnv = list[legacyIndex];
      final healedEnv = KeyEnvelope(
        schemaVersion: legacyEnv.schemaVersion,
        envelopeId: legacyEnv.envelopeId,
        documentId: legacyEnv.documentId,
        recipientType: legacyEnv.recipientType,
        recipientId: recipientId,
        wrappedDek: legacyEnv.wrappedDek,
        wrappingAlgorithm: legacyEnv.wrappingAlgorithm,
        keyEpoch: legacyEnv.keyEpoch,
        createdAt: legacyEnv.createdAt,
      );
      list.add(healedEnv);

      // Also heal the document record's ownerUid if it was the legacy demo account
      final doc = _documents[documentId];
      if (doc != null &&
          (doc.ownerUid == 'uid-test-familyvault-app' ||
              doc.ownerUid == 'guest-uid')) {
        _documents[documentId] = doc.copyWith(ownerUid: recipientId);
      }

      await _persist();
      return healedEnv;
    }

    // 4. Document-owner fallback:
    // If the document is owned by recipientId, allow the owner to access their key envelope.
    final doc = _documents[documentId];
    if (doc != null && doc.ownerUid == recipientId && list.isNotEmpty) {
      final existingEnv = list.first;
      final healedEnv = KeyEnvelope(
        schemaVersion: existingEnv.schemaVersion,
        envelopeId: existingEnv.envelopeId,
        documentId: existingEnv.documentId,
        recipientType: existingEnv.recipientType,
        recipientId: recipientId,
        wrappedDek: existingEnv.wrappedDek,
        wrappingAlgorithm: existingEnv.wrappingAlgorithm,
        keyEpoch: existingEnv.keyEpoch,
        createdAt: existingEnv.createdAt,
      );
      list.add(healedEnv);
      await _persist();
      return healedEnv;
    }

    // 5. Family category shared envelope:
    // If the document is categorized as Family, allow group members to access the envelope.
    if (doc != null && doc.category == 'Family' && list.isNotEmpty) {
      final existingEnv = list.first;
      final familyEnv = KeyEnvelope(
        schemaVersion: existingEnv.schemaVersion,
        envelopeId: existingEnv.envelopeId,
        documentId: existingEnv.documentId,
        recipientType: 'user',
        recipientId: recipientId,
        wrappedDek: existingEnv.wrappedDek,
        wrappingAlgorithm: existingEnv.wrappingAlgorithm,
        keyEpoch: existingEnv.keyEpoch,
        createdAt: existingEnv.createdAt,
      );
      list.add(familyEnv);
      await _persist();
      return familyEnv;
    }

    return null;
  }

  @override
  Future<void> softDeleteDocument(String documentId) async {
    await _ensureLoaded();
    final doc = _documents[documentId];
    if (doc != null) {
      _documents[documentId] = doc.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now().toUtc(),
      );
      await _persist();
    }
  }

  @override
  Future<void> toggleFavorite(String documentId) async {
    await _ensureLoaded();
    final doc = _documents[documentId];
    if (doc != null) {
      _documents[documentId] = doc.copyWith(isFavorite: !doc.isFavorite);
      await _persist();
    }
  }

  @override
  Future<void> permanentlyDeleteDocument(String documentId) async {
    await _ensureLoaded();
    _documents.remove(documentId);
    _versions.remove(documentId);
    _envelopes.remove(documentId);
    await _persist();
  }
}
