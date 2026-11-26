/// Key envelope record matching DATABASE_SCHEMA.md Section 11.
/// Binds document DEK wrapped for recipient or owner key material.
class KeyEnvelope {
  final int schemaVersion;
  final String envelopeId;
  final String documentId;
  final String recipientType; // 'user' or 'familyGroup'
  final String recipientId; // UID or familyId
  final String? recipientEmail; // Normalized email for cross-device matching
  final String wrappedDek; // Base64 wrapped key
  final String wrappingAlgorithm;
  final int keyEpoch;
  final DateTime createdAt;

  const KeyEnvelope({
    this.schemaVersion = 1,
    required this.envelopeId,
    required this.documentId,
    required this.recipientType,
    required this.recipientId,
    this.recipientEmail,
    required this.wrappedDek,
    required this.wrappingAlgorithm,
    this.keyEpoch = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'schemaVersion': schemaVersion,
      'envelopeId': envelopeId,
      'documentId': documentId,
      'recipientType': recipientType,
      'recipientId': recipientId,
      if (recipientEmail != null) 'recipientEmail': recipientEmail,
      'wrappedDek': wrappedDek,
      'wrappingAlgorithm': wrappingAlgorithm,
      'keyEpoch': keyEpoch,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory KeyEnvelope.fromFirestoreMap(Map<String, dynamic> map) {
    return KeyEnvelope(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      envelopeId: map['envelopeId'] as String,
      documentId: map['documentId'] as String,
      recipientType: map['recipientType'] as String,
      recipientId: map['recipientId'] as String,
      recipientEmail: (map['recipientEmail'] as String?)?.toLowerCase(),
      wrappedDek: map['wrappedDek'] as String,
      wrappingAlgorithm: map['wrappingAlgorithm'] as String,
      keyEpoch: map['keyEpoch'] as int? ?? 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
