/// Family roles defined in PRD.md FAM-007.
enum FamilyRole { owner, admin, member, viewer }

/// Family member record matching DATABASE_SCHEMA.md Section 8.
class FamilyMember {
  final int schemaVersion;
  final String uid;
  final String familyId;
  final String displayName;
  final String email;
  final FamilyRole role;
  final DateTime joinedAt;
  final String? invitedBy;
  final String status; // 'active' or 'suspended'
  final String? devicePublicKey;
  final String? keyFingerprint;

  const FamilyMember({
    this.schemaVersion = 1,
    required this.uid,
    required this.familyId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    this.status = 'active',
    this.devicePublicKey,
    this.keyFingerprint,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'uid': uid,
      'familyId': familyId,
      'displayName': displayName,
      'email': email,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy,
      'status': status,
      'devicePublicKey': devicePublicKey,
      'keyFingerprint': keyFingerprint,
    };
  }

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      uid: map['uid'] as String,
      familyId: map['familyId'] as String,
      displayName: map['displayName'] as String? ?? 'Family Member',
      email: map['email'] as String? ?? '',
      role: FamilyRole.values.byName(map['role'] as String? ?? 'member'),
      joinedAt: DateTime.parse(map['joinedAt'] as String),
      invitedBy: map['invitedBy'] as String?,
      status: map['status'] as String? ?? 'active',
      devicePublicKey: map['devicePublicKey'] as String?,
      keyFingerprint: map['keyFingerprint'] as String?,
    );
  }
}
