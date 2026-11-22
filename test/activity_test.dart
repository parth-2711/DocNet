import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:docnet/features/activity/data/repositories/in_memory_activity_repository.dart';
import 'package:docnet/features/activity/domain/entities/activity_event.dart';
import 'package:docnet/features/activity/presentation/activity_screen.dart';
import 'package:docnet/features/activity/presentation/controllers/activity_controller.dart';
import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/domain/usecases/upload_document_usecase.dart';
import 'package:docnet/features/family/data/repositories/in_memory_family_repository.dart';
import 'package:docnet/features/family/domain/usecases/share_document_usecase.dart';
import 'package:docnet/features/security/data/crypto/cryptography_crypto_service.dart';
import 'package:docnet/features/sync/data/database/app_database.dart';
import 'package:docnet/features/sync/data/repositories/drift_sync_queue_repository.dart';

void main() {
  group('ActivityEvent Entity & Serialization Tests', () {
    test('ActivityEvent correctly converts to and from Firestore map', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0, 0);
      final event = ActivityEvent(
        activityId: 'act-123',
        familyId: 'fam-456',
        eventType: ActivityEventType.documentCreated,
        actorUid: 'user-789',
        targetDocumentId: 'doc-999',
        summary: 'Encrypted document uploaded',
        metadata: {'category': 'Finance', 'encryptedSize': 4096},
        timestamp: now,
      );

      final map = event.toFirestoreMap();
      expect(map['activityId'], 'act-123');
      expect(map['familyId'], 'fam-456');
      expect(map['eventType'], 'documentCreated');
      expect(map['actorUid'], 'user-789');
      expect(map['targetDocumentId'], 'doc-999');
      expect(map['summary'], 'Encrypted document uploaded');
      expect(map['metadata']['category'], 'Finance');
      expect(map['timestamp'], now.toIso8601String());

      final reconstituted = ActivityEvent.fromFirestoreMap(map);
      expect(reconstituted.activityId, event.activityId);
      expect(reconstituted.familyId, event.familyId);
      expect(reconstituted.eventType, event.eventType);
      expect(reconstituted.actorUid, event.actorUid);
      expect(reconstituted.targetDocumentId, event.targetDocumentId);
      expect(reconstituted.summary, event.summary);
      expect(reconstituted.metadata['category'], 'Finance');
      expect(reconstituted.timestamp, event.timestamp);
    });
  });

  group('InMemoryActivityRepository Tests', () {
    late InMemoryActivityRepository repository;

    setUp(() {
      repository = InMemoryActivityRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('logs and queries events chronologically descending', () async {
      final t1 = DateTime.utc(2026, 11, 6, 10, 0);
      final t2 = DateTime.utc(2026, 11, 6, 11, 0);

      await repository.logEvent(
        ActivityEvent(
          activityId: '1',
          eventType: ActivityEventType.signIn,
          actorUid: 'user-1',
          summary: 'User signed in',
          timestamp: t1,
        ),
      );

      await repository.logEvent(
        ActivityEvent(
          activityId: '2',
          eventType: ActivityEventType.documentCreated,
          actorUid: 'user-1',
          summary: 'Encrypted document uploaded',
          timestamp: t2,
        ),
      );

      final events = await repository.getEvents();
      expect(events.length, 2);
      expect(events.first.activityId, '2'); // Most recent first
      expect(events.last.activityId, '1');
    });

    test('filters events by actorUid, familyId, and eventType', () async {
      final now = DateTime.now().toUtc();
      await repository.logEvent(
        ActivityEvent(
          activityId: '1',
          familyId: 'fam-a',
          eventType: ActivityEventType.documentCreated,
          actorUid: 'user-a',
          summary: 'Doc created',
          timestamp: now,
        ),
      );
      await repository.logEvent(
        ActivityEvent(
          activityId: '2',
          familyId: 'fam-b',
          eventType: ActivityEventType.shareGranted,
          actorUid: 'user-b',
          summary: 'Share granted',
          timestamp: now,
        ),
      );

      final famAEvents = await repository.getEvents(familyId: 'fam-a');
      expect(famAEvents.length, 1);
      expect(famAEvents.first.activityId, '1');

      final shareEvents = await repository.getEvents(
        eventType: ActivityEventType.shareGranted,
      );
      expect(shareEvents.length, 1);
      expect(shareEvents.first.activityId, '2');
    });

    test('watchEvents emits stream updates when events are logged', () async {
      final stream = repository.watchEvents();
      final futureEvents = stream.first;

      await repository.logEvent(
        ActivityEvent(
          activityId: 'stream-1',
          eventType: ActivityEventType.documentExported,
          actorUid: 'user-1',
          summary: 'Document exported',
          timestamp: DateTime.now().toUtc(),
        ),
      );

      final result = await futureEvents;
      expect(result.length, 1);
      expect(result.first.activityId, 'stream-1');
    });
  });

  group('Activity Logging UseCase Integration Tests', () {
    late CryptographyCryptoService cryptoService;
    late InMemoryDocumentRepository docRepo;
    late InMemoryActivityRepository activityRepo;
    late AppDatabase db;
    late DriftSyncQueueRepository syncRepo;

    setUp(() {
      cryptoService = CryptographyCryptoService();
      docRepo = InMemoryDocumentRepository();
      activityRepo = InMemoryActivityRepository();
      db = AppDatabase(NativeDatabase.memory());
      syncRepo = DriftSyncQueueRepository(db);
    });

    tearDown(() async {
      activityRepo.dispose();
      await db.close();
    });

    test(
      'UploadDocumentUseCase automatically logs zero-knowledge activity event',
      () async {
        final uploadUseCase = UploadDocumentUseCase(
          cryptoService: cryptoService,
          documentRepository: docRepo,
          syncQueueRepository: syncRepo,
          activityRepository: activityRepo,
        );

        final dummyBytes = Uint8List.fromList(
          utf8.encode('Secret passport plaintext payload'),
        );
        final result = await uploadUseCase.execute(
          fileBytes: dummyBytes,
          fileName: 'Confidential_Passport.pdf',
          category: 'Identity',
          ownerUid: 'uid-test-owner',
        );

        final events = await activityRepo.getEvents();
        expect(events.length, 1);
        final event = events.first;

        expect(event.eventType, ActivityEventType.documentCreated);
        expect(event.actorUid, 'uid-test-owner');
        expect(event.targetDocumentId, result.document.documentId);
        expect(event.summary, 'Encrypted document uploaded');
        // Crucial: Zero-knowledge verification — no plaintext filename in event summary or metadata
        expect(event.summary, isNot(contains('Confidential_Passport')));
        expect(event.metadata['category'], 'Identity');
      },
    );

    test(
      'ShareDocumentUseCase automatically logs share event with least-privilege metadata',
      () async {
        final familyRepo = InMemoryFamilyRepository();
        final uploadUseCase = UploadDocumentUseCase(
          cryptoService: cryptoService,
          documentRepository: docRepo,
          syncQueueRepository: syncRepo,
        );
        final shareUseCase = ShareDocumentUseCase(
          documentRepository: docRepo,
          familyRepository: familyRepo,
          activityRepository: activityRepo,
        );

        final uploadResult = await uploadUseCase.execute(
          fileBytes: Uint8List.fromList(utf8.encode('Document content')),
          fileName: 'Tax_Return_2025.pdf',
          category: 'Finance',
          ownerUid: 'owner-uid',
        );

        await shareUseCase.execute(
          documentId: uploadResult.document.documentId,
          granterUid: 'owner-uid',
          recipientUid: 'spouse-uid',
          canView: true,
          canDownload: false,
        );

        final events = await activityRepo.getEvents();
        expect(events.length, 1);
        final event = events.first;

        expect(event.eventType, ActivityEventType.shareGranted);
        expect(event.actorUid, 'owner-uid');
        expect(event.targetMemberUid, 'spouse-uid');
        expect(event.targetDocumentId, uploadResult.document.documentId);
        expect(event.summary, contains('view-only permission'));
        expect(event.metadata['canView'], true);
        expect(event.metadata['canDownload'], false);
      },
    );
  });

  group('ActivityScreen & Controller UI Tests', () {
    testWidgets('ActivityScreen displays empty state when no events exist', (
      tester,
    ) async {
      final activityRepo = InMemoryActivityRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityRepositoryProvider.overrideWithValue(activityRepo),
          ],
          child: const MaterialApp(home: ActivityScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity Log'), findsOneWidget);
      expect(find.text('No Activity Found'), findsOneWidget);
      expect(
        find.text('No security or vault events recorded yet.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'ActivityScreen renders event cards and filter chips interactively',
      (tester) async {
        final activityRepo = InMemoryActivityRepository();
        final now = DateTime.now().toUtc();

        await activityRepo.logEvent(
          ActivityEvent(
            activityId: 'act-1',
            eventType: ActivityEventType.documentCreated,
            actorUid: 'user-1',
            targetDocumentId: 'doc-alpha-1234',
            summary: 'Encrypted document uploaded',
            timestamp: now,
          ),
        );

        await activityRepo.logEvent(
          ActivityEvent(
            activityId: 'act-2',
            eventType: ActivityEventType.recoveryPhraseVerified,
            actorUid: 'user-1',
            summary: '12-word recovery phrase confirmed and stored',
            timestamp: now.add(const Duration(minutes: 5)),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activityRepositoryProvider.overrideWithValue(activityRepo),
            ],
            child: const MaterialApp(home: ActivityScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Encrypted document uploaded'), findsOneWidget);
        expect(
          find.text('12-word recovery phrase confirmed and stored'),
          findsOneWidget,
        );

        // Tap "Security" filter chip
        await tester.tap(find.widgetWithText(FilterChip, 'Security'));
        await tester.pumpAndSettle();

        // Only recovery event should be visible
        expect(find.text('Encrypted document uploaded'), findsNothing);
        expect(
          find.text('12-word recovery phrase confirmed and stored'),
          findsOneWidget,
        );

        // Tap "Documents" filter chip
        await tester.tap(find.widgetWithText(FilterChip, 'Documents'));
        await tester.pumpAndSettle();

        // Only document event should be visible
        expect(find.text('Encrypted document uploaded'), findsOneWidget);
        expect(
          find.text('12-word recovery phrase confirmed and stored'),
          findsNothing,
        );
      },
    );
  });
}
