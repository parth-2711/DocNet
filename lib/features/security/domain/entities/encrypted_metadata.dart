import 'dart:convert';
import 'dart:typed_data';

/// Encrypted metadata container for protecting document names, descriptions,
/// user-defined tags, and OCR text from Firebase disclosure (ENCRYPTION.md Section 5).
class EncryptedMetadata {
  final int formatVersion;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List macTag;

  const EncryptedMetadata({
    this.formatVersion = 1,
    required this.nonce,
    required this.cipherText,
    required this.macTag,
  });

  /// Converts the encrypted payload into a map suitable for Firestore storage.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'formatVersion': formatVersion,
      'nonce': base64Encode(nonce),
      'cipherText': base64Encode(cipherText),
      'macTag': base64Encode(macTag),
    };
  }

  /// Reconstructs the container from a Firestore map.
  factory EncryptedMetadata.fromFirestoreMap(Map<String, dynamic> map) {
    return EncryptedMetadata(
      formatVersion: map['formatVersion'] as int? ?? 1,
      nonce: base64Decode(map['nonce'] as String),
      cipherText: base64Decode(map['cipherText'] as String),
      macTag: base64Decode(map['macTag'] as String),
    );
  }
}
