import 'dart:async';
import '../../domain/entities/activity_event.dart';
import '../../domain/repositories/activity_repository.dart';

/// In-memory implementation of [ActivityRepository] for testing and local operation.
class InMemoryActivityRepository implements ActivityRepository {
  final List<ActivityEvent> _events = [];
  final StreamController<List<ActivityEvent>> _controller =
      StreamController<List<ActivityEvent>>.broadcast();

  @override
  Future<void> logEvent(ActivityEvent event) async {
    _events.insert(0, event); // Most recent first
    _controller.add(List.unmodifiable(_events));
  }

  @override
  Future<List<ActivityEvent>> getEvents({
    String? familyId,
    String? actorUid,
    ActivityEventType? eventType,
    int limit = 50,
  }) async {
    var filtered = _events.where((e) {
      if (familyId != null && e.familyId != familyId) return false;
      if (actorUid != null && e.actorUid != actorUid) return false;
      if (eventType != null && e.eventType != eventType) return false;
      return true;
    }).toList();

    if (filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }
    return List.unmodifiable(filtered);
  }

  @override
  Stream<List<ActivityEvent>> watchEvents({
    String? familyId,
    String? actorUid,
  }) {
    return _controller.stream.map((events) {
      return events.where((e) {
        if (familyId != null && e.familyId != familyId) return false;
        if (actorUid != null && e.actorUid != actorUid) return false;
        return true;
      }).toList();
    });
  }

  void dispose() {
    _controller.close();
  }
}
