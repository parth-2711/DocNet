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

/// Persistent implementation of FamilyRepository preserving family spaces,
/// members, and sharing permissions across app restarts and multiple devices.
class PersistentFamilyRepository implements FamilyRepository {
  final LocalVaultStorageService storageService;

  final Map<String, FamilySpace> _families = {};
  final Map<String, List<FamilyMember>> _members = {};
  final Map<String, List<DocumentPermission>> _permissions = {};
  bool _loaded = false;

  PersistentFamilyRepository(this.storageService);

  static bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canUseFirestore =>
      Firebase.apps.isNotEmpty && !_isTestEnvironment;

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
          'Failed to fetch family from Firestore: $e',
        );
      }
    }
    return null;
  }

  @override
  Future<FamilySpace?> getUserFamily(String uid) async {
    await _ensureLoaded();

    // 1. Check if user has an activeFamilyId recorded in Firestore
    if (_canUseFirestore) {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data()?['activeFamilyId'] != null) {
          final activeFamilyId = userDoc.data()!['activeFamilyId'] as String;
          final fam = await getFamily(activeFamilyId);
          if (fam != null) return fam;
        }
      } catch (_) {}
    }

    // 2. Check if user is a member of any local family
    for (final entry in _members.entries) {
      if (entry.value.any((m) => m.uid == uid)) {
        return _families[entry.key];
      }
    }

    // 3. Check if user is owner of a local family
    for (final fam in _families.values) {
      if (fam.ownerUid == uid) return fam;
    }

    // 4. Check if owner of any family in Firestore
    if (_canUseFirestore) {
      try {
        final ownerSnap = await _firestore
            .collection('families')
            .where('ownerUid', isEqualTo: uid)
            .limit(1)
            .get();
        if (ownerSnap.docs.isNotEmpty) {
          final fam = FamilySpace.fromMap(ownerSnap.docs.first.data());
          _families[fam.familyId] = fam;
          await _persist();
          return fam;
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<void> saveFamily(FamilySpace family) async {
    await _ensureLoaded();
    _families[family.familyId] = family;
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('families')
            .doc(family.familyId)
            .set(family.toMap(), SetOptions(merge: true));
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyRepository',
          'Failed to save family to Firestore: $e',
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
  Future<void> addMember(FamilyMember member) async {
    await _ensureLoaded();
    final list = _members.putIfAbsent(member.familyId, () => []);
    list.removeWhere((m) => m.uid == member.uid);
    list.add(member);

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
    list.removeWhere((p) => p.granteeId == permission.granteeId);
    list.add(permission);
    await _persist();
  }

  @override
  Future<List<DocumentPermission>> getPermissions(String documentId) async {
    await _ensureLoaded();
    return List.unmodifiable(_permissions[documentId] ?? []);
  }

  @override
  Future<DocumentPermission?> getPermission({
    required String documentId,
    required String granteeId,
  }) async {
    await _ensureLoaded();
    final list = _permissions[documentId] ?? [];
    try {
      return list.firstWhere((p) => p.granteeId == granteeId);
    } catch (_) {
      return null;
    }
  }
}
