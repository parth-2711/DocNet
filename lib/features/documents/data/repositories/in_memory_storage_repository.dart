import 'dart:typed_data';
import '../../domain/repositories/storage_repository.dart';

/// In-memory storage repository for local development, tests, and offline encrypted cache.
class InMemoryStorageRepository implements StorageRepository {
  final Map<String, Uint8List> _storage = {};

  @override
  Future<void> putObject({
    required String objectRef,
    required Uint8List data,
  }) async {
    _storage[objectRef] = data;
  }

  @override
  Future<Uint8List?> getObject(String objectRef) async {
    return _storage[objectRef];
  }

  @override
  Future<bool> objectExists(String objectRef) async {
    return _storage.containsKey(objectRef);
  }

  @override
  Future<void> deleteObject(String objectRef) async {
    _storage.remove(objectRef);
  }

  @override
  Future<void> syncObjectToCloud(String objectRef) async {}

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  int get objectCount => _storage.length;
}
