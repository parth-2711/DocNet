import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../activity/domain/entities/activity_event.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../activity/presentation/controllers/activity_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../security/data/crypto/cryptography_crypto_service.dart';
import '../../../security/domain/services/crypto_service.dart';
import '../../../sync/data/database/app_database.dart';
import '../../../sync/data/repositories/drift_sync_queue_repository.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/repositories/sync_queue_repository.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../data/repositories/persistent_document_repository.dart';
import '../../data/repositories/persistent_storage_repository.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/services/document_search_engine.dart';
import '../../domain/usecases/download_and_decrypt_usecase.dart';
import '../../domain/usecases/upload_document_usecase.dart';

class DocumentsState {
  final List<DocumentRecord> rawDocuments;
  final DocumentFilter filter;
  final bool isLoading;
  final bool isUploading;
  final String? errorMessage;

  const DocumentsState({
    List<DocumentRecord> rawDocuments = const [],
    List<DocumentRecord>? documents,
    this.filter = const DocumentFilter(),
    this.isLoading = false,
    this.isUploading = false,
    this.errorMessage,
  }) : rawDocuments = documents ?? rawDocuments;

  List<DocumentRecord> get documents =>
      DocumentSearchEngine.applyFilter(documents: rawDocuments, filter: filter);

  String get selectedCategory => filter.category;

  DocumentsState copyWith({
    List<DocumentRecord>? rawDocuments,
    List<DocumentRecord>? documents,
    DocumentFilter? filter,
    bool? isLoading,
    bool? isUploading,
    String? errorMessage,
  }) {
    return DocumentsState(
      rawDocuments: documents ?? rawDocuments ?? this.rawDocuments,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      errorMessage: errorMessage,
    );
  }
}

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptographyCryptoService();
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return PersistentDocumentRepository(storageService);
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return PersistentStorageRepository(storageService);
});

// Provides the sync queue repository using an in-memory Drift database
final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  final db = AppDatabase(NativeDatabase.memory());
  ref.onDispose(() => db.close());
  return DriftSyncQueueRepository(db);
});

final uploadDocumentUseCaseProvider = Provider<UploadDocumentUseCase>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  final docRepo = ref.watch(documentRepositoryProvider);
  final syncRepo = ref.watch(syncQueueRepositoryProvider);
  final storageRepo = ref.watch(storageRepositoryProvider);
  final activityRepo = ref.watch(activityRepositoryProvider);

  return UploadDocumentUseCase(
    cryptoService: cryptoService,
    documentRepository: docRepo,
    syncQueueRepository: syncRepo,
    storageRepository: storageRepo,
    activityRepository: activityRepo,
  );
});

final downloadAndDecryptUseCaseProvider = Provider<DownloadAndDecryptUseCase>((
  ref,
) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  final docRepo = ref.watch(documentRepositoryProvider);
  final storageRepo = ref.watch(storageRepositoryProvider);

  return DownloadAndDecryptUseCase(
    cryptoService: cryptoService,
    documentRepository: docRepo,
    storageRepository: storageRepo,
  );
});

final documentsControllerProvider =
    StateNotifierProvider<DocumentsController, DocumentsState>((ref) {
      final docRepo = ref.watch(documentRepositoryProvider);
      final uploadUseCase = ref.watch(uploadDocumentUseCaseProvider);
      final authState = ref.watch(authControllerProvider);
      final activityRepo = ref.watch(activityRepositoryProvider);
      final syncRepo = ref.watch(syncQueueRepositoryProvider);

      return DocumentsController(
        docRepo: docRepo,
        uploadUseCase: uploadUseCase,
        currentUserUid: authState.userProfile?.uid ?? 'guest-uid',
        activityRepo: activityRepo,
        syncRepo: syncRepo,
      );
    });

class DocumentsController extends StateNotifier<DocumentsState> {
  final DocumentRepository docRepo;
  final UploadDocumentUseCase uploadUseCase;
  final String currentUserUid;
  final ActivityRepository? activityRepo;
  final SyncQueueRepository? syncRepo;

  DocumentsController({
    required this.docRepo,
    required this.uploadUseCase,
    required this.currentUserUid,
    this.activityRepo,
    this.syncRepo,
  }) : super(DocumentsState(filter: DocumentFilter(ownerUid: currentUserUid))) {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final docs = await docRepo.getDocuments(ownerUid: currentUserUid);
      state = state.copyWith(rawDocuments: docs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> selectCategory(String category) async {
    state = state.copyWith(
      filter: state.filter.copyWith(category: category, ownerUid: currentUserUid),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query, ownerUid: currentUserUid),
    );
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(
      filter: state.filter.copyWith(
        favoritesOnly: !state.filter.favoritesOnly,
        ownerUid: currentUserUid,
      ),
    );
  }

  void setSortOption(DocumentSortOption sortBy) {
    state = state.copyWith(
      filter: state.filter.copyWith(sortBy: sortBy, ownerUid: currentUserUid),
    );
  }

  Future<void> toggleFavorite(String documentId) async {
    try {
      await docRepo.toggleFavorite(documentId);
      final updatedRaw = state.rawDocuments.map((doc) {
        if (doc.documentId == documentId) {
          return doc.copyWith(isFavorite: !doc.isFavorite);
        }
        return doc;
      }).toList();
      state = state.copyWith(rawDocuments: updatedRaw);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Deletes a document either via recoverable soft-delete (DOC-013) or permanent purge (DOC-014).
  /// Immediately updates state so the UI reflects the removal instantaneously.
  Future<void> deleteDocument({
    required String documentId,
    String? ownerUid,
    bool permanently = false,
  }) async {
    try {
      if (permanently) {
        await docRepo.permanentlyDeleteDocument(documentId);
      } else {
        await docRepo.softDeleteDocument(documentId);
      }

      // Immediately filter out from in-memory rawDocuments
      final updatedRaw = state.rawDocuments
          .where((doc) => doc.documentId != documentId)
          .toList();
      state = state.copyWith(rawDocuments: updatedRaw);

      // Log zero-knowledge activity event
      if (activityRepo != null) {
        try {
          await activityRepo!.logEvent(
            ActivityEvent(
              activityId: const Uuid().v4(),
              actorUid: ownerUid ?? currentUserUid,
              targetDocumentId: documentId,
              eventType: ActivityEventType.documentDeleted,
              summary: permanently
                  ? 'Document permanently deleted'
                  : 'Document moved to trash',
              timestamp: DateTime.now().toUtc(),
            ),
          );
        } catch (_) {}
      }

      // Record tombstone in sync queue
      if (syncRepo != null) {
        try {
          final now = DateTime.now().toUtc();
          await syncRepo!.enqueue(
            SyncOperation(
              operationId: const Uuid().v4(),
              userId: ownerUid ?? currentUserUid,
              deviceId: 'device-local-1',
              operationType: SyncOperationType.delete,
              documentId: documentId,
              versionId: 'v-deleted',
              encryptedPayloadReference: '',
              status: SyncOperationStatus.queued,
              idempotencyKey:
                  '${documentId}_delete_${now.millisecondsSinceEpoch}',
              createdAt: now,
              updatedAt: now,
            ),
          );
        } catch (_) {}
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  /// Restores a soft-deleted document back to active status (DOC-013 Undo).
  Future<void> restoreDocument(String documentId) async {
    try {
      final doc = await docRepo.getDocumentById(documentId);
      if (doc != null && doc.isDeleted) {
        final restored = doc.copyWith(isDeleted: false);
        await docRepo.saveDocument(restored);
        await loadDocuments();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<UploadDocumentResult> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String category,
    String? description,
    List<String>? tags,
  }) async {
    state = state.copyWith(isUploading: true, errorMessage: null);
    try {
      final result = await uploadUseCase.execute(
        fileBytes: fileBytes,
        fileName: fileName,
        category: category,
        ownerUid: currentUserUid,
        description: description,
        tags: tags,
      );
      state = state.copyWith(isUploading: false);
      await loadDocuments();
      return result;
    } catch (e) {
      state = state.copyWith(isUploading: false, errorMessage: e.toString());
      rethrow;
    }
  }
}
