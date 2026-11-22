import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docnet/features/documents/data/repositories/in_memory_document_repository.dart';
import 'package:docnet/features/documents/domain/entities/document_record.dart';
import 'package:docnet/features/documents/domain/services/document_search_engine.dart';
import 'package:docnet/features/documents/presentation/controllers/documents_controller.dart';
import 'package:docnet/features/documents/presentation/documents_screen.dart';
import 'package:docnet/features/security/domain/entities/encrypted_metadata.dart';

DocumentRecord _createTestDoc({
  required String id,
  required String name,
  required String category,
  String? description,
  List<String> tags = const [],
  bool isFavorite = false,
  bool isDeleted = false,
  String ownerUid = 'guest-uid',
  int originalSizeBytes = 1024,
  required DateTime updatedAt,
}) {
  return DocumentRecord(
    documentId: id,
    ownerUid: ownerUid,
    currentVersionId: 'ver-$id',
    category: category,
    isFavorite: isFavorite,
    isDeleted: isDeleted,
    encryptedMetadata: EncryptedMetadata(
      nonce: Uint8List(12),
      cipherText: Uint8List(16),
      macTag: Uint8List(16),
    ),
    mimeType: name.endsWith('.pdf') ? 'application/pdf' : 'image/png',
    originalSizeBytes: originalSizeBytes,
    encryptedSizeBytes: originalSizeBytes + 28,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    decryptedName: name,
    decryptedDescription: description,
    decryptedTags: tags,
  );
}

void main() {
  group('DocumentSearchEngine Unit Tests (SEARCH-001 through SEARCH-007)', () {
    late List<DocumentRecord> sampleDocs;

    setUp(() {
      sampleDocs = [
        _createTestDoc(
          id: 'doc-1',
          name: 'Passport_Scan.pdf',
          category: 'Identity',
          description: 'Official biometric passport',
          tags: ['official', 'travel'],
          isFavorite: true,
          originalSizeBytes: 5000,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        _createTestDoc(
          id: 'doc-2',
          name: 'Income_Tax_2025.pdf',
          category: 'Finance',
          description: 'Filed acknowledgment',
          tags: ['tax', 'finance'],
          isFavorite: false,
          originalSizeBytes: 15000,
          updatedAt: DateTime.utc(2026, 3, 15),
        ),
        _createTestDoc(
          id: 'doc-3',
          name: 'Blood_Report.png',
          category: 'Medical',
          description: 'Annual routine health checkup',
          tags: ['health', 'hospital'],
          isFavorite: true,
          originalSizeBytes: 2000,
          updatedAt: DateTime.utc(2026, 5, 20),
        ),
        _createTestDoc(
          id: 'doc-4',
          name: 'Deleted_Contract.pdf',
          category: 'Legal',
          isDeleted: true,
          updatedAt: DateTime.utc(2026, 6, 1),
        ),
      ];
    });

    test('excludes soft-deleted documents by default', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(),
      );
      expect(results.length, 3);
      expect(results.any((d) => d.documentId == 'doc-4'), isFalse);
    });

    test('SEARCH-001: searches locally by decrypted name', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(searchQuery: 'passport'),
      );
      expect(results.length, 1);
      expect(results.first.documentId, 'doc-1');
    });

    test('SEARCH-001: searches locally by decrypted description', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(searchQuery: 'routine health'),
      );
      expect(results.length, 1);
      expect(results.first.documentId, 'doc-3');
    });

    test('SEARCH-001: searches locally by tags', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(searchQuery: 'tax'),
      );
      expect(results.length, 1);
      expect(results.first.documentId, 'doc-2');
    });

    test('SEARCH-002: filters by category', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(category: 'Medical'),
      );
      expect(results.length, 1);
      expect(results.first.documentId, 'doc-3');
    });

    test('SEARCH-005: filters favorites only', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(favoritesOnly: true),
      );
      expect(results.length, 2);
      expect(results.map((d) => d.documentId), containsAll(['doc-1', 'doc-3']));
    });

    test('SEARCH-003: filters by owner UID', () {
      final docBob = _createTestDoc(
        id: 'doc-bob',
        name: 'Bob_License.pdf',
        category: 'Identity',
        ownerUid: 'user-bob',
        updatedAt: DateTime.utc(2026, 2, 1),
      );

      final combined = [...sampleDocs, docBob];
      final results = DocumentSearchEngine.applyFilter(
        documents: combined,
        filter: const DocumentFilter(ownerUid: 'user-bob'),
      );
      expect(results.length, 1);
      expect(results.first.documentId, 'doc-bob');
    });

    test('SEARCH-004: filters by date range', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: DocumentFilter(
          dateFrom: DateTime.utc(2026, 2, 1),
          dateTo: DateTime.utc(2026, 4, 1),
        ),
      );
      expect(results.length, 1);
      expect(results.first.documentId, 'doc-2');
    });

    test('Sorts by date descending (newest first)', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(sortBy: DocumentSortOption.dateDesc),
      );
      expect(results.map((d) => d.documentId).toList(), [
        'doc-3',
        'doc-2',
        'doc-1',
      ]);
    });

    test('Sorts by name ascending (A-Z)', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(sortBy: DocumentSortOption.nameAsc),
      );
      expect(results.map((d) => d.decryptedName).toList(), [
        'Blood_Report.png',
        'Income_Tax_2025.pdf',
        'Passport_Scan.pdf',
      ]);
    });

    test('Sorts by original size descending (largest first)', () {
      final results = DocumentSearchEngine.applyFilter(
        documents: sampleDocs,
        filter: const DocumentFilter(sortBy: DocumentSortOption.sizeDesc),
      );
      expect(results.map((d) => d.documentId).toList(), [
        'doc-2',
        'doc-1',
        'doc-3',
      ]);
    });
  });

  group('DocumentsController & Search Integration Tests', () {
    test('StateNotifier updates search query and category smoothly', () async {
      final docRepo = InMemoryDocumentRepository();
      final t1 = DateTime.utc(2026, 1, 1);

      await docRepo.saveDocument(
        _createTestDoc(
          id: 'doc-1',
          name: 'Aadhaar_Card.pdf',
          category: 'Identity',
          updatedAt: t1,
        ),
      );
      await docRepo.saveDocument(
        _createTestDoc(
          id: 'doc-2',
          name: 'Salary_Slip.pdf',
          category: 'Finance',
          updatedAt: t1,
        ),
      );

      final container = ProviderContainer(
        overrides: [documentRepositoryProvider.overrideWithValue(docRepo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(documentsControllerProvider.notifier);
      await controller.loadDocuments();

      var state = container.read(documentsControllerProvider);
      expect(state.documents.length, 2);

      // Search by name
      controller.setSearchQuery('Salary');
      state = container.read(documentsControllerProvider);
      expect(state.documents.length, 1);
      expect(state.documents.first.documentId, 'doc-2');

      // Clear search
      controller.setSearchQuery('');
      state = container.read(documentsControllerProvider);
      expect(state.documents.length, 2);

      // Filter by category
      controller.selectCategory('Identity');
      state = container.read(documentsControllerProvider);
      expect(state.documents.length, 1);
      expect(state.documents.first.documentId, 'doc-1');
    });

    test(
      'toggleFavorite updates favorite state and filters correctly',
      () async {
        final docRepo = InMemoryDocumentRepository();
        final doc = _createTestDoc(
          id: 'doc-fav',
          name: 'Will.pdf',
          category: 'Legal',
          isFavorite: false,
          updatedAt: DateTime.now().toUtc(),
        );
        await docRepo.saveDocument(doc);

        final container = ProviderContainer(
          overrides: [documentRepositoryProvider.overrideWithValue(docRepo)],
        );
        addTearDown(container.dispose);

        final controller = container.read(documentsControllerProvider.notifier);
        await controller.loadDocuments();

        var state = container.read(documentsControllerProvider);
        expect(state.documents.first.isFavorite, isFalse);

        // Toggle favorite
        await controller.toggleFavorite('doc-fav');
        state = container.read(documentsControllerProvider);
        expect(state.documents.first.isFavorite, isTrue);

        // Filter favorites
        controller.toggleFavoritesOnly();
        state = container.read(documentsControllerProvider);
        expect(state.documents.length, 1);
      },
    );
  });

  group('DocumentsScreen UI Widget Search Tests', () {
    testWidgets(
      'Entering search query in TextField filters document list live',
      (tester) async {
        final docRepo = InMemoryDocumentRepository();
        await docRepo.saveDocument(
          _createTestDoc(
            id: 'doc-1',
            name: 'Passport.pdf',
            category: 'Identity',
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        await docRepo.saveDocument(
          _createTestDoc(
            id: 'doc-2',
            name: 'Car_Insurance.pdf',
            category: 'Insurance',
            updatedAt: DateTime.now().toUtc(),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [documentRepositoryProvider.overrideWithValue(docRepo)],
            child: const MaterialApp(home: DocumentsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Passport.pdf'), findsOneWidget);
        expect(find.text('Car_Insurance.pdf'), findsOneWidget);

        // Type "Car" into search field
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Car');
        await tester.pumpAndSettle();

        expect(find.text('Passport.pdf'), findsNothing);
        expect(find.text('Car_Insurance.pdf'), findsOneWidget);
      },
    );

    testWidgets('Tapping Favorites chip filters to only favorite documents', (
      tester,
    ) async {
      final docRepo = InMemoryDocumentRepository();
      await docRepo.saveDocument(
        _createTestDoc(
          id: 'doc-1',
          name: 'Passport.pdf',
          category: 'Identity',
          isFavorite: true,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await docRepo.saveDocument(
        _createTestDoc(
          id: 'doc-2',
          name: 'Electric_Bill.pdf',
          category: 'Utility',
          isFavorite: false,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [documentRepositoryProvider.overrideWithValue(docRepo)],
          child: const MaterialApp(home: DocumentsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passport.pdf'), findsOneWidget);
      expect(find.text('Electric_Bill.pdf'), findsOneWidget);

      // Tap "Favorites" chip
      await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
      await tester.pumpAndSettle();

      expect(find.text('Passport.pdf'), findsOneWidget);
      expect(find.text('Electric_Bill.pdf'), findsNothing);
    });
  });
}
