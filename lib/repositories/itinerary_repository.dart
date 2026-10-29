import '../models/activity.dart';
import '../models/itinerary_entry.dart';

// The contract MyItineraryShellScreen depends on. Screens must only ever
// import THIS file, never MockItineraryRepository or (later) a
// SupabaseItineraryRepository directly.
abstract class ItineraryRepository {
  Future<List<ItineraryEntry>> getMySchedule();

  /// Toggles whether an activity is favorited and returns the new state
  /// (true = now favorited). Used only by MapDirectionsShellScreen's own
  /// heart — NOT the same state as My Schedule (isScheduled) below, despite
  /// both being activity-related. See the note on isScheduled.
  Future<bool> toggleFavorite(String activityId);
  Future<bool> isFavorited(String activityId);

  /// Adds an activity to the user's My Schedule.
  Future<void> addToSchedule(Activity activity);

  /// Removes an activity from the user's My Schedule.
  Future<void> removeFromSchedule(String activityId);

  /// Whether the given activity is already in the user's My Schedule. This
  /// IS "favoriting" an activity on ActivityDetailsShellScreen and the My
  /// Schedule list — the heart icon and "Add to Itinerary" both
  /// drive/reflect this one state there.
  Future<bool> isScheduled(String activityId);

  /// Toggles whether an event (not activity — see toggleFavorite above) is
  /// saved and returns the new state (true = now saved). Backed by the
  /// same `favorites` table, with target_type='event'. Used by Event
  /// Details' save/bookmark action.
  Future<bool> toggleEventFavorite(String eventId);
  Future<bool> isEventFavorited(String eventId);
}
