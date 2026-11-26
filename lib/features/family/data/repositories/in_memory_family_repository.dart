import '../../domain/entities/document_permission.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/entities/family_space.dart';
import '../../domain/repositories/family_repository.dart';

/// In-memory implementation of FamilyRepository for development, tests, and offline execution.
class InMemoryFamilyRepository implements FamilyRepository {
  final Map<String, FamilySpace> _families = {};
  final Map<String, List<FamilyMember>> _members = {};
  final Map<String, List<DocumentPermission>> _permissions = {};
  final Map<String, String> _activeSpaceByUid = {};

  @override
  Future<FamilySpace?> getFamily(String familyId) async {
    return _families[familyId];
  }

  @override
  Future<FamilySpace?> getUserFamily(String uid) async {
    final activeId = _activeSpaceByUid[uid];
    if (activeId != null && _families.containsKey(activeId)) {
      final members = _members[activeId] ?? [];
      if (_families[activeId]!.ownerUid == uid ||
          members.any((m) => m.uid == uid && m.status == 'active')) {
        return _families[activeId];
      }
    }
    for (var familyId in _members.keys) {
      final members = _members[familyId] ?? [];
      if (members.any((m) => m.uid == uid && m.status == 'active')) {
        return _families[familyId];
      }
    }
    for (final fam in _families.values) {
      if (fam.ownerUid == uid) return fam;
    }
    return null;
  }

  @override
  Future<List<FamilySpace>> getUserFamilies(String uid) async {
    final results = <String, FamilySpace>{};
    for (final fam in _families.values) {
      if (fam.ownerUid == uid) {
        results[fam.familyId] = fam;
      }
    }
    for (final entry in _members.entries) {
      if (entry.value.any((m) => m.uid == uid && m.status == 'active')) {
        final fam = _families[entry.key];
        if (fam != null) results[fam.familyId] = fam;
      }
    }
    return results.values.toList();
  }

  @override
  Future<void> setActiveFamily({
    required String uid,
    required String familyId,
  }) async {
    _activeSpaceByUid[uid] = familyId;
  }

  @override
  Future<void> saveFamily(FamilySpace family) async {
    _families[family.familyId] = family;
  }

  @override
  Future<List<FamilyMember>> getMembers(String familyId) async {
    final list = _members[familyId] ?? [];
    return List.unmodifiable(list.where((m) => m.status == 'active'));
  }

  @override
  Future<void> addMember(FamilyMember member) async {
    final list = _members.putIfAbsent(member.familyId, () => []);
    list.removeWhere((m) => m.uid == member.uid);
    list.add(member);

    final family = _families[member.familyId];
    if (family != null) {
      _families[member.familyId] = family.copyWith(
        memberCount: list.where((m) => m.status == 'active').length,
      );
    }
  }

  @override
  Future<void> removeFamily(String familyId) async {
    _families.remove(familyId);
    _members.remove(familyId);
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String uid,
  }) async {
    final list = _members[familyId];
    if (list != null) {
      list.removeWhere((m) => m.uid == uid);
      final family = _families[familyId];
      if (family != null) {
        _families[familyId] = family.copyWith(memberCount: list.length);
      }
    }
  }

  @override
  Future<void> savePermission(DocumentPermission permission) async {
    final list = _permissions.putIfAbsent(permission.documentId, () => []);
    list.removeWhere((p) => p.matchesUser(uid: permission.granteeId, email: permission.granteeEmail));
    list.add(permission);
  }

  @override
  Future<List<DocumentPermission>> getPermissions(String documentId) async {
    return List.unmodifiable(_permissions[documentId] ?? []);
  }

  @override
  Future<List<DocumentPermission>> getPermissionsForUser({
    required String uid,
    String? email,
  }) async {
    final results = <DocumentPermission>[];
    for (final list in _permissions.values) {
      for (final p in list) {
        if (p.matchesUser(uid: uid, email: email) && !p.isExpired) {
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
    final list = _permissions[documentId] ?? [];
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
    final list = _permissions[documentId];
    if (list == null) return;
    list.removeWhere(
      (p) => p.matchesUser(uid: granteeId, email: granteeEmail),
    );
  }
}
