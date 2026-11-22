import '../../../security/domain/services/recovery_key_service.dart';

/// Key profile record matching DATABASE_SCHEMA.md Section 6.
/// Stores wrapped vault keys and public key identity material without ever exposing raw private keys.
class KeyProfile {
  final int schemaVersion;
  final String profileId;
  final String publicKey;
  final String publicKeyFingerprint;
  final String wrappedVaultKey;
  final String wrappingAlgorithm;
  final KdfDescriptor kdfDescriptor;
  final int keyEpoch;
  final DateTime createdAt;

  const KeyProfile({
    this.schemaVersion = 1,
    required this.profileId,
    required this.publicKey,
    required this.publicKeyFingerprint,
    required this.wrappedVaultKey,
    required this.wrappingAlgorithm,
    required this.kdfDescriptor,
    this.keyEpoch = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'publicKey': publicKey,
      'publicKeyFingerprint': publicKeyFingerprint,
      'wrappedVaultKey': wrappedVaultKey,
      'wrappingAlgorithm': wrappingAlgorithm,
      'kdfDescriptor': kdfDescriptor.toMap(),
      'keyEpoch': keyEpoch,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory KeyProfile.fromMap(Map<String, dynamic> map) {
    return KeyProfile(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      profileId: map['profileId'] as String,
      publicKey: map['publicKey'] as String,
      publicKeyFingerprint: map['publicKeyFingerprint'] as String,
      wrappedVaultKey: map['wrappedVaultKey'] as String,
      wrappingAlgorithm: map['wrappingAlgorithm'] as String,
      kdfDescriptor: KdfDescriptor.fromMap(
        map['kdfDescriptor'] as Map<String, dynamic>,
      ),
      keyEpoch: map['keyEpoch'] as int? ?? 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
