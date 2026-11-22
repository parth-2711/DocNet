import '../../domain/entities/document_permission.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/entities/family_space.dart';
import '../../domain/repositories/family_repository.dart';

/// In-memory implementation of FamilyRepository for development, tests, and offline execution.
class InMemoryFamilyRepository implements FamilyRepository {
  final Map<String, FamilySpace> _families = {};
  final Map<String, List<FamilyMember>> _members = {};
  final Map<String, List<DocumentPermission>> _permissions = {};

  @override
  Future<FamilySpace?> getFamily(String familyId) async {
    return _families[familyId];
  }

  @override
  Future<FamilySpace?> getUserFamily(String uid) async {
    for (var familyId in _members.keys) {
      final members = _members[familyId] ?? [];
      if (members.any((m) => m.uid == uid && m.status == 'active')) {
        return _families[familyId];
      }
    }
    return null;
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
    list.removeWhere((p) => p.granteeId == permission.granteeId);
    list.add(permission);
  }

  @override
  Future<List<DocumentPermission>> getPermissions(String documentId) async {
    return List.unmodifiable(_permissions[documentId] ?? []);
  }

  @override
  Future<DocumentPermission?> getPermission({
    required String documentId,
    required String granteeId,
  }) async {
    final list = _permissions[documentId] ?? [];
    try {
      return list.firstWhere((p) => p.granteeId == granteeId);
    } catch (_) {
      return null;
    }
  }
}
