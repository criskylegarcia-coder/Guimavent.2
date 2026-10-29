import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';
import '../models/itinerary_entry.dart';
import 'itinerary_repository.dart';
import 'repository_exception.dart';
import 'supabase_row_mappers.dart';

// Real, Supabase-backed ItineraryRepository, covering My Schedule
// (itinerary_items) and activity favorites (favorites, with
// target_type='activity' only). RSVP (the rsvp table) was removed from
// scope — the table itself is left alone (not dropped), the app just no
// longer reads/writes it.
class SupabaseItineraryRepository implements ItineraryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const RepositoryException('You must be signed in.');
    }
    return id;
  }

  @override
  Future<List<ItineraryEntry>> getMySchedule() async {
    final start = DateTime.now();
    debugPrint('[SupabaseItineraryRepository] getMySchedule: start');
    try {
      final userId = _requireUserId;
      final rows = await _client
          .from('itinerary_items')
          .select('*, sub_activity($subActivitySelectWithJoins)')
          .eq('user_id', userId)
          // ascending: true required — package:postgrest's order() defaults
          // to descending; see supabase_event_repository.dart's
          // getUpcomingEvents() for the full explanation.
          .order('event_date', ascending: true);
      debugPrint(
        '[SupabaseItineraryRepository] getMySchedule: query returned after '
        '${DateTime.now().difference(start).inMilliseconds}ms (${rows.length} rows)',
      );
      final entries = [
        for (final row in rows) itineraryEntryFromRow(row),
      ].whereType<ItineraryEntry>().toList();
      debugPrint(
        '[SupabaseItineraryRepository] getMySchedule: mapping done, total '
        '${DateTime.now().difference(start).inMilliseconds}ms',
      );
      return entries;
    } catch (e) {
      debugPrint(
        '[SupabaseItineraryRepository] getMySchedule: threw after '
        '${DateTime.now().difference(start).inMilliseconds}ms — $e',
      );
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not load your schedule: $e');
    }
  }

  @override
  Future<bool> toggleFavorite(String activityId) =>
      _toggleFavorite(targetType: 'activity', targetId: activityId);

  @override
  Future<bool> isFavorited(String activityId) =>
      _isFavorited(targetType: 'activity', targetId: activityId);

  @override
  Future<bool> toggleEventFavorite(String eventId) =>
      _toggleFavorite(targetType: 'event', targetId: eventId);

  @override
  Future<bool> isEventFavorited(String eventId) =>
      _isFavorited(targetType: 'event', targetId: eventId);

  @override
  Future<void> addToSchedule(Activity activity) async {
    try {
      final userId = _requireUserId;
      final row = {
        'user_id': userId,
        'event_id': int.parse(activity.eventId),
        'subactivity_id': int.parse(activity.id),
        'title': activity.title,
        'venue': activity.venue,
        'event_date': formatDateForSupabase(activity.activityDate),
      };
      debugPrint('[SupabaseItineraryRepository] addToSchedule: inserting $row');
      final inserted = await _client
          .from('itinerary_items')
          .insert(row)
          .select();
      debugPrint(
        '[SupabaseItineraryRepository] addToSchedule: insert returned $inserted',
      );
    } catch (e) {
      debugPrint('[SupabaseItineraryRepository] addToSchedule: threw — $e');
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not add to your schedule: $e');
    }
  }

  @override
  Future<void> removeFromSchedule(String activityId) async {
    try {
      final userId = _requireUserId;
      final subactivityId = int.tryParse(activityId);
      if (subactivityId == null) return;
      debugPrint(
        '[SupabaseItineraryRepository] removeFromSchedule: deleting '
        'activityId=$activityId',
      );
      await _client
          .from('itinerary_items')
          .delete()
          .eq('user_id', userId)
          .eq('subactivity_id', subactivityId);
    } catch (e) {
      debugPrint('[SupabaseItineraryRepository] removeFromSchedule: threw — $e');
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not remove from your schedule: $e');
    }
  }

  @override
  Future<bool> isScheduled(String activityId) async {
    try {
      final userId = _requireUserId;
      final subactivityId = int.tryParse(activityId);
      if (subactivityId == null) return false;
      final row = await _client
          .from('itinerary_items')
          .select('id')
          .eq('user_id', userId)
          .eq('subactivity_id', subactivityId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not check schedule status: $e');
    }
  }

  Future<bool> _isFavorited({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final userId = _requireUserId;
      final row = await _client
          .from('favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not check favorite status: $e');
    }
  }

  Future<bool> _toggleFavorite({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final userId = _requireUserId;
      final alreadyFavorited = await _isFavorited(
        targetType: targetType,
        targetId: targetId,
      );
      if (alreadyFavorited) {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('target_type', targetType)
            .eq('target_id', targetId);
        return false;
      }
      await _client.from('favorites').insert({
        'user_id': userId,
        'target_type': targetType,
        'target_id': targetId,
      });
      return true;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not update favorite: $e');
    }
  }
}
