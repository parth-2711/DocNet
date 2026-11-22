import '../entities/document_record.dart';

/// Available sort criteria for vault documents.
enum DocumentSortOption { dateDesc, dateAsc, nameAsc, nameDesc, sizeDesc }

/// Filter criteria for querying vault documents locally on-device
/// (PRD.md SEARCH-001 through SEARCH-007).
class DocumentFilter {
  final String searchQuery;
  final String category;
  final bool favoritesOnly;
  final String? ownerUid;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final DocumentSortOption sortBy;

  const DocumentFilter({
    this.searchQuery = '',
    this.category = 'All',
    this.favoritesOnly = false,
    this.ownerUid,
    this.dateFrom,
    this.dateTo,
    this.sortBy = DocumentSortOption.dateDesc,
  });

  DocumentFilter copyWith({
    String? searchQuery,
    String? category,
    bool? favoritesOnly,
    String? ownerUid,
    DateTime? dateFrom,
    DateTime? dateTo,
    DocumentSortOption? sortBy,
  }) {
    return DocumentFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      ownerUid: ownerUid ?? this.ownerUid,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

/// Zero-knowledge local search and filter engine (PRD.md SEARCH-001, SEARCH-007).
///
/// Executes multi-criteria filtering completely on-device against decrypted in-memory
/// metadata, ensuring no sensitive queries or plaintext names leak to cloud search indexes.
class DocumentSearchEngine {
  const DocumentSearchEngine._();

  static List<DocumentRecord> applyFilter({
    required List<DocumentRecord> documents,
    required DocumentFilter filter,
  }) {
    var result = documents.where((doc) {
      // 1. Exclude soft-deleted documents
      if (doc.isDeleted) return false;

      // 2. Category filter (SEARCH-002)
      if (filter.category != 'All' &&
          doc.category.toLowerCase() != filter.category.toLowerCase()) {
        return false;
      }

      // 3. Favorites filter (SEARCH-005)
      if (filter.favoritesOnly && !doc.isFavorite) {
        return false;
      }

      // 4. Owner filter (SEARCH-003)
      if (filter.ownerUid != null &&
          filter.ownerUid!.isNotEmpty &&
          doc.ownerUid != filter.ownerUid &&
          doc.category != 'Family') {
        return false;
      }

      // 5. Date filter (SEARCH-004)
      if (filter.dateFrom != null && doc.updatedAt.isBefore(filter.dateFrom!)) {
        return false;
      }
      if (filter.dateTo != null && doc.updatedAt.isAfter(filter.dateTo!)) {
        return false;
      }

      // 6. Text query search (SEARCH-001: decrypted names, descriptions, tags, and category)
      final query = filter.searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final nameMatch =
            doc.decryptedName?.toLowerCase().contains(query) ?? false;
        final descMatch =
            doc.decryptedDescription?.toLowerCase().contains(query) ?? false;
        final catMatch = doc.category.toLowerCase().contains(query);
        final tagMatch = doc.decryptedTags.any(
          (t) => t.toLowerCase().contains(query),
        );

        if (!nameMatch && !descMatch && !catMatch && !tagMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    // 7. Sort documents according to selected option
    switch (filter.sortBy) {
      case DocumentSortOption.dateDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case DocumentSortOption.dateAsc:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case DocumentSortOption.nameAsc:
        result.sort((a, b) {
          final nameA = a.decryptedName ?? a.documentId;
          final nameB = b.decryptedName ?? b.documentId;
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
        break;
      case DocumentSortOption.nameDesc:
        result.sort((a, b) {
          final nameA = a.decryptedName ?? a.documentId;
          final nameB = b.decryptedName ?? b.documentId;
          return nameB.toLowerCase().compareTo(nameA.toLowerCase());
        });
        break;
      case DocumentSortOption.sizeDesc:
        result.sort(
          (a, b) => b.originalSizeBytes.compareTo(a.originalSizeBytes),
        );
        break;
    }

    return result;
  }
}
