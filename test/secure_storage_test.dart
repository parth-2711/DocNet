import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/security/data/storage/in_memory_secure_storage.dart';

void main() {
  late InMemorySecureStorage storage;

  setUp(() {
    storage = InMemorySecureStorage();
  });

  group('SecureStorageService Tests', () {
    test('Writes and reads secret value', () async {
      await storage.write(key: 'vault_key', value: 'secret_hex_123');
      final value = await storage.read(key: 'vault_key');
      expect(value, equals('secret_hex_123'));
    });

    test('Returns null for missing key', () async {
      final value = await storage.read(key: 'non_existent');
      expect(value, isNull);
    });

    test('Checks key existence accurately', () async {
      expect(await storage.containsKey(key: 'device_private_key'), isFalse);
      await storage.write(key: 'device_private_key', value: 'priv_key_xyz');
      expect(await storage.containsKey(key: 'device_private_key'), isTrue);
    });

    test('Deletes key correctly', () async {
      await storage.write(key: 'temp_key', value: '12345');
      await storage.delete(key: 'temp_key');
      expect(await storage.containsKey(key: 'temp_key'), isFalse);
      expect(await storage.read(key: 'temp_key'), isNull);
    });

    test('Clears all keys on deleteAll', () async {
      await storage.write(key: 'k1', value: 'v1');
      await storage.write(key: 'k2', value: 'v2');
      expect(storage.count, equals(2));

      await storage.deleteAll();
      expect(storage.count, equals(0));
      expect(await storage.read(key: 'k1'), isNull);
      expect(await storage.read(key: 'k2'), isNull);
    });
  });
}
