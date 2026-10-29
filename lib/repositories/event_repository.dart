import '../models/activity.dart';
import '../models/event.dart';
import '../models/municipality.dart';
import '../models/nearby_activity.dart';

// The contract every screen depends on. Screens must only ever import
// THIS file, never MockEventRepository or (later) SupabaseEventRepository
// directly — that's what lets us swap the data source without touching
// any screen.
abstract class EventRepository {
  Future<List<Event>> getUpcomingEvents();
  Future<List<Municipality>> getMunicipalities();
  Future<List<Activity>> getPopularActivities();
  Future<Event?> getEventById(String id);
  Future<Activity?> getActivityById(String id);
  Future<List<NearbyActivity>> getNearbyActivities(
    String activityId, {
    double radiusMeters = 1000,
    int maxResults = 10,
  });
}
