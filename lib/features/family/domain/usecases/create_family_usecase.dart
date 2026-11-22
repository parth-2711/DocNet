import 'package:uuid/uuid.dart';
import '../entities/family_member.dart';
import '../entities/family_space.dart';
import '../repositories/family_repository.dart';

/// Use case for creating a family space and designating the creator as Owner (FAM-001, FAM-007).
class CreateFamilyUseCase {
  final FamilyRepository familyRepository;
  final Uuid uuid;

  CreateFamilyUseCase({
    required this.familyRepository,
    this.uuid = const Uuid(),
  });

  Future<FamilySpace> execute({
    required String familyName,
    required String ownerUid,
    required String ownerDisplayName,
    required String ownerEmail,
  }) async {
    final trimmedName = familyName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Family name cannot be empty');
    }

    final familyId = uuid.v4();
    final now = DateTime.now().toUtc();

    final family = FamilySpace(
      familyId: familyId,
      name: trimmedName,
      ownerUid: ownerUid,
      createdAt: now,
      updatedAt: now,
      memberCount: 1,
    );

    final ownerMember = FamilyMember(
      uid: ownerUid,
      familyId: familyId,
      displayName: ownerDisplayName,
      email: ownerEmail,
      role: FamilyRole.owner,
      joinedAt: now,
    );

    await familyRepository.saveFamily(family);
    await familyRepository.addMember(ownerMember);

    return family;
  }
}
