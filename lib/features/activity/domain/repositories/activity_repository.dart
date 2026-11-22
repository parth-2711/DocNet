import '../entities/activity_event.dart';

/// Repository interface for security audit events (PRD.md Section 6.12, DATABASE_SCHEMA.md Section 3).
abstract class ActivityRepository {
  /// Records a new security or audit event.
  Future<void> logEvent(ActivityEvent event);

  /// Retrieves events filtered by family, actor, or event type, ordered chronologically descending.
  Future<List<ActivityEvent>> getEvents({
    String? familyId,
    String? actorUid,
    ActivityEventType? eventType,
    int limit = 50,
  });

  /// Real-time stream of audit events.
  Stream<List<ActivityEvent>> watchEvents({String? familyId, String? actorUid});
}
