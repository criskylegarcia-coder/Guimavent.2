import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_exception.dart';

// One sub_activity row, admin-shape — raw eventId/venueId (not just the
// joined display names) so the edit form can pre-select the right dropdown
// items, same reasoning as AdminVenue/AdminEvent.
class AdminActivity {
  final String id;
  final String eventId;
  final String eventName;
  final String venueId;
  final String venueName;
  final int dayNumber;
  final String activityName;
  final String description;
  final DateTime startTime;
  final DateTime endTime;

  const AdminActivity({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.venueId,
    required this.venueName,
    required this.dayNumber,
    required this.activityName,
    required this.description,
    required this.startTime,
    required this.endTime,
  });
}

// Admin-only writes for `sub_activity`. Split out from AdminEventRepository/
// AdminVenueRepository, same reasoning as Batch 2's venue split — a
// genuinely different concern, kept focused.
abstract class AdminActivityRepository {
  Future<List<AdminActivity>> getAllActivities();

  Future<void> createActivity({
    required String eventId,
    required String venueId,
    required int dayNumber,
    required String activityName,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  });

  Future<void> updateActivity(
    String activityId, {
    required String eventId,
    required String venueId,
    required int dayNumber,
    required String activityName,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  });

  Future<void> deleteActivity(String activityId);

  /// How many itinerary_items rows currently reference this activity.
  /// Unlike venue deletion (sub_activity.venue_id has no ON DELETE clause,
  /// so Postgres' default NO ACTION rejects the delete outright),
  /// itinerary_items.subactivity_id is `ON DELETE SET NULL` (confirmed via
  /// the migration that added it) — deleting an activity is NEVER rejected
  /// by this FK, it just silently detaches those rows. This count is purely
  /// informational, so staff know how many users' schedules will lose this
  /// entry, not a "this may fail" warning like the venue dialog's.
  Future<int> countReferencingItineraryItems(String activityId);
}

class SupabaseAdminActivityRepository implements AdminActivityRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<AdminActivity>> getAllActivities() async {
    try {
      final rows = await _client
          .from('sub_activity')
          .select('*, event(event_name), venue(venue_name)')
          // ascending: true required — package:postgrest's order() defaults
          // to descending; see supabase_event_repository.dart's
          // getUpcomingEvents() for the full explanation.
          .order('start_time', ascending: true);
      return [for (final row in rows) _adminActivityFromRow(row)];
    } catch (e) {
      throw RepositoryException('Could not load activities: $e');
    }
  }

  @override
  Future<void> createActivity({
    required String eventId,
    required String venueId,
    required int dayNumber,
    required String activityName,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      await _client.from('sub_activity').insert({
        'event_id': int.parse(eventId),
        'venue_id': int.parse(venueId),
        'day_number': dayNumber,
        'activity_name': activityName,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      });
    } catch (e) {
      throw RepositoryException('Could not create activity: $e');
    }
  }

  @override
  Future<void> updateActivity(
    String activityId, {
    required String eventId,
    required String venueId,
    required int dayNumber,
    required String activityName,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final activityIdInt = int.parse(activityId);
      await _client
          .from('sub_activity')
          .update({
            'event_id': int.parse(eventId),
            'venue_id': int.parse(venueId),
            'day_number': dayNumber,
            'activity_name': activityName,
            'description': description,
            'start_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
          })
          .eq('subactivity_id', activityIdInt);
    } catch (e) {
      throw RepositoryException('Could not update activity: $e');
    }
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    try {
      final activityIdInt = int.parse(activityId);
      await _client.from('sub_activity').delete().eq('subactivity_id', activityIdInt);
    } catch (e) {
      throw RepositoryException('Could not delete activity: $e');
    }
  }

  @override
  Future<int> countReferencingItineraryItems(String activityId) async {
    try {
      final activityIdInt = int.parse(activityId);
      final rows = await _client
          .from('itinerary_items')
          .select('id')
          .eq('subactivity_id', activityIdInt);
      return rows.length;
    } catch (e) {
      throw RepositoryException('Could not check activity references: $e');
    }
  }

  AdminActivity _adminActivityFromRow(Map<String, dynamic> row) {
    final event = row['event'] as Map<String, dynamic>?;
    final venue = row['venue'] as Map<String, dynamic>?;
    return AdminActivity(
      id: row['subactivity_id'].toString(),
      eventId: row['event_id'].toString(),
      eventName: event?['event_name'] as String? ?? '',
      venueId: row['venue_id'].toString(),
      venueName: venue?['venue_name'] as String? ?? '',
      dayNumber: row['day_number'] as int,
      activityName: row['activity_name'] as String,
      description: row['description'] as String? ?? '',
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: DateTime.parse(row['end_time'] as String),
    );
  }
}

// For tests/previews — no real Supabase connection needed.
class MockAdminActivityRepository implements AdminActivityRepository {
  // id -> name, so created/updated activities can show real event/venue
  // names the same way the Supabase implementation's joins would.
  final Map<String, String> eventNames;
  final Map<String, String> venueNames;
  final List<AdminActivity> _activities;
  // Simulates which activities have referencing itinerary_items rows, for
  // testing the delete-warning flow without a real DB.
  final Set<String> referencedActivityIds;
  int _nextId;

  MockAdminActivityRepository({
    required this.eventNames,
    required this.venueNames,
    List<AdminActivity>? seedActivities,
    Set<String>? referencedActivityIds,
  }) : _activities = seedActivities ?? [],
       referencedActivityIds = referencedActivityIds ?? {},
       _nextId = 1000;

  @override
  Future<List<AdminActivity>> getAllActivities() async =>
      List.unmodifiable(_activities);

  @override
  Future<void> createActivity({
    required String eventId,
    required String venueId,
    required int dayNumber,
    required String activityName,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _activities.add(
      AdminActivity(
        id: (_nextId++).toString(),
        eventId: eventId,
        eventName: eventNames[eventId] ?? '',
        venueId: venueId,
        venueName: venueNames[venueId] ?? '',
        dayNumber: dayNumber,
        activityName: activityName,
        description: description,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  @override
  Future<void> updateActivity(
    String activityId, {
    required String eventId,
    required String venueId,
    required int dayNumber,
    required String activityName,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index == -1) {
      throw const RepositoryException('Activity not found.');
    }
    _activities[index] = AdminActivity(
      id: activityId,
      eventId: eventId,
      eventName: eventNames[eventId] ?? '',
      venueId: venueId,
      venueName: venueNames[venueId] ?? '',
      dayNumber: dayNumber,
      activityName: activityName,
      description: description,
      startTime: startTime,
      endTime: endTime,
    );
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _activities.removeWhere((a) => a.id == activityId);
  }

  @override
  Future<int> countReferencingItineraryItems(String activityId) async {
    return referencedActivityIds.contains(activityId) ? 1 : 0;
  }
}
