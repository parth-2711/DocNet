/// Typed user profile entity matching DATABASE_SCHEMA.md Section 4.
class UserProfile {
  final int schemaVersion;
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoRef;
  final String accountStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? defaultFamilyId;
  final String language;
  final String themeMode;
  final bool onboardingCompleted;
  final String? keyProfileId;
  final bool biometricsEnabled;

  const UserProfile({
    this.schemaVersion = 1,
    required this.uid,
    this.displayName,
    this.email,
    this.photoRef,
    this.accountStatus = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.defaultFamilyId,
    this.language = 'en',
    this.themeMode = 'system',
    this.onboardingCompleted = false,
    this.keyProfileId,
    this.biometricsEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoRef': photoRef,
      'accountStatus': accountStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'defaultFamilyId': defaultFamilyId,
      'language': language,
      'themeMode': themeMode,
      'onboardingCompleted': onboardingCompleted,
      'keyProfileId': keyProfileId,
      'biometricsEnabled': biometricsEnabled,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      uid: map['uid'] as String,
      displayName: map['displayName'] as String?,
      email: map['email'] as String?,
      photoRef: map['photoRef'] as String?,
      accountStatus: map['accountStatus'] as String? ?? 'active',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      defaultFamilyId: map['defaultFamilyId'] as String?,
      language: map['language'] as String? ?? 'en',
      themeMode: map['themeMode'] as String? ?? 'system',
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      keyProfileId: map['keyProfileId'] as String?,
      biometricsEnabled: map['biometricsEnabled'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoRef,
    String? accountStatus,
    DateTime? updatedAt,
    String? defaultFamilyId,
    String? language,
    String? themeMode,
    bool? onboardingCompleted,
    String? keyProfileId,
    bool? biometricsEnabled,
  }) {
    return UserProfile(
      schemaVersion: schemaVersion,
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoRef: photoRef ?? this.photoRef,
      accountStatus: accountStatus ?? this.accountStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      defaultFamilyId: defaultFamilyId ?? this.defaultFamilyId,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      keyProfileId: keyProfileId ?? this.keyProfileId,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    );
  }

  /// Returns a clean, user-friendly display name.
  /// If [displayName] is null, empty, or a legacy placeholder ("Vault User"),
  /// derives a formatted name from the email (e.g. "parth.godhani" -> "Parth Godhani").
  String get effectiveDisplayName {
    final name = displayName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        name.toLowerCase() != 'vault user' &&
        name.toLowerCase() != 'google account user' &&
        name.toLowerCase() != 'google user' &&
        name.toLowerCase() != 'user') {
      return name;
    }
    if (email != null && email!.contains('@')) {
      final prefix = email!.split('@').first;
      final parts = prefix.split(RegExp(r'[._\-]'));
      final formatted = parts
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : ''))
          .join(' ');
      if (formatted.isNotEmpty) return formatted;
    }
    return 'User';
  }

  /// Returns the real email, never a dummy/legacy placeholder.
  String? get effectiveEmail {
    final e = email?.trim();
    if (e == null || e.isEmpty) return null;
    if (e == 'user@familyvault.app') return null;
    if (e == 'google.user@familyvault.app') return null;
    if (e.endsWith('@familyvault.app')) return null;
    return e;
  }
}
