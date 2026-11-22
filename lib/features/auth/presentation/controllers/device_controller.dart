import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../activity/domain/entities/activity_event.dart';
import '../../../activity/presentation/controllers/activity_controller.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../data/repositories/persistent_device_repository.dart';
import '../../domain/entities/device_record.dart';
import '../../domain/repositories/device_repository.dart';
import 'auth_controller.dart';

class DeviceState {
  final List<DeviceRecord> devices;
  final String currentDeviceId;
  final bool isLoading;
  final String? errorMessage;

  const DeviceState({
    this.devices = const [],
    this.currentDeviceId = 'device-local-1',
    this.isLoading = false,
    this.errorMessage,
  });

  DeviceState copyWith({
    List<DeviceRecord>? devices,
    String? currentDeviceId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  return PersistentDeviceRepository(storageService);
});

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, DeviceState>((ref) {
      final repo = ref.watch(deviceRepositoryProvider);
      final authState = ref.watch(authControllerProvider);
      final activityRepo = ref.watch(activityRepositoryProvider);
      final uid = authState.userProfile?.uid ?? 'guest-uid';

      return DeviceController(
        deviceRepository: repo,
        activityRepository: activityRepo,
        currentUid: uid,
      );
    });

class DeviceController extends StateNotifier<DeviceState> {
  final DeviceRepository deviceRepository;
  final dynamic activityRepository;
  final String currentUid;

  DeviceController({
    required this.deviceRepository,
    required this.activityRepository,
    required this.currentUid,
  }) : super(const DeviceState()) {
    initDefaultDevice();
  }

  /// Ensures current device is enrolled and loads device list.
  Future<void> initDefaultDevice() async {
    state = state.copyWith(isLoading: true);
    final now = DateTime.now().toUtc();
    final currentDevice = DeviceRecord(
      deviceId: state.currentDeviceId,
      platform: 'Windows / Flutter Client',
      deviceLabel: 'This Device (Primary)',
      devicePublicKey: 'x25519-pk-local',
      keyFingerprint: 'SHA256:fp-local',
      enrolledAt: now,
      lastSeenAt: now,
    );

    await deviceRepository.saveDevice(uid: currentUid, device: currentDevice);
    await loadDevices();
  }

  Future<void> loadDevices() async {
    try {
      final list = await deviceRepository.getDevices(currentUid);
      state = state.copyWith(devices: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> renameDevice(String deviceId, String newLabel) async {
    try {
      final device = await deviceRepository.getDevice(
        uid: currentUid,
        deviceId: deviceId,
      );
      if (device != null) {
        final updated = device.copyWith(deviceLabel: newLabel);
        await deviceRepository.saveDevice(uid: currentUid, device: updated);
        await loadDevices();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> revokeDevice(String deviceId) async {
    try {
      await deviceRepository.revokeDevice(uid: currentUid, deviceId: deviceId);
      if (activityRepository != null) {
        await activityRepository.logEvent(
          ActivityEvent(
            activityId: const Uuid().v4(),
            actorUid: currentUid,
            eventType: ActivityEventType.deviceRevoked,
            summary: 'Device revoked from vault access',
            metadata: {'deviceId': deviceId},
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }
      await loadDevices();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> revokeAllOtherDevices() async {
    try {
      await deviceRepository.revokeAllOtherDevices(
        uid: currentUid,
        currentDeviceId: state.currentDeviceId,
      );
      if (activityRepository != null) {
        await activityRepository.logEvent(
          ActivityEvent(
            activityId: const Uuid().v4(),
            actorUid: currentUid,
            eventType: ActivityEventType.deviceRevoked,
            summary: 'All other authorized devices revoked',
            metadata: {'retainedDeviceId': state.currentDeviceId},
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }
      await loadDevices();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
