import '../entities/family_member.dart';

/// Status of a family invitation.
enum InvitationStatus { pending, accepted, declined, canceled }

/// Family invitation entity representing an invite to join a family space.
class FamilyInvitation {
  final int schemaVersion;
  final String invitationId;
  final String familyId;
  final String familyName;
  final String inviterUid;
  final String inviterDisplayName;
  final String inviterEmail;
  final String recipientEmail;
  final String? recipientUid;
  final String? recipientDisplayName;
  final FamilyRole role;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const FamilyInvitation({
    this.schemaVersion = 1,
    required this.invitationId,
    required this.familyId,
    required this.familyName,
    required this.inviterUid,
    required this.inviterDisplayName,
    required this.inviterEmail,
    required this.recipientEmail,
    this.recipientUid,
    this.recipientDisplayName,
    this.role = FamilyRole.member,
    this.status = InvitationStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'invitationId': invitationId,
      'familyId': familyId,
      'familyName': familyName,
      'inviterUid': inviterUid,
      'inviterDisplayName': inviterDisplayName,
      'inviterEmail': inviterEmail,
      'recipientEmail': recipientEmail,
      'recipientUid': recipientUid,
      'recipientDisplayName': recipientDisplayName,
      'role': role.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  factory FamilyInvitation.fromMap(Map<String, dynamic> map) {
    return FamilyInvitation(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      invitationId: map['invitationId'] as String,
      familyId: map['familyId'] as String,
      familyName: map['familyName'] as String? ?? 'Family Space',
      inviterUid: map['inviterUid'] as String,
      inviterDisplayName:
          map['inviterDisplayName'] as String? ?? 'Family Admin',
      inviterEmail: map['inviterEmail'] as String? ?? '',
      recipientEmail: (map['recipientEmail'] as String? ?? '').toLowerCase(),
      recipientUid: map['recipientUid'] as String?,
      recipientDisplayName: map['recipientDisplayName'] as String?,
      role: FamilyRole.values.byName(map['role'] as String? ?? 'member'),
      status: InvitationStatus.values.byName(
        map['status'] as String? ?? 'pending',
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      respondedAt: map['respondedAt'] != null
          ? DateTime.parse(map['respondedAt'] as String)
          : null,
    );
  }

  FamilyInvitation copyWith({
    String? invitationId,
    String? familyId,
    String? familyName,
    String? inviterUid,
    String? inviterDisplayName,
    String? inviterEmail,
    String? recipientEmail,
    String? recipientUid,
    String? recipientDisplayName,
    FamilyRole? role,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return FamilyInvitation(
      schemaVersion: schemaVersion,
      invitationId: invitationId ?? this.invitationId,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      inviterUid: inviterUid ?? this.inviterUid,
      inviterDisplayName: inviterDisplayName ?? this.inviterDisplayName,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientUid: recipientUid ?? this.recipientUid,
      recipientDisplayName: recipientDisplayName ?? this.recipientDisplayName,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}
