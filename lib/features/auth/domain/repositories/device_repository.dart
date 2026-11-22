import '../entities/device_record.dart';

/// Repository contract for managing enrolled user devices (PRD.md Section 6.11 & DATABASE_SCHEMA.md Section 5).
abstract class DeviceRepository {
  /// Retrieves all devices enrolled by a user.
  Future<List<DeviceRecord>> getDevices(String uid);

  /// Retrieves a specific device record.
  Future<DeviceRecord?> getDevice({
    required String uid,
    required String deviceId,
  });

  /// Enrolls or updates a device record.
  Future<void> saveDevice({required String uid, required DeviceRecord device});

  /// Revokes an individual device (DEVICE-003, DEVICE-006).
  Future<void> revokeDevice({required String uid, required String deviceId});

  /// Revokes all enrolled devices for this user except the current active device (DEVICE-004).
  Future<void> revokeAllOtherDevices({
    required String uid,
    required String currentDeviceId,
  });
}
