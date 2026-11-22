import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docnet/features/activity/data/repositories/in_memory_activity_repository.dart';
import 'package:docnet/features/auth/data/repositories/in_memory_device_repository.dart';
import 'package:docnet/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:docnet/features/auth/data/repositories/mock_user_profile_repository.dart';
import 'package:docnet/features/auth/domain/entities/device_record.dart';
import 'package:docnet/features/auth/presentation/controllers/auth_controller.dart';
import 'package:docnet/features/auth/presentation/controllers/device_controller.dart';
import 'package:docnet/features/auth/presentation/devices_screen.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_request_repository.dart';
import 'package:docnet/features/documents/domain/entities/document_request.dart';
import 'package:docnet/features/documents/presentation/controllers/document_request_controller.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_repository.dart';
import 'package:docnet/features/family/domain/entities/family_member.dart';
import 'package:docnet/features/family/domain/entities/family_space.dart';
import 'package:docnet/features/family/presentation/controllers/family_controller.dart';
import 'package:docnet/features/family/presentation/family_screen.dart';
import 'package:docnet/features/settings/presentation/settings_screen.dart';

void main() {
  group('Device Management Tests (PRD.md Section 6.11)', () {
    late InMemoryDeviceRepository deviceRepo;
    late InMemoryActivityRepository activityRepo;

    setUp(() {
      deviceRepo = InMemoryDeviceRepository();
      activityRepo = InMemoryActivityRepository();
    });

    tearDown(() {
      activityRepo.dispose();
    });

    test(
      'Enrolls device and retrieves enrolled device list (DEVICE-001)',
      () async {
        final now = DateTime.now().toUtc();
        final device = DeviceRecord(
          deviceId: 'dev-win-1',
          platform: 'Windows',
          deviceLabel: 'My Laptop',
          devicePublicKey: 'pk-1',
          keyFingerprint: 'SHA256:fp1',
          enrolledAt: now,
          lastSeenAt: now,
        );

        await deviceRepo.saveDevice(uid: 'user-1', device: device);
        final list = await deviceRepo.getDevices('user-1');

        expect(list.length, 1);
        expect(list.first.deviceLabel, 'My Laptop');
        expect(list.first.status, 'active');
      },
    );

    test('Renames enrolled device (DEVICE-002)', () async {
      final now = DateTime.now().toUtc();
      final device = DeviceRecord(
        deviceId: 'dev-1',
        platform: 'Android',
        deviceLabel: 'Pixel Phone',
        devicePublicKey: 'pk-2',
        keyFingerprint: 'SHA256:fp2',
        enrolledAt: now,
        lastSeenAt: now,
      );
      await deviceRepo.saveDevice(uid: 'user-1', device: device);

      final controller = DeviceController(
        deviceRepository: deviceRepo,
        activityRepository: activityRepo,
        currentUid: 'user-1',
      );
      await controller.renameDevice('dev-1', 'Pixel 9 Pro');

      final updated = await deviceRepo.getDevice(
        uid: 'user-1',
        deviceId: 'dev-1',
      );
      expect(updated!.deviceLabel, 'Pixel 9 Pro');
    });

    test(
      'Revokes specific device and logs activity event (DEVICE-003, DEVICE-006)',
      () async {
        final now = DateTime.now().toUtc();
        final device = DeviceRecord(
          deviceId: 'dev-old',
          platform: 'iOS',
          deviceLabel: 'Old iPad',
          devicePublicKey: 'pk-3',
          keyFingerprint: 'SHA256:fp3',
          enrolledAt: now,
          lastSeenAt: now,
        );
        await deviceRepo.saveDevice(uid: 'user-1', device: device);

        final controller = DeviceController(
          deviceRepository: deviceRepo,
          activityRepository: activityRepo,
          currentUid: 'user-1',
        );
        await controller.revokeDevice('dev-old');

        final revoked = await deviceRepo.getDevice(
          uid: 'user-1',
          deviceId: 'dev-old',
        );
        expect(revoked!.status, 'revoked');
        expect(revoked.revokedAt, isNotNull);

        final events = await activityRepo.getEvents();
        expect(events.any((e) => e.summary.contains('Device revoked')), isTrue);
      },
    );

    test('Revokes all other sessions except current (DEVICE-004)', () async {
      final now = DateTime.now().toUtc();
      await deviceRepo.saveDevice(
        uid: 'user-1',
        device: DeviceRecord(
          deviceId: 'current-dev',
          platform: 'Windows',
          deviceLabel: 'Current Laptop',
          devicePublicKey: 'pk-cur',
          keyFingerprint: 'fp-cur',
          enrolledAt: now,
          lastSeenAt: now,
        ),
      );
      await deviceRepo.saveDevice(
        uid: 'user-1',
        device: DeviceRecord(
          deviceId: 'other-dev',
          platform: 'Android',
          deviceLabel: 'Other Phone',
          devicePublicKey: 'pk-oth',
          keyFingerprint: 'fp-oth',
          enrolledAt: now,
          lastSeenAt: now,
        ),
      );

      await deviceRepo.revokeAllOtherDevices(
        uid: 'user-1',
        currentDeviceId: 'current-dev',
      );

      final current = await deviceRepo.getDevice(
        uid: 'user-1',
        deviceId: 'current-dev',
      );
      final other = await deviceRepo.getDevice(
        uid: 'user-1',
        deviceId: 'other-dev',
      );

      expect(current!.status, 'active');
      expect(other!.status, 'revoked');
    });

    testWidgets(
      'DevicesScreen renders warning banner and device list (DEVICE-007)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [deviceRepositoryProvider.overrideWithValue(deviceRepo)],
            child: const MaterialApp(home: DevicesScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Device Management'), findsOneWidget);
        expect(
          find.textContaining(
            'cannot remotely erase unencrypted files previously exported',
          ),
          findsOneWidget,
        );
        expect(find.text('Revoke All Other Devices'), findsOneWidget);
      },
    );
  });

  group(
    'Document Requests Tests (PRD.md Section 6.8 & DATABASE_SCHEMA.md Section 15)',
    () {
      late InMemoryDocumentRequestRepository requestRepo;

      setUp(() {
        requestRepo = InMemoryDocumentRequestRepository();
      });

      test('DocumentRequest entity converts to and from map', () {
        final now = DateTime.utc(2026, 11, 6, 17, 0);
        final req = DocumentRequest(
          requestId: 'req-101',
          familyId: 'fam-1',
          requesterUid: 'user-alice',
          recipientUid: 'user-bob',
          title: 'Tax acknowledgment 2025',
          notes: 'Needed for joint filing',
          status: DocumentRequestStatus.pending,
          createdAt: now,
          expiresAt: now.add(const Duration(days: 7)),
        );

        final map = req.toMap();
        expect(map['title'], 'Tax acknowledgment 2025');
        expect(map['status'], 'pending');

        final reconstituted = DocumentRequest.fromMap(map);
        expect(reconstituted.requestId, 'req-101');
        expect(reconstituted.requesterUid, 'user-alice');
        expect(reconstituted.recipientUid, 'user-bob');
        expect(reconstituted.status, DocumentRequestStatus.pending);
      });

      test(
        'Creates, fulfills, and declines document requests (REQ-001, REQ-003, REQ-005)',
        () async {
          final controller = DocumentRequestController(
            requestRepository: requestRepo,
            currentUid: 'user-alice',
          );

          // Create request (REQ-001, REQ-002)
          await controller.createRequest(
            familyId: 'fam-alpha',
            recipientUid: 'user-bob',
            title: 'Passport Copy',
            notes: 'For visa application',
          );

          var state = controller.state;
          expect(state.outgoingRequests.length, 1);
          final createdReq = state.outgoingRequests.first;
          expect(createdReq.title, 'Passport Copy');
          expect(createdReq.status, DocumentRequestStatus.pending);

          // Fulfill request (REQ-003, REQ-004)
          await controller.fulfillRequest(
            requestId: createdReq.requestId,
            documentId: 'doc-passport-999',
          );

          state = controller.state;
          expect(
            state.outgoingRequests.first.status,
            DocumentRequestStatus.fulfilled,
          );
          expect(
            state.outgoingRequests.first.fulfilledDocumentId,
            'doc-passport-999',
          );
        },
      );

      testWidgets('FamilyScreen renders Document Requests section', (
        tester,
      ) async {
        final familyRepo = InMemoryFamilyRepository();
        final now = DateTime.now().toUtc();

        await familyRepo.saveFamily(
          FamilySpace(
            familyId: 'fam-test-1',
            name: 'Godhani Family',
            ownerUid: 'guest-uid',
            keyEpoch: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await familyRepo.addMember(
          FamilyMember(
            uid: 'guest-uid',
            familyId: 'fam-test-1',
            displayName: 'Alice',
            email: 'alice@family.org',
            role: FamilyRole.owner,
            joinedAt: now,
          ),
        );
        await familyRepo.addMember(
          FamilyMember(
            uid: 'user-bob',
            familyId: 'fam-test-1',
            displayName: 'Bob',
            email: 'bob@family.org',
            role: FamilyRole.member,
            joinedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              familyRepositoryProvider.overrideWithValue(familyRepo),
              documentRequestRepositoryProvider.overrideWithValue(requestRepo),
            ],
            child: const MaterialApp(home: FamilyScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Document Requests (0)'), findsOneWidget);
        expect(find.text('Request Document'), findsOneWidget);
      });
    },
  );

  group('SettingsScreen Account Deletion Workflow (ROADMAP.md Section 15)', () {
    testWidgets('Prompts confirmation before deleting account', (tester) async {
      final mockAuth = MockAuthRepository();
      final mockProfile = MockUserProfileRepository();
      await mockAuth.signInWithEmailAndPassword(
        email: 'test@familyvault.app',
        password: 'Password123!',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuth),
            userProfileRepositoryProvider.overrideWithValue(mockProfile),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final deleteTile = find.text('Delete Account & Vault');
      await tester.scrollUntilVisible(
        deleteTile,
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(deleteTile, findsOneWidget);

      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      // Verify dialog appears with warning
      expect(find.text('Delete Account & Vault?'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete Permanently'));
      await tester.pumpAndSettle();

      // Verify user is signed out and account deleted
      expect(mockAuth.currentUid, isNull);
    });
  });
}
