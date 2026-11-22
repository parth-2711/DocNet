import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/document_request.dart';
import '../../domain/repositories/document_request_repository.dart';

/// Persistent implementation of DocumentRequestRepository saving requests
/// to device storage across application restarts (PRD.md Section 6.8).
class PersistentDocumentRequestRepository implements DocumentRequestRepository {
  final LocalVaultStorageService storageService;

  final Map<String, DocumentRequest> _requests = {};
  bool _loaded = false;

  PersistentDocumentRequestRepository(this.storageService);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('requests');
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final req = DocumentRequest.fromMap(item);
            _requests[req.requestId] = req;
          }
        }
      }
    } catch (_) {
      // Ignore initial missing file
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final list = _requests.values.map((r) => r.toMap()).toList();
    await storageService.saveJson('requests', list);
  }

  @override
  Future<void> createRequest(DocumentRequest request) async {
    await _ensureLoaded();
    _requests[request.requestId] = request;
    await _persist();
  }

  @override
  Future<List<DocumentRequest>> getRequestsForRecipient(
    String recipientUid,
  ) async {
    await _ensureLoaded();
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
    await _ensureLoaded();
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
    await _ensureLoaded();
    final existing = _requests[requestId];
    if (existing != null) {
      _requests[requestId] = existing.copyWith(
        status: status,
        fulfilledDocumentId: fulfilledDocumentId,
        respondedAt: DateTime.now().toUtc(),
      );
      await _persist();
    }
  }
}
