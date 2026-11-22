import '../entities/document_record.dart';
import '../entities/document_version.dart';
import '../entities/key_envelope.dart';

/// Repository contract for managing personal vault documents, immutable versions,
/// and key envelopes (DATABASE_SCHEMA.md & ARCHITECTURE.md).
abstract class DocumentRepository {
  /// Retrieves personal documents, optionally filtered by category and owner.
  Future<List<DocumentRecord>> getDocuments({
    String? category,
    String? ownerUid,
    bool includeArchived = false,
    bool includeDeleted = false,
  });

  /// Retrieves a specific document by its ID.
  Future<DocumentRecord?> getDocumentById(String documentId);

  /// Saves or updates a document metadata record.
  Future<void> saveDocument(DocumentRecord document);

  /// Saves an immutable document version record.
  Future<void> saveVersion(DocumentVersion version);

  /// Retrieves the complete version history of a document.
  Future<List<DocumentVersion>> getVersions(String documentId);

  /// Saves a wrapped key envelope.
  Future<void> saveKeyEnvelope(KeyEnvelope envelope);

  /// Retrieves an authorized key envelope for a recipient.
  Future<KeyEnvelope?> getKeyEnvelope({
    required String documentId,
    required String recipientId,
  });

  /// Soft deletes a document (DOC-013).
  Future<void> softDeleteDocument(String documentId);

  /// Toggles favorite status on a document (SEARCH-005).
  Future<void> toggleFavorite(String documentId);

  /// Permanently removes a document and its version history (DOC-014).
  Future<void> permanentlyDeleteDocument(String documentId);
}
