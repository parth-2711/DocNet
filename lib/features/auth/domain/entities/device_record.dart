/// Device enrollment record matching DATABASE_SCHEMA.md Section 5.
class DeviceRecord {
  final int schemaVersion;
  final String deviceId;
  final String platform;
  final String deviceLabel;
  final String devicePublicKey;
  final String keyFingerprint;
  final String status;
  final DateTime enrolledAt;
  final DateTime lastSeenAt;
  final DateTime? lastAcknowledgedSyncAt;
  final DateTime? revokedAt;
  final String appVersion;

  const DeviceRecord({
    this.schemaVersion = 1,
    required this.deviceId,
    required this.platform,
    required this.deviceLabel,
    required this.devicePublicKey,
    required this.keyFingerprint,
    this.status = 'active',
    required this.enrolledAt,
    required this.lastSeenAt,
    this.lastAcknowledgedSyncAt,
    this.revokedAt,
    this.appVersion = '1.0.0',
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'deviceId': deviceId,
      'platform': platform,
      'deviceLabel': deviceLabel,
      'devicePublicKey': devicePublicKey,
      'keyFingerprint': keyFingerprint,
      'status': status,
      'enrolledAt': enrolledAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'lastAcknowledgedSyncAt': lastAcknowledgedSyncAt?.toIso8601String(),
      'revokedAt': revokedAt?.toIso8601String(),
      'appVersion': appVersion,
    };
  }

  factory DeviceRecord.fromMap(Map<String, dynamic> map) {
    return DeviceRecord(
      schemaVersion: map['schemaVersion'] as int? ?? 1,
      deviceId: map['deviceId'] as String,
      platform: map['platform'] as String,
      deviceLabel: map['deviceLabel'] as String,
      devicePublicKey: map['devicePublicKey'] as String,
      keyFingerprint: map['keyFingerprint'] as String,
      status: map['status'] as String? ?? 'active',
      enrolledAt: DateTime.parse(map['enrolledAt'] as String),
      lastSeenAt: DateTime.parse(map['lastSeenAt'] as String),
      lastAcknowledgedSyncAt: map['lastAcknowledgedSyncAt'] != null
          ? DateTime.parse(map['lastAcknowledgedSyncAt'] as String)
          : null,
      revokedAt: map['revokedAt'] != null
          ? DateTime.parse(map['revokedAt'] as String)
          : null,
      appVersion: map['appVersion'] as String? ?? '1.0.0',
    );
  }

  DeviceRecord copyWith({
    String? deviceLabel,
    String? status,
    DateTime? lastSeenAt,
    DateTime? lastAcknowledgedSyncAt,
    DateTime? revokedAt,
    String? appVersion,
  }) {
    return DeviceRecord(
      schemaVersion: schemaVersion,
      deviceId: deviceId,
      platform: platform,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      devicePublicKey: devicePublicKey,
      keyFingerprint: keyFingerprint,
      status: status ?? this.status,
      enrolledAt: enrolledAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastAcknowledgedSyncAt:
          lastAcknowledgedSyncAt ?? this.lastAcknowledgedSyncAt,
      revokedAt: revokedAt ?? this.revokedAt,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}
