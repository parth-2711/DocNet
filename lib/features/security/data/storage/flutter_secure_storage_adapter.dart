import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/services/secure_storage_service.dart';

/// Production secure storage adapter configuring OS-specific protection:
/// - Android: Android Keystore + EncryptedSharedPreferences
/// - iOS: Apple Keychain
/// - Windows: Windows DPAPI (Data Protection API)
/// - macOS: Apple Keychain
/// - Linux: Secret Service API
class FlutterSecureStorageAdapter implements SecureStorageService {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            wOptions: WindowsOptions(useBackwardCompatibility: false),
          );

  @override
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  @override
  Future<bool> containsKey({required String key}) async {
    return await _storage.containsKey(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
