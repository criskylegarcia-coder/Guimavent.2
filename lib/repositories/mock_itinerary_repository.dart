import '../models/activity.dart';
import '../models/itinerary_entry.dart';
import 'event_repository.dart';
import 'itinerary_repository.dart';
import 'mock_event_repository.dart';

// Sample "My Schedule" data built on top of the same mock Events/Activities
// used elsewhere in the app (see MockEventRepository), so the two mock
// repositories never disagree about what an activity looks like.
class MockItineraryRepository implements ItineraryRepository {
  final EventRepository _eventRepository = MockEventRepository();

  // static so state is shared across every MockItineraryRepository instance
  // different screens create (each screen makes its own), rather than each
  // screen having its own disconnected copy. In-memory only — resets
  // whenever the app restarts. Real persistence comes with a
  // backend-backed repository later.
  static final Set<String> _favoriteActivityIds = {};
  static final Set<String> _favoriteEventIds = {};
  // All of Manggahan Festival's sample activities start scheduled, matching
  // this mock's previous (unconditional) demo behavior — but genuinely
  // toggleable now, unlike before.
  static final Set<String> _scheduledActivityIds = {
    'itin-1-1',
    'itin-1-2',
    'itin-1-3',
    'itin-1-4',
    'itin-2-1',
    'itin-2-2',
    'itin-3-1',
  };

  @override
  Future<List<ItineraryEntry>> getMySchedule() async {
    final events = await _eventRepository.getUpcomingEvents();
    final manggahan = events.firstWhere((event) => event.id == 'evt-1');
    return [
      for (final day in manggahan.itinerary)
        for (final activity in day.activities)
          if (_scheduledActivityIds.contains(activity.id))
            ItineraryEntry(
              activityId: activity.id,
              activity: activity,
              date: activity.activityDate,
              addedAt: DateTime(2025, 4, 20),
            ),
    ];
  }

  @override
  Future<bool> toggleFavorite(String activityId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_favoriteActivityIds.contains(activityId)) {
      _favoriteActivityIds.remove(activityId);
      return false;
    }
    _favoriteActivityIds.add(activityId);
    return true;
  }

  @override
  Future<bool> isFavorited(String activityId) async {
    return _favoriteActivityIds.contains(activityId);
  }

  @override
  Future<void> addToSchedule(Activity activity) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _scheduledActivityIds.add(activity.id);
  }

  @override
  Future<bool> isScheduled(String activityId) async {
    return _scheduledActivityIds.contains(activityId);
  }

  @override
  Future<void> removeFromSchedule(String activityId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _scheduledActivityIds.remove(activityId);
  }

  @override
  Future<bool> toggleEventFavorite(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds.remove(eventId);
      return false;
    }
    _favoriteEventIds.add(eventId);
    return true;
  }

  @override
  Future<bool> isEventFavorited(String eventId) async {
    return _favoriteEventIds.contains(eventId);
  }
}
