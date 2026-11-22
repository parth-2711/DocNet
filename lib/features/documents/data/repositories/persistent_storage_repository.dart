import 'dart:typed_data';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/repositories/storage_repository.dart';

/// Persistent implementation of StorageRepository saving encrypted binary objects
/// directly to the on-device secure file system (PRD.md DOC-017, SYNC_ENGINE.md Section 6).
class PersistentStorageRepository implements StorageRepository {
  final LocalVaultStorageService storageService;

  PersistentStorageRepository(this.storageService);

  @override
  Future<void> putObject({
    required String objectRef,
    required Uint8List data,
  }) async {
    await storageService.saveObject(objectRef, data);
  }

  @override
  Future<Uint8List?> getObject(String objectRef) async {
    return await storageService.getObject(objectRef);
  }

  @override
  Future<bool> objectExists(String objectRef) async {
    return await storageService.objectExists(objectRef);
  }

  @override
  Future<void> deleteObject(String objectRef) async {
    await storageService.deleteObject(objectRef);
  }

  @override
  Future<void> clearAll() async {
    // Retained for tests and reset workflows
  }
}
