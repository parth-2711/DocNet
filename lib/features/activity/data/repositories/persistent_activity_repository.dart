import 'dart:async';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/repositories/activity_repository.dart';

/// Persistent implementation of ActivityRepository preserving security audit trail
/// events on-device across app restarts (PRD.md Section 6.12, AUDIT-001).
class PersistentActivityRepository implements ActivityRepository {
  final LocalVaultStorageService storageService;

  final List<ActivityEvent> _events = [];
  final StreamController<List<ActivityEvent>> _streamController =
      StreamController<List<ActivityEvent>>.broadcast();
  bool _loaded = false;

  PersistentActivityRepository(this.storageService);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('activity');
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            _events.add(ActivityEvent.fromFirestoreMap(item));
          }
        }
      }
    } catch (_) {
      // Ignore initial missing file
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final list = _events.map((e) => e.toFirestoreMap()).toList();
    await storageService.saveJson('activity', list);
  }

  @override
  Future<void> logEvent(ActivityEvent event) async {
    await _ensureLoaded();
    _events.insert(0, event);
    _streamController.add(List.unmodifiable(_events));
    await _persist();
  }

  @override
  Future<List<ActivityEvent>> getEvents({
    String? actorUid,
    String? familyId,
    ActivityEventType? eventType,
    int limit = 50,
  }) async {
    await _ensureLoaded();
    var filtered = _events.where((e) {
      if (actorUid != null && e.actorUid != actorUid) return false;
      if (familyId != null && e.familyId != familyId) return false;
      if (eventType != null && e.eventType != eventType) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }
    return List.unmodifiable(filtered);
  }

  @override
  Stream<List<ActivityEvent>> watchEvents({
    String? actorUid,
    String? familyId,
    ActivityEventType? eventType,
  }) {
    return _streamController.stream.map((list) {
      return list.where((e) {
        if (actorUid != null && e.actorUid != actorUid) return false;
        if (familyId != null && e.familyId != familyId) return false;
        if (eventType != null && e.eventType != eventType) return false;
        return true;
      }).toList();
    });
  }

  void dispose() {
    _streamController.close();
  }
}
