/// Family Space entity matching DATABASE_SCHEMA.md Section 7.
class FamilySpace {
  final int schemaVersion;
  final String familyId;
  final String name;
  final String ownerUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;
  final int keyEpoch;
  final String? currentGroupPublicKey;

  const FamilySpace({
    this.schemaVersion = 1,
    required this.familyId,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 1,
    this.keyEpoch = 1,
    this.currentGroupPublicKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'familyId': familyId,
      'name': name,
      'ownerUid': ownerUid,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'memberCount': memberCount,
      'keyEpoch': keyEpoch,
      'currentGroupPublicKey': currentGroupPublicKey,
    };
  }

  factory FamilySpace.fromMap(Map<String, dynamic> map) {
    return FamilySpace(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      familyId: map['familyId'] as String,
      name: map['name'] as String,
      ownerUid: map['ownerUid'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      memberCount: map['memberCount'] as int? ?? 1,
      keyEpoch: map['keyEpoch'] as int? ?? 1,
      currentGroupPublicKey: map['currentGroupPublicKey'] as String?,
    );
  }

  FamilySpace copyWith({
    String? name,
    DateTime? updatedAt,
    int? memberCount,
    int? keyEpoch,
    String? currentGroupPublicKey,
  }) {
    return FamilySpace(
      schemaVersion: schemaVersion,
      familyId: familyId,
      name: name ?? this.name,
      ownerUid: ownerUid,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      memberCount: memberCount ?? this.memberCount,
      keyEpoch: keyEpoch ?? this.keyEpoch,
      currentGroupPublicKey:
          currentGroupPublicKey ?? this.currentGroupPublicKey,
    );
  }
}
