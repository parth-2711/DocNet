import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:docnet/core/logging/app_logger.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/document_permission.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/entities/family_space.dart';
import '../../domain/repositories/family_repository.dart';

/// Persistent implementation of FamilyRepository preserving shared spaces,
/// members, multi-space switching, and per-document sharing permissions across
/// app restarts and multiple devices.
class PersistentFamilyRepository implements FamilyRepository {
  final LocalVaultStorageService storageService;

  final Map<String, FamilySpace> _families = {};
  final Map<String, List<FamilyMember>> _members = {};
  final Map<String, List<DocumentPermission>> _permissions = {};
  final Map<String, String> _activeSpaces = {};
  bool _loaded = false;

  PersistentFamilyRepository(this.storageService);

  static bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canUseFirestore => Firebase.apps.isNotEmpty && !_isTestEnvironment;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('families');
      if (data is Map<String, dynamic>) {
        if (data['families'] is List) {
          for (final item in data['families']) {
            if (item is Map<String, dynamic>) {
              final fam = FamilySpace.fromMap(item);
              _families[fam.familyId] = fam;
            }
          }
        }

        if (data['members'] is Map<String, dynamic>) {
          final membersMap = data['members'] as Map<String, dynamic>;
          membersMap.forEach((famId, list) {
            if (list is List) {
              _members[famId] = list
                  .whereType<Map<String, dynamic>>()
                  .map((m) => FamilyMember.fromMap(m))
                  .toList();
            }
          });
        }

        if (data['permissions'] is Map<String, dynamic>) {
          final permsMap = data['permissions'] as Map<String, dynamic>;
          permsMap.forEach((docId, list) {
            if (list is List) {
              _permissions[docId] = list
                  .whereType<Map<String, dynamic>>()
                  .map((m) => DocumentPermission.fromMap(m))
                  .toList();
            }
          });
        }

        if (data['activeSpaces'] is Map<String, dynamic>) {
          final activeMap = data['activeSpaces'] as Map<String, dynamic>;
          activeMap.forEach((uid, famId) {
            if (famId is String) {
              _activeSpaces[uid] = famId;
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
    final familiesList = _families.values.map((f) => f.toMap()).toList();

    final membersMap = <String, dynamic>{};
    _members.forEach((famId, list) {
      membersMap[famId] = list.map((m) => m.toMap()).toList();
    });

    final permissionsMap = <String, dynamic>{};
    _permissions.forEach((docId, list) {
      permissionsMap[docId] = list.map((p) => p.toMap()).toList();
    });

    await storageService.saveJson('families', {
      'families': familiesList,
      'members': membersMap,
      'permissions': permissionsMap,
      'activeSpaces': _activeSpaces,
    });
  }

  @override
  Future<FamilySpace?> getFamily(String familyId) async {
    await _ensureLoaded();
    final local = _families[familyId];
    if (local != null) return local;

    if (_canUseFirestore) {
      try {
        final doc =
            await _firestore.collection('families').doc(familyId).get();
        if (doc.exists && doc.data() != null) {
          final fam = FamilySpace.fromMap(doc.data()!);
          _families[fam.familyId] = fam;
          await _persist();
          return fam;
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to fetch space from Firestore: $e',
        );
      }
    }
    return null;
  }

  @override
  Future<List<FamilySpace>> getUserFamilies(String uid) async {
    await _ensureLoaded();
    final resultMap = <String, FamilySpace>{};

    if (_canUseFirestore) {
      try {
        // 1. All spaces owned by user
        final ownerSnap = await _firestore
            .collection('families')
            .where('ownerUid', isEqualTo: uid)
            .get();
        for (final doc in ownerSnap.docs) {
          final fam = FamilySpace.fromMap(doc.data());
          _families[fam.familyId] = fam;
          resultMap[fam.familyId] = fam;
        }

        // 2. All spaces recorded in users/{uid}.spaceIds / activeFamilyId
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          final candidateIds = <String>{};
          if (data['activeFamilyId'] is String &&
              (data['activeFamilyId'] as String).isNotEmpty) {
            candidateIds.add(data['activeFamilyId'] as String);
          }
          if (data['spaceIds'] is List) {
            for (final id in data['spaceIds']) {
              if (id is String && id.isNotEmpty) {
                candidateIds.add(id);
              }
            }
          }

          final invalidIds = <String>[];
          for (final spaceId in candidateIds) {
            if (resultMap.containsKey(spaceId)) continue;
            final memberDoc = await _firestore
                .collection('families')
                .doc(spaceId)
                .collection('members')
                .doc(uid)
                .get();
            if (memberDoc.exists && memberDoc.data()?['status'] == 'active') {
              final fam = await getFamily(spaceId);
              if (fam != null) {
                resultMap[fam.familyId] = fam;
              }
            } else {
              invalidIds.add(spaceId);
            }
          }

          if (invalidIds.isNotEmpty) {
            for (final badId in invalidIds) {
              _members[badId]?.removeWhere((m) => m.uid == uid);
              _families.remove(badId);
              if (_activeSpaces[uid] == badId) {
                _activeSpaces.remove(uid);
              }
            }
            await _firestore.collection('users').doc(uid).set({
              'spaceIds': FieldValue.arrayRemove(invalidIds),
              if (invalidIds.contains(data['activeFamilyId']))
                'activeFamilyId':
                    resultMap.isNotEmpty ? resultMap.keys.first : null,
            }, SetOptions(merge: true));
            await _persist();
          }
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Error loading user spaces from Firestore: $e',
        );
      }
    }

    // Merge local spaces
    for (final fam in _families.values) {
      if (fam.ownerUid == uid) {
        resultMap.putIfAbsent(fam.familyId, () => fam);
      }
    }
    for (final entry in _members.entries) {
      if (entry.value.any((m) => m.uid == uid && m.status == 'active')) {
        final fam = _families[entry.key];
        if (fam != null) {
          resultMap.putIfAbsent(fam.familyId, () => fam);
        }
      }
    }

    final list = resultMap.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> setActiveFamily({
    required String uid,
    required String familyId,
  }) async {
    await _ensureLoaded();
    _activeSpaces[uid] = familyId;
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'activeFamilyId': familyId,
          'spaceIds': FieldValue.arrayUnion([familyId]),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<FamilySpace?> getUserFamily(String uid) async {
    await _ensureLoaded();
    final spaces = await getUserFamilies(uid);
    if (spaces.isEmpty) return null;

    // 1. Check local active preference
    final localActive = _activeSpaces[uid];
    if (localActive != null) {
      final match = spaces.where((s) => s.familyId == localActive).toList();
      if (match.isNotEmpty) return match.first;
    }

    // 2. Check Firestore active preference
    if (_canUseFirestore) {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final activeId = userDoc.data()?['activeFamilyId'] as String?;
        if (activeId != null) {
          final match = spaces.where((s) => s.familyId == activeId).toList();
          if (match.isNotEmpty) {
            _activeSpaces[uid] = activeId;
            await _persist();
            return match.first;
          }
        }
      } catch (_) {}
    }

    return spaces.first;
  }

  @override
  Future<void> saveFamily(FamilySpace family) async {
    await _ensureLoaded();
    _families[family.familyId] = family;
    _activeSpaces[family.ownerUid] = family.familyId;
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('families')
            .doc(family.familyId)
            .set(family.toMap(), SetOptions(merge: true));
        await _firestore.collection('users').doc(family.ownerUid).set({
          'activeFamilyId': family.familyId,
          'spaceIds': FieldValue.arrayUnion([family.familyId]),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to save space to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<List<FamilyMember>> getMembers(String familyId) async {
    await _ensureLoaded();

    if (_canUseFirestore) {
      try {
        final snap = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get();
        if (snap.docs.isNotEmpty) {
          final list = snap.docs
              .map((d) => FamilyMember.fromMap(d.data()))
              .toList();

          final fam = _families[familyId];
          if (fam != null && !list.any((m) => m.uid == fam.ownerUid)) {
            final localOwner = (_members[familyId] ?? []).firstWhere(
              (m) => m.uid == fam.ownerUid,
              orElse: () => FamilyMember(
                uid: fam.ownerUid,
                familyId: fam.familyId,
                displayName: 'Space Owner',
                email: '',
                role: FamilyRole.owner,
                joinedAt: fam.createdAt,
              ),
            );
            list.insert(0, localOwner);
            _firestore
                .collection('families')
                .doc(familyId)
                .collection('members')
                .doc(fam.ownerUid)
                .set(localOwner.toMap(), SetOptions(merge: true))
                .catchError((_) {});
          }

          _members[familyId] = list;
          await _persist();
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to fetch members from Firestore: $e',
        );
      }
    }

    return List.unmodifiable(_members[familyId] ?? []);
  }

  @override
  Future<void> removeFamily(String familyId) async {
    await _ensureLoaded();
    _families.remove(familyId);
    _members.remove(familyId);
    _activeSpaces.removeWhere((_, v) => v == familyId);
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore.collection('families').doc(familyId).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> addMember(FamilyMember member) async {
    await _ensureLoaded();
    final list = _members.putIfAbsent(member.familyId, () => []);
    list.removeWhere((m) => m.uid == member.uid);
    list.add(member);
    _activeSpaces[member.uid] = member.familyId;

    final family = _families[member.familyId];
    if (family != null) {
      _families[member.familyId] = family.copyWith(
        memberCount: list.length,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('families')
            .doc(member.familyId)
            .collection('members')
            .doc(member.uid)
            .set(member.toMap(), SetOptions(merge: true));

        await _firestore.collection('families').doc(member.familyId).update({
          'memberCount': list.length,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });

        await _firestore.collection('users').doc(member.uid).set({
          'activeFamilyId': member.familyId,
          'spaceIds': FieldValue.arrayUnion([member.familyId]),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to sync member to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String uid,
  }) async {
    await _ensureLoaded();
    final list = _members[familyId];
    if (list != null) {
      list.removeWhere((m) => m.uid == uid);
      final family = _families[familyId];
      if (family != null) {
        _families[familyId] = family.copyWith(
          memberCount: list.length,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      if (_activeSpaces[uid] == familyId) {
        _activeSpaces.remove(uid);
      }
      await _persist();
    }

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('families')
            .doc(familyId)
            .collection('members')
            .doc(uid)
            .delete();

        await _firestore.collection('families').doc(familyId).update({
          'memberCount': list?.length ?? 0,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });

        await _firestore.collection('users').doc(uid).set({
          'activeFamilyId': null,
          'spaceIds': FieldValue.arrayRemove([familyId]),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to remove member from Firestore: $e',
        );
      }
    }
  }

  @override
  Future<void> savePermission(DocumentPermission permission) async {
    await _ensureLoaded();
    final list = _permissions.putIfAbsent(permission.documentId, () => []);
    list.removeWhere(
      (p) => p.matchesUser(
        uid: permission.granteeId,
        email: permission.granteeEmail,
      ),
    );
    list.add(permission);
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('document_permissions')
            .doc(permission.permissionId)
            .set(permission.toMap(), SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to sync document permission to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<List<DocumentPermission>> getPermissions(String documentId) async {
    await _ensureLoaded();
    if (_canUseFirestore) {
      try {
        final snap = await _firestore
            .collection('document_permissions')
            .where('documentId', isEqualTo: documentId)
            .get();
        final list = snap.docs
            .map((d) => DocumentPermission.fromMap(d.data()))
            .toList();
        _permissions[documentId] = list;
        await _persist();
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to fetch permissions from Firestore: $e',
        );
      }
    }
    return List.unmodifiable(_permissions[documentId] ?? []);
  }

  @override
  Future<List<DocumentPermission>> getPermissionsForUser({
    required String uid,
    String? email,
  }) async {
    await _ensureLoaded();
    final normalizedEmail = email?.trim().toLowerCase();

    if (_canUseFirestore) {
      try {
        final uidSnap = await _firestore
            .collection('document_permissions')
            .where('granteeId', isEqualTo: uid)
            .get();
        for (final doc in uidSnap.docs) {
          final perm = DocumentPermission.fromMap(doc.data());
          final list = _permissions.putIfAbsent(perm.documentId, () => []);
          list.removeWhere((p) => p.permissionId == perm.permissionId);
          list.add(perm);
        }

        if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
          final emailSnap = await _firestore
              .collection('document_permissions')
              .where('granteeEmail', isEqualTo: normalizedEmail)
              .get();
          for (final doc in emailSnap.docs) {
            final perm = DocumentPermission.fromMap(doc.data());
            final list = _permissions.putIfAbsent(perm.documentId, () => []);
            list.removeWhere((p) => p.permissionId == perm.permissionId);
            list.add(perm);
          }
        }
        await _persist();
      } catch (_) {}
    }

    final results = <DocumentPermission>[];
    for (final list in _permissions.values) {
      for (final p in list) {
        if (p.matchesUser(uid: uid, email: normalizedEmail) && !p.isExpired) {
          results.add(p);
        }
      }
    }
    return results;
  }

  @override
  Future<DocumentPermission?> getPermission({
    required String documentId,
    required String granteeId,
    String? granteeEmail,
  }) async {
    final list = await getPermissions(documentId);
    try {
      return list.firstWhere(
        (p) => p.matchesUser(uid: granteeId, email: granteeEmail),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> revokePermission({
    required String documentId,
    required String granteeId,
    String? granteeEmail,
  }) async {
    await _ensureLoaded();
    final normalizedEmail = granteeEmail?.trim().toLowerCase();
    final list = _permissions[documentId];
    final toDeleteIds = <String>[];

    if (list != null) {
      for (final p in list) {
        if (p.matchesUser(uid: granteeId, email: normalizedEmail)) {
          toDeleteIds.add(p.permissionId);
        }
      }
      list.removeWhere((p) => toDeleteIds.contains(p.permissionId));
      await _persist();
    }

    if (_canUseFirestore) {
      try {
        for (final permId in toDeleteIds) {
          await _firestore
              .collection('document_permissions')
              .doc(permId)
              .delete();
        }
        final snap = await _firestore
            .collection('document_permissions')
            .where('documentId', isEqualTo: documentId)
            .get();
        for (final doc in snap.docs) {
          final perm = DocumentPermission.fromMap(doc.data());
          if (perm.matchesUser(uid: granteeId, email: normalizedEmail)) {
            await doc.reference.delete();
          }
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to revoke permission from Firestore: $e',
        );
      }
    }
  }
}
