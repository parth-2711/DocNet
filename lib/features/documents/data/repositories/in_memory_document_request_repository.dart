import '../../domain/entities/document_request.dart';
import '../../domain/repositories/document_request_repository.dart';

/// In-memory implementation of DocumentRequestRepository.
class InMemoryDocumentRequestRepository implements DocumentRequestRepository {
  final Map<String, DocumentRequest> _requests = {};

  @override
  Future<void> createRequest(DocumentRequest request) async {
    _requests[request.requestId] = request;
  }

  @override
  Future<List<DocumentRequest>> getRequestsForRecipient(
    String recipientUid,
  ) async {
    final list = _requests.values
        .where((r) => r.recipientUid == recipientUid)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<List<DocumentRequest>> getRequestsByRequester(
    String requesterUid,
  ) async {
    final list = _requests.values
        .where((r) => r.requesterUid == requesterUid)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<void> updateStatus({
    required String requestId,
    required DocumentRequestStatus status,
    String? fulfilledDocumentId,
  }) async {
    final existing = _requests[requestId];
    if (existing != null) {
      _requests[requestId] = existing.copyWith(
        status: status,
        fulfilledDocumentId: fulfilledDocumentId,
        respondedAt: DateTime.now().toUtc(),
      );
    }
  }
}
