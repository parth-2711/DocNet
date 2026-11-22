import '../entities/document_request.dart';

/// Repository contract for managing formal document requests (PRD.md Section 6.8 & DATABASE_SCHEMA.md Section 15).
abstract class DocumentRequestRepository {
  /// Creates a new document request.
  Future<void> createRequest(DocumentRequest request);

  /// Retrieves requests where user is recipient.
  Future<List<DocumentRequest>> getRequestsForRecipient(String recipientUid);

  /// Retrieves requests initiated by the user.
  Future<List<DocumentRequest>> getRequestsByRequester(String requesterUid);

  /// Updates status and optional fulfillment details of a request.
  Future<void> updateStatus({
    required String requestId,
    required DocumentRequestStatus status,
    String? fulfilledDocumentId,
  });
}
