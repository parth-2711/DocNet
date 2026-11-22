import '../../domain/services/secure_storage_service.dart';

/// In-memory secure storage adapter for unit tests and headless environments.
class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _memoryStore = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _memoryStore[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _memoryStore[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _memoryStore.remove(key);
  }

  @override
  Future<bool> containsKey({required String key}) async {
    return _memoryStore.containsKey(key);
  }

  @override
  Future<void> deleteAll() async {
    _memoryStore.clear();
  }

  /// Helper for inspecting stored keys count in tests
  int get count => _memoryStore.length;
}
