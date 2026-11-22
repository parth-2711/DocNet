import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/auth/domain/entities/device_record.dart';
import 'package:docnet/features/auth/domain/entities/key_profile.dart';
import 'package:docnet/features/auth/domain/entities/user_profile.dart';
import 'package:docnet/features/security/domain/services/recovery_key_service.dart';

void main() {
  group('Auth & Profile Domain Models Tests', () {
    test('UserProfile serializes to and from map accurately', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0);
      final profile = UserProfile(
        uid: 'uid-parth',
        email: 'parth@example.com',
        displayName: 'Parth Godhani',
        accountStatus: 'active',
        createdAt: now,
        updatedAt: now,
        language: 'gu',
        themeMode: 'dark',
        onboardingCompleted: true,
        keyProfileId: 'kp-1',
      );

      final map = profile.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.uid, equals('uid-parth'));
      expect(restored.displayName, equals('Parth Godhani'));
      expect(restored.email, equals('parth@example.com'));
      expect(restored.language, equals('gu'));
      expect(restored.themeMode, equals('dark'));
      expect(restored.onboardingCompleted, isTrue);
      expect(restored.keyProfileId, equals('kp-1'));
    });

    test('DeviceRecord serializes to and from map accurately', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0);
      final device = DeviceRecord(
        deviceId: 'dev-win-100',
        platform: 'windows',
        deviceLabel: 'Windows Desktop',
        devicePublicKey: 'base64pubkey',
        keyFingerprint: 'fp123',
        status: 'active',
        enrolledAt: now,
        lastSeenAt: now,
      );

      final map = device.toMap();
      final restored = DeviceRecord.fromMap(map);

      expect(restored.deviceId, equals('dev-win-100'));
      expect(restored.platform, equals('windows'));
      expect(restored.deviceLabel, equals('Windows Desktop'));
      expect(restored.status, equals('active'));
    });

    test('KeyProfile serializes to and from map accurately', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0);
      const kdf = KdfDescriptor(
        algorithm: 'Argon2id',
        saltBase64: 'c2FsdA==',
        iterations: 100000,
        memoryCostKb: 65536,
        parallelism: 1,
        keyLength: 32,
      );

      final keyProfile = KeyProfile(
        profileId: 'kp-999',
        publicKey: 'pubKeyBase64',
        publicKeyFingerprint: 'sha256fingerprint',
        wrappedVaultKey: 'wrappedVaultKeyBase64',
        wrappingAlgorithm: 'AES-KW',
        kdfDescriptor: kdf,
        keyEpoch: 1,
        createdAt: now,
      );

      final map = keyProfile.toMap();
      final restored = KeyProfile.fromMap(map);

      expect(restored.profileId, equals('kp-999'));
      expect(restored.wrappedVaultKey, equals('wrappedVaultKeyBase64'));
      expect(restored.kdfDescriptor.algorithm, equals('Argon2id'));
    });
  });
}
