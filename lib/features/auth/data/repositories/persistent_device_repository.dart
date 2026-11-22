import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/device_record.dart';
import '../../domain/repositories/device_repository.dart';

/// Persistent implementation of DeviceRepository saving device enrollment
/// records directly to on-device storage across app sessions (PRD.md Section 6.11).
class PersistentDeviceRepository implements DeviceRepository {
  final LocalVaultStorageService storageService;

  final Map<String, List<DeviceRecord>> _userDevices = {};
  bool _loaded = false;

  PersistentDeviceRepository(this.storageService);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('devices');
      if (data is Map<String, dynamic>) {
        data.forEach((uid, list) {
          if (list is List) {
            _userDevices[uid] = list
                .whereType<Map<String, dynamic>>()
                .map((m) => DeviceRecord.fromMap(m))
                .toList();
          }
        });
      }
    } catch (_) {
      // Ignore initial missing file
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final map = <String, dynamic>{};
    _userDevices.forEach((uid, list) {
      map[uid] = list.map((d) => d.toMap()).toList();
    });
    await storageService.saveJson('devices', map);
  }

  @override
  Future<List<DeviceRecord>> getDevices(String uid) async {
    await _ensureLoaded();
    return List.unmodifiable(_userDevices[uid] ?? []);
  }

  @override
  Future<DeviceRecord?> getDevice({
    required String uid,
    required String deviceId,
  }) async {
    await _ensureLoaded();
    final list = _userDevices[uid] ?? [];
    try {
      return list.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDevice({
    required String uid,
    required DeviceRecord device,
  }) async {
    await _ensureLoaded();
    final list = _userDevices.putIfAbsent(uid, () => []);
    list.removeWhere((d) => d.deviceId == device.deviceId);
    list.add(device);
    await _persist();
  }

  @override
  Future<void> revokeDevice({
    required String uid,
    required String deviceId,
  }) async {
    await _ensureLoaded();
    final list = _userDevices[uid];
    if (list != null) {
      final index = list.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        list[index] = list[index].copyWith(
          status: 'revoked',
          revokedAt: DateTime.now().toUtc(),
        );
        await _persist();
      }
    }
  }

  @override
  Future<void> revokeAllOtherDevices({
    required String uid,
    required String currentDeviceId,
  }) async {
    await _ensureLoaded();
    final list = _userDevices[uid];
    if (list != null) {
      final now = DateTime.now().toUtc();
      for (var i = 0; i < list.length; i++) {
        if (list[i].deviceId != currentDeviceId && list[i].status == 'active') {
          list[i] = list[i].copyWith(status: 'revoked', revokedAt: now);
        }
      }
      await _persist();
    }
  }
}
