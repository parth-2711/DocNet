import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/persistent_activity_repository.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/repositories/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final storageService = ref.watch(localVaultStorageServiceProvider);
  final repo = PersistentActivityRepository(storageService);
  ref.onDispose(repo.dispose);
  return repo;
});

class ActivityState {
  final List<ActivityEvent> events;
  final String filter;
  final bool isLoading;
  final String? errorMessage;

  const ActivityState({
    this.events = const [],
    this.filter = 'All',
    this.isLoading = false,
    this.errorMessage,
  });

  List<ActivityEvent> get filteredEvents {
    if (filter == 'All') return events;
    return events.where((e) {
      switch (filter) {
        case 'Documents':
          return e.eventType == ActivityEventType.documentCreated ||
              e.eventType == ActivityEventType.documentReplaced ||
              e.eventType == ActivityEventType.documentDeleted ||
              e.eventType == ActivityEventType.documentRestored ||
              e.eventType == ActivityEventType.documentExported;
        case 'Sharing':
          return e.eventType == ActivityEventType.shareGranted ||
              e.eventType == ActivityEventType.shareRevoked;
        case 'Spaces':
        case 'Family':
          return e.eventType == ActivityEventType.familyCreated ||
              e.eventType == ActivityEventType.familyInvitationSent ||
              e.eventType == ActivityEventType.familyMemberJoined ||
              e.eventType == ActivityEventType.familyMemberRemoved ||
              e.eventType == ActivityEventType.familyRoleUpdated;
        case 'Security':
          return e.eventType == ActivityEventType.signIn ||
              e.eventType == ActivityEventType.signOut ||
              e.eventType == ActivityEventType.deviceEnrolled ||
              e.eventType == ActivityEventType.deviceRevoked ||
              e.eventType == ActivityEventType.recoveryPhraseGenerated ||
              e.eventType == ActivityEventType.recoveryPhraseVerified;
        default:
          return true;
      }
    }).toList();
  }

  ActivityState copyWith({
    List<ActivityEvent>? events,
    String? filter,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ActivityState(
      events: events ?? this.events,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final activityControllerProvider =
    StateNotifierProvider<ActivityController, ActivityState>((ref) {
      final repo = ref.watch(activityRepositoryProvider);
      final authState = ref.watch(authControllerProvider);
      final uid = authState.userProfile?.uid;
      return ActivityController(
        activityRepository: repo,
        currentUserUid: uid,
      );
    });

class ActivityController extends StateNotifier<ActivityState> {
  final ActivityRepository activityRepository;
  final String? currentUserUid;

  ActivityController({
    required this.activityRepository,
    this.currentUserUid,
  }) : super(const ActivityState()) {
    loadEvents();
  }

  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final events = await activityRepository.getEvents(
        actorUid: currentUserUid,
      );
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> logEvent(ActivityEvent event) async {
    try {
      await activityRepository.logEvent(event);
      await loadEvents();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}
