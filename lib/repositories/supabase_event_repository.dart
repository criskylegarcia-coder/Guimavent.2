import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';
import '../models/event.dart';
import '../models/itinerary_day.dart';
import '../models/municipality.dart';
import '../models/nearby_activity.dart';
import '../utils/date_format.dart';
import 'event_repository.dart';
import 'repository_exception.dart';
import 'supabase_row_mappers.dart';

// Real, Supabase-backed EventRepository. See MockEventRepository for the
// mock this replaces — screens never reference either directly, only the
// abstract EventRepository.
//
// Assumption worth verifying once this is exercised live: `event` and
// `sub_activity` are joined to `municipality`/`event`/`venue` below via
// PostgREST's embed syntax (e.g. `municipality(municipality_name)`), which
// requires a real foreign-key constraint between the tables. Column
// existence was confirmed earlier; the FK constraints themselves weren't.
// If a query fails with "Could not find a relationship between X and Y",
// that FK is what's missing.
class SupabaseEventRepository implements EventRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // How many activities getPopularActivities() returns — see
  // getPopularActivities() for what "popular" means here.
  static const int _popularActivitiesLimit = 6;

  @override
  Future<List<Event>> getUpcomingEvents() async {
    try {
      // ascending: true is required, not just documentation — the
      // postgrest package's order() defaults to ascending: false
      // (descending), the opposite of what its name suggests and of what
      // every .order() call in this codebase actually wants. Confirmed via
      // package:postgrest source (PostgrestTransformBuilder.order) after
      // this exact gap silently reversed the Itinerary tab's day/activity
      // ordering — every .order() call in this file (and several other
      // repositories) needed this same explicit fix.
      final rows = await _client
          .from('event')
          .select(eventSelectWithJoins)
          .order('start_date', ascending: true);
      return [for (final row in rows) eventFromRow(row)];
    } catch (e) {
      throw RepositoryException('Could not load events: $e');
    }
  }

  @override
  Future<List<Municipality>> getMunicipalities() async {
    try {
      final rows = await _client
          .from('municipality')
          .select()
          .order('municipality_name', ascending: true);
      return [
        for (final row in rows)
          Municipality(
            id: row['municipality_id'].toString(),
            name: row['municipality_name'] as String,
            iconAsset:
                'assets/icons/${(row['municipality_name'] as String).toLowerCase().replaceAll(' ', '_')}.png',
          ),
      ];
    } catch (e) {
      throw RepositoryException('Could not load municipalities: $e');
    }
  }

  @override
  Future<List<Activity>> getPopularActivities() async {
    // No popularity/featured signal exists on sub_activity yet — the
    // soonest-upcoming activities across all events stand in for "popular"
    // until a real signal (e.g. derived from favorite/schedule counts)
    // exists.
    try {
      final rows = await _client
          .from('sub_activity')
          .select(subActivitySelectWithJoins)
          .order('start_time', ascending: true)
          .limit(_popularActivitiesLimit);
      return [for (final row in rows) activityFromRow(row)];
    } catch (e) {
      throw RepositoryException('Could not load popular activities: $e');
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    final start = DateTime.now();
    try {
      final eventId = int.tryParse(id);
      if (eventId == null) return null;

      // Independent queries — neither needs the other's result — so both
      // fire at once instead of stacking their round-trips sequentially.
      final eventFuture = _client
          .from('event')
          .select(eventSelectWithJoins)
          .eq('event_id', eventId)
          .maybeSingle()
          .then((row) {
            debugPrint(
              '[SupabaseEventRepository] event query: '
              '${DateTime.now().difference(start).inMilliseconds}ms',
            );
            return row;
          });
      final itineraryFuture = _getItineraryForEvent(eventId).then((
        itinerary,
      ) {
        debugPrint(
          '[SupabaseEventRepository] itinerary query: '
          '${DateTime.now().difference(start).inMilliseconds}ms '
          '(${itinerary.length} days, '
          '${itinerary.fold(0, (n, d) => n + d.activities.length)} activities)',
        );
        return itinerary;
      });

      final results = await Future.wait([eventFuture, itineraryFuture]);
      final row = results[0] as Map<String, dynamic>?;
      final itinerary = results[1] as List<ItineraryDay>;
      if (row == null) return null;

      debugPrint(
        '[SupabaseEventRepository] getEventById total (parallel): '
        '${DateTime.now().difference(start).inMilliseconds}ms',
      );
      return eventFromRow(row, itinerary: itinerary);
    } catch (e) {
      throw RepositoryException('Could not load event: $e');
    }
  }

  @override
  Future<Activity?> getActivityById(String id) async {
    final start = DateTime.now();
    try {
      final subactivityId = int.tryParse(id);
      if (subactivityId == null) return null;

      final row = await _client
          .from('sub_activity')
          .select(subActivitySelectWithJoins)
          .eq('subactivity_id', subactivityId)
          .maybeSingle();
      debugPrint(
        '[SupabaseEventRepository] getActivityById query: '
        '${DateTime.now().difference(start).inMilliseconds}ms',
      );
      if (row == null) return null;
      return activityFromRow(row);
    } catch (e) {
      throw RepositoryException('Could not load activity: $e');
    }
  }

  @override
  Future<List<NearbyActivity>> getNearbyActivities(
    String activityId, {
    double radiusMeters = 1000,
    int maxResults = 10,
  }) async {
    final start = DateTime.now();
    try {
      final subactivityId = int.tryParse(activityId);
      if (subactivityId == null) return [];

      final rows = await _client.rpc(
        'nearby_activities',
        params: {
          'p_activity_id': subactivityId,
          'p_radius_meters': radiusMeters,
          'p_max_results': maxResults,
        },
      );
      debugPrint(
        '[SupabaseEventRepository] getNearbyActivities RPC: '
        '${DateTime.now().difference(start).inMilliseconds}ms '
        '(${(rows as List).length} rows)',
      );
      return [
        for (final row in rows)
          nearbyActivityFromRow(row as Map<String, dynamic>),
      ];
    } catch (e) {
      throw RepositoryException('Could not load nearby activities: $e');
    }
  }

  // getUpcomingEvents() deliberately leaves itinerary empty — nothing reads
  // it from that list today (only getEventById's detail view does), so
  // fetching it there avoids an extra query per event in the list.
  Future<List<ItineraryDay>> _getItineraryForEvent(int eventId) async {
    final rows = await _client
        .from('sub_activity')
        .select(subActivitySelectWithJoins)
        .eq('event_id', eventId)
        .order('day_number', ascending: true)
        .order('start_time', ascending: true);

    final byDay = <int, List<Activity>>{};
    for (final row in rows) {
      final dayNumber = row['day_number'] as int;
      byDay.putIfAbsent(dayNumber, () => []).add(activityFromRow(row));
    }

    final dayNumbers = byDay.keys.toList()..sort();
    return [
      for (final dayNumber in dayNumbers)
        ItineraryDay(
          dayLabel:
              'Day $dayNumber - ${formatSingleDate(byDay[dayNumber]!.first.activityDate)}',
          date: byDay[dayNumber]!.first.activityDate,
          activities: byDay[dayNumber]!,
        ),
    ];
  }
}
