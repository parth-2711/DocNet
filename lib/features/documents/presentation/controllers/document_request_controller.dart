import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../data/repositories/persistent_document_request_repository.dart';
import '../../domain/entities/document_request.dart';
import '../../domain/repositories/document_request_repository.dart';

class DocumentRequestState {
  final List<DocumentRequest> incomingRequests;
  final List<DocumentRequest> outgoingRequests;
  final bool isLoading;
  final String? errorMessage;

  const DocumentRequestState({
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DocumentRequestState copyWith({
    List<DocumentRequest>? incomingRequests,
    List<DocumentRequest>? outgoingRequests,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DocumentRequestState(
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final documentRequestRepositoryProvider = Provider<DocumentRequestRepository>((
  ref,
) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return PersistentDocumentRequestRepository(storageService);
});

final documentRequestControllerProvider =
    StateNotifierProvider<DocumentRequestController, DocumentRequestState>((
      ref,
    ) {
      final repo = ref.watch(documentRequestRepositoryProvider);
      final authState = ref.watch(authControllerProvider);
      final uid = authState.userProfile?.uid ?? 'guest-uid';

      return DocumentRequestController(
        requestRepository: repo,
        currentUid: uid,
      );
    });

class DocumentRequestController extends StateNotifier<DocumentRequestState> {
  final DocumentRequestRepository requestRepository;
  final String currentUid;
  final Uuid uuid;

  DocumentRequestController({
    required this.requestRepository,
    required this.currentUid,
    this.uuid = const Uuid(),
  }) : super(const DocumentRequestState()) {
    loadRequests();
  }

  Future<void> loadRequests() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final incoming = await requestRepository.getRequestsForRecipient(
        currentUid,
      );
      final outgoing = await requestRepository.getRequestsByRequester(
        currentUid,
      );
      state = state.copyWith(
        incomingRequests: incoming,
        outgoingRequests: outgoing,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Initiates a new document request without sensitive numbers (REQ-001, REQ-002).
  Future<void> createRequest({
    required String familyId,
    required String recipientUid,
    required String title,
    String? notes,
    Duration expiry = const Duration(days: 7),
  }) async {
    final now = DateTime.now().toUtc();
    final req = DocumentRequest(
      requestId: uuid.v4(),
      familyId: familyId,
      requesterUid: currentUid,
      recipientUid: recipientUid,
      title: title,
      notes: notes,
      status: DocumentRequestStatus.pending,
      createdAt: now,
      expiresAt: now.add(expiry),
    );

    await requestRepository.createRequest(req);
    await loadRequests();
  }

  /// Fulfills an incoming request by associating a document (REQ-003, REQ-004).
  Future<void> fulfillRequest({
    required String requestId,
    required String documentId,
  }) async {
    await requestRepository.updateStatus(
      requestId: requestId,
      status: DocumentRequestStatus.fulfilled,
      fulfilledDocumentId: documentId,
    );
    await loadRequests();
  }

  /// Declines an incoming request (REQ-003).
  Future<void> declineRequest(String requestId) async {
    await requestRepository.updateStatus(
      requestId: requestId,
      status: DocumentRequestStatus.declined,
    );
    await loadRequests();
  }

  /// Cancels an outgoing request (REQ-005).
  Future<void> cancelRequest(String requestId) async {
    await requestRepository.updateStatus(
      requestId: requestId,
      status: DocumentRequestStatus.cancelled,
    );
    await loadRequests();
  }
}
