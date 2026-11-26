import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:docnet/core/logging/app_logger.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../../security/data/crypto/cryptography_crypto_service.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/entities/document_version.dart';
import '../../domain/entities/key_envelope.dart';
import '../../domain/repositories/document_repository.dart';

/// Persistent implementation of DocumentRepository saving document metadata,
/// version histories, and key envelopes directly to persistent device storage
/// and syncing shared zero-knowledge records via Cloud Firestore
/// (PRD.md DOC-017, SYNC_ENGINE.md Section 6).
class PersistentDocumentRepository implements DocumentRepository {
  final LocalVaultStorageService storageService;

  final Map<String, DocumentRecord> _documents = {};
  final Map<String, List<DocumentVersion>> _versions = {};
  final Map<String, List<KeyEnvelope>> _envelopes = {};
  bool _loaded = false;

  PersistentDocumentRepository(this.storageService);

  static bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canUseFirestore => Firebase.apps.isNotEmpty && !_isTestEnvironment;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

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

  /// Pulls documents explicitly shared with [uid] or [email] from Firestore,
  /// decrypting zero-knowledge metadata locally using the recipient's KeyEnvelope
  /// and purging any local shared document whose access was revoked.
  Future<void> _syncSharedFromFirestore({
    required String uid,
    String? email,
  }) async {
    if (!_canUseFirestore) return;
    final normalizedEmail = email?.trim().toLowerCase();

    try {
      final remoteEnvelopes = <String, KeyEnvelope>{};

      final uidEnvSnap = await _firestore
          .collection('key_envelopes')
          .where('recipientId', isEqualTo: uid)
          .get();
      for (final doc in uidEnvSnap.docs) {
        final env = KeyEnvelope.fromFirestoreMap(doc.data());
        remoteEnvelopes[env.documentId] = env;
      }

      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        final emailEnvSnap = await _firestore
            .collection('key_envelopes')
            .where('recipientEmail', isEqualTo: normalizedEmail)
            .get();
        for (final doc in emailEnvSnap.docs) {
          final env = KeyEnvelope.fromFirestoreMap(doc.data());
          remoteEnvelopes[env.documentId] = env;
        }
      }

      // Check permissions for expiry / revocation
      final revokedDocIds = <String>{};
      final permDocsByDocId = <String, Map<String, dynamic>>{};

      final uidPermSnap = await _firestore
          .collection('document_permissions')
          .where('granteeId', isEqualTo: uid)
          .get();
      for (final doc in uidPermSnap.docs) {
        final data = doc.data();
        permDocsByDocId[data['documentId'] as String] = data;
      }

      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        final emailPermSnap = await _firestore
            .collection('document_permissions')
            .where('granteeEmail', isEqualTo: normalizedEmail)
            .get();
        for (final doc in emailPermSnap.docs) {
          final data = doc.data();
          permDocsByDocId[data['documentId'] as String] = data;
        }
      }

      for (final entry in permDocsByDocId.entries) {
        final canView = entry.value['canView'] as bool? ?? true;
        final expiresAtStr = entry.value['expiresAt'] as String?;
        final isExpired = expiresAtStr != null &&
            DateTime.now().toUtc().isAfter(DateTime.parse(expiresAtStr));
        if (!canView || isExpired) {
          revokedDocIds.add(entry.key);
        }
      }

      // Purge any locally cached non-owned document that was revoked or expired
      final localNonOwnedIds = _documents.values
          .where((d) => d.ownerUid != uid)
          .map((d) => d.documentId)
          .toList();
      for (final docId in localNonOwnedIds) {
        if (!remoteEnvelopes.containsKey(docId) ||
            revokedDocIds.contains(docId)) {
          _envelopes[docId]?.removeWhere(
            (e) =>
                e.recipientId == uid ||
                (normalizedEmail != null &&
                    normalizedEmail.isNotEmpty &&
                    e.recipientEmail?.toLowerCase() == normalizedEmail),
          );
          _documents.remove(docId);
        }
      }

      // Sync active remote shared documents locally
      final crypto = CryptographyCryptoService();
      for (final entry in remoteEnvelopes.entries) {
        final docId = entry.key;
        final env = entry.value;
        if (revokedDocIds.contains(docId)) continue;

        final list = _envelopes.putIfAbsent(docId, () => []);
        list.removeWhere((e) => e.envelopeId == env.envelopeId || e.recipientId == env.recipientId);
        list.add(env);

        final docSnap = await _firestore.collection('documents').doc(docId).get();
        if (docSnap.exists && docSnap.data() != null) {
          var record = DocumentRecord.fromFirestoreMap(docSnap.data()!);

          // Decrypt zero-knowledge metadata locally using recipient's DEK
          if (record.decryptedName == null) {
            try {
              final dek = Uint8List.fromList(base64Decode(env.wrappedDek));
              final meta = await crypto.decryptMetadata(
                encryptedMetadata: record.encryptedMetadata,
                key: dek,
              );
              record = record.copyWith(
                decryptedName: meta['name'] as String?,
                decryptedDescription: meta['description'] as String?,
                decryptedTags: (meta['tags'] as List?)?.cast<String>() ?? const [],
              );
            } catch (_) {}
          }
          _documents[docId] = record;

          // Fetch versions for this document
          final verSnap = await _firestore
              .collection('versions')
              .where('documentId', isEqualTo: docId)
              .get();
          if (verSnap.docs.isNotEmpty) {
            _versions[docId] = verSnap.docs
                .map((d) => DocumentVersion.fromFirestoreMap(d.data()))
                .toList();
          }
        }
      }

      await _persist();
    } catch (e) {
      AppLogger.warn(
        'PersistentDocumentRepository',
        'Failed to sync shared documents from Firestore: $e',
      );
    }
  }

  @override
  Future<List<DocumentRecord>> getDocuments({
    String? category,
    String? ownerUid,
    String? ownerEmail,
    bool includeArchived = false,
    bool includeDeleted = false,
  }) async {
    await _ensureLoaded();

    if (ownerUid != null && ownerUid.isNotEmpty && _canUseFirestore) {
      await _syncSharedFromFirestore(uid: ownerUid, email: ownerEmail);
    }

    final normalizedEmail = ownerEmail?.trim().toLowerCase();

    return _documents.values.where((doc) {
      if (!includeDeleted && doc.isDeleted) return false;
      if (!includeArchived && doc.isArchived) return false;
      if (category != null && category != 'All' && doc.category != category) {
        return false;
      }
      if (ownerUid != null && ownerUid.isNotEmpty) {
        if (doc.ownerUid != ownerUid) {
          final envelopes = _envelopes[doc.documentId] ?? [];
          final isShared = envelopes.any(
            (e) =>
                e.recipientId == ownerUid ||
                (normalizedEmail != null &&
                    normalizedEmail.isNotEmpty &&
                    e.recipientEmail?.trim().toLowerCase() == normalizedEmail),
          );
          if (!isShared) return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Future<DocumentRecord?> getDocumentById(String documentId) async {
    await _ensureLoaded();
    final local = _documents[documentId];
    if (local != null) return local;

    if (_canUseFirestore) {
      try {
        final docSnap =
            await _firestore.collection('documents').doc(documentId).get();
        if (docSnap.exists && docSnap.data() != null) {
          final record = DocumentRecord.fromFirestoreMap(docSnap.data()!);
          _documents[documentId] = record;
          await _persist();
          return record;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> saveDocument(DocumentRecord document) async {
    await _ensureLoaded();
    _documents[document.documentId] = document;
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('documents')
            .doc(document.documentId)
            .set(document.toFirestoreMap(), SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentDocumentRepository',
          'Failed to sync document metadata to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<void> saveVersion(DocumentVersion version) async {
    await _ensureLoaded();
    final list = _versions.putIfAbsent(version.documentId, () => []);
    list.removeWhere((v) => v.versionId == version.versionId);
    list.add(version);
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('versions')
            .doc(version.versionId)
            .set(version.toFirestoreMap(), SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentDocumentRepository',
          'Failed to sync document version to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<List<DocumentVersion>> getVersions(String documentId) async {
    await _ensureLoaded();
    var list = _versions[documentId] ?? [];
    if (list.isEmpty && _canUseFirestore) {
      try {
        final snap = await _firestore
            .collection('versions')
            .where('documentId', isEqualTo: documentId)
            .get();
        if (snap.docs.isNotEmpty) {
          list = snap.docs
              .map((d) => DocumentVersion.fromFirestoreMap(d.data()))
              .toList();
          _versions[documentId] = list;
          await _persist();
        }
      } catch (_) {}
    }
    list.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return List.unmodifiable(list);
  }

  @override
  Future<void> saveKeyEnvelope(KeyEnvelope envelope) async {
    await _ensureLoaded();
    final list = _envelopes.putIfAbsent(envelope.documentId, () => []);
    list.removeWhere(
      (e) =>
          e.envelopeId == envelope.envelopeId ||
          e.recipientId == envelope.recipientId ||
          (envelope.recipientEmail != null &&
              envelope.recipientEmail!.isNotEmpty &&
              e.recipientEmail?.toLowerCase() ==
                  envelope.recipientEmail!.toLowerCase()),
    );
    list.add(envelope);
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('key_envelopes')
            .doc(envelope.envelopeId)
            .set(envelope.toFirestoreMap(), SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentDocumentRepository',
          'Failed to sync key envelope to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<KeyEnvelope?> getKeyEnvelope({
    required String documentId,
    required String recipientId,
    String? recipientEmail,
  }) async {
    await _ensureLoaded();
    final list = _envelopes[documentId] ?? [];
    final normalizedEmail = recipientEmail?.trim().toLowerCase();

    // 1. Direct exact UID match
    for (final e in list) {
      if (e.recipientId == recipientId) {
        return e;
      }
    }

    // 2. Direct Email match
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      for (final e in list) {
        if (e.recipientEmail?.trim().toLowerCase() == normalizedEmail) {
          return e;
        }
      }
    }

    // 3. Normalized email/Google UID match
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
          recipientEmail: e.recipientEmail ?? normalizedEmail,
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

    // 4. Legacy demo/test account healing (uid-test-familyvault-app / guest-uid)
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
        recipientEmail: normalizedEmail,
        wrappedDek: legacyEnv.wrappedDek,
        wrappingAlgorithm: legacyEnv.wrappingAlgorithm,
        keyEpoch: legacyEnv.keyEpoch,
        createdAt: legacyEnv.createdAt,
      );
      list.add(healedEnv);

      final doc = _documents[documentId];
      if (doc != null &&
          (doc.ownerUid == 'uid-test-familyvault-app' ||
              doc.ownerUid == 'guest-uid')) {
        _documents[documentId] = doc.copyWith(ownerUid: recipientId);
      }

      await _persist();
      return healedEnv;
    }

    // 5. Document-owner fallback
    final doc = _documents[documentId];
    if (doc != null && doc.ownerUid == recipientId && list.isNotEmpty) {
      final existingEnv = list.first;
      final healedEnv = KeyEnvelope(
        schemaVersion: existingEnv.schemaVersion,
        envelopeId: existingEnv.envelopeId,
        documentId: existingEnv.documentId,
        recipientType: existingEnv.recipientType,
        recipientId: recipientId,
        recipientEmail: normalizedEmail,
        wrappedDek: existingEnv.wrappedDek,
        wrappingAlgorithm: existingEnv.wrappingAlgorithm,
        keyEpoch: existingEnv.keyEpoch,
        createdAt: existingEnv.createdAt,
      );
      list.add(healedEnv);
      await _persist();
      return healedEnv;
    }

    // 6. Firestore lookup fallback for cross-device recipients
    if (_canUseFirestore) {
      try {
        final snap = await _firestore
            .collection('key_envelopes')
            .where('documentId', isEqualTo: documentId)
            .get();
        for (final docSnap in snap.docs) {
          final env = KeyEnvelope.fromFirestoreMap(docSnap.data());
          if (env.recipientId == recipientId ||
              (normalizedEmail != null &&
                  normalizedEmail.isNotEmpty &&
                  env.recipientEmail?.trim().toLowerCase() ==
                      normalizedEmail)) {
            _envelopes.putIfAbsent(documentId, () => []).add(env);
            await _persist();
            return env;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<List<KeyEnvelope>> getKeyEnvelopes(String documentId) async {
    await _ensureLoaded();
    if (_canUseFirestore) {
      try {
        final snap = await _firestore
            .collection('key_envelopes')
            .where('documentId', isEqualTo: documentId)
            .get();
        if (snap.docs.isNotEmpty) {
          final remoteList = snap.docs
              .map((d) => KeyEnvelope.fromFirestoreMap(d.data()))
              .toList();
          final local = _envelopes.putIfAbsent(documentId, () => []);
          for (final env in remoteList) {
            if (!local.any((e) => e.envelopeId == env.envelopeId)) {
              local.add(env);
            }
          }
          await _persist();
        }
      } catch (_) {}
    }
    return List.unmodifiable(_envelopes[documentId] ?? []);
  }

  @override
  Future<void> deleteKeyEnvelope({
    required String documentId,
    required String recipientId,
    String? recipientEmail,
  }) async {
    await _ensureLoaded();
    final normalizedEmail = recipientEmail?.trim().toLowerCase();
    final list = _envelopes[documentId];
    final toDeleteIds = <String>[];

    if (list != null) {
      for (final e in list) {
        if (e.recipientId == recipientId ||
            (normalizedEmail != null &&
                normalizedEmail.isNotEmpty &&
                e.recipientEmail?.trim().toLowerCase() == normalizedEmail)) {
          toDeleteIds.add(e.envelopeId);
        }
      }
      list.removeWhere((e) => toDeleteIds.contains(e.envelopeId));
      await _persist();
    }

    if (_canUseFirestore) {
      try {
        for (final envId in toDeleteIds) {
          await _firestore.collection('key_envelopes').doc(envId).delete();
        }
        final snap = await _firestore
            .collection('key_envelopes')
            .where('documentId', isEqualTo: documentId)
            .get();
        for (final docSnap in snap.docs) {
          final env = KeyEnvelope.fromFirestoreMap(docSnap.data());
          if (env.recipientId == recipientId ||
              (normalizedEmail != null &&
                  normalizedEmail.isNotEmpty &&
                  env.recipientEmail?.trim().toLowerCase() ==
                      normalizedEmail)) {
            await docSnap.reference.delete();
          }
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentDocumentRepository',
          'Failed to delete key envelope from Firestore: $e',
        );
      }
    }
  }

  @override
  Future<void> softDeleteDocument(String documentId) async {
    await _ensureLoaded();
    final doc = _documents[documentId];
    if (doc != null) {
      final updated = doc.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now().toUtc(),
      );
      _documents[documentId] = updated;
      await _persist();

      if (_canUseFirestore) {
        try {
          await _firestore
              .collection('documents')
              .doc(documentId)
              .set(updated.toFirestoreMap(), SetOptions(merge: true));
        } catch (_) {}
      }
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

    if (_canUseFirestore) {
      try {
        await _firestore.collection('documents').doc(documentId).delete();
      } catch (_) {}
    }
  }
}
