import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_repository.dart';
import 'package:docnet/features/family/domain/entities/family_member.dart';
import 'package:docnet/features/family/domain/usecases/create_family_usecase.dart';
import 'package:docnet/features/family/presentation/controllers/family_controller.dart';

void main() {
  late InMemoryFamilyRepository familyRepo;
  late CreateFamilyUseCase createFamilyUseCase;
  late FamilyController controller;

  setUp(() {
    familyRepo = InMemoryFamilyRepository();
    createFamilyUseCase = CreateFamilyUseCase(familyRepository: familyRepo);
    controller = FamilyController(
      familyRepo: familyRepo,
      createFamilyUseCase: createFamilyUseCase,
      currentUserUid: 'uid-user-1',
      currentDisplayName: 'User One',
      currentUserEmail: 'user1@example.com',
    );
  });

  group('FamilyController Tests', () {
    test('Initial state has no family', () {
      expect(controller.state.family, isNull);
      expect(controller.state.members, isEmpty);
    });

    test('Creates family space and designates creator as owner', () async {
      await controller.createFamily('Test Family');

      expect(controller.state.family, isNotNull);
      expect(controller.state.family!.name, equals('Test Family'));
      expect(controller.state.members.length, equals(1));
      expect(controller.state.members.first.role, equals(FamilyRole.owner));
    });

    test('Invites member and updates member count', () async {
      await controller.createFamily('Test Family');

      await controller.inviteMember(
        email: 'member@example.com',
        displayName: 'Invited Member',
        role: FamilyRole.member,
      );

      expect(controller.state.members.length, equals(2));
      expect(
        controller.state.members.any((m) => m.displayName == 'Invited Member'),
        isTrue,
      );
    });

    test('Removes member and refreshes member list (FAM-008)', () async {
      await controller.createFamily('Test Family');

      await controller.inviteMember(
        email: 'temp@example.com',
        displayName: 'Temporary Member',
        role: FamilyRole.viewer,
      );
      expect(controller.state.members.length, equals(2));

      final tempMember = controller.state.members.firstWhere(
        (m) => m.displayName == 'Temporary Member',
      );
      await controller.removeMember(tempMember.uid);

      expect(controller.state.members.length, equals(1));
      expect(
        controller.state.members.any(
          (m) => m.displayName == 'Temporary Member',
        ),
        isFalse,
      );
    });
  });
}
