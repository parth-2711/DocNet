import '../../domain/entities/device_record.dart';
import '../../domain/repositories/device_repository.dart';

/// In-memory implementation of DeviceRepository for local operation and testing.
class InMemoryDeviceRepository implements DeviceRepository {
  // uid -> Map of deviceId -> DeviceRecord
  final Map<String, Map<String, DeviceRecord>> _userDevices = {};

  @override
  Future<List<DeviceRecord>> getDevices(String uid) async {
    final devices = _userDevices[uid]?.values.toList() ?? [];
    devices.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return List.unmodifiable(devices);
  }

  @override
  Future<DeviceRecord?> getDevice({
    required String uid,
    required String deviceId,
  }) async {
    return _userDevices[uid]?[deviceId];
  }

  @override
  Future<void> saveDevice({
    required String uid,
    required DeviceRecord device,
  }) async {
    _userDevices.putIfAbsent(uid, () => {})[device.deviceId] = device;
  }

  @override
  Future<void> revokeDevice({
    required String uid,
    required String deviceId,
  }) async {
    final existing = _userDevices[uid]?[deviceId];
    if (existing != null) {
      _userDevices[uid]![deviceId] = existing.copyWith(
        status: 'revoked',
        revokedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<void> revokeAllOtherDevices({
    required String uid,
    required String currentDeviceId,
  }) async {
    final map = _userDevices[uid];
    if (map == null) return;

    final now = DateTime.now().toUtc();
    for (final entry in map.entries) {
      if (entry.key != currentDeviceId && entry.value.status != 'revoked') {
        map[entry.key] = entry.value.copyWith(
          status: 'revoked',
          revokedAt: now,
        );
      }
    }
  }
}
