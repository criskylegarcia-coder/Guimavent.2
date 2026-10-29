import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getActivities(int eventId) async {
    final activityData = await _supabase
        .from('sub_activity')
        .select()
        .eq('event_id', eventId)
        .order('day_number')
        .order('start_time');

    final venueData = await _supabase.from('venue').select();

    final Map<int, Map<String, dynamic>> venueMap = {};

    for (final venue in venueData) {
      venueMap[venue['venue_id']] = Map<String, dynamic>.from(venue);
    }

    final activities = <Map<String, dynamic>>[];

    for (final item in activityData) {
      final activity = Map<String, dynamic>.from(item);
      final venue = venueMap[activity['venue_id'] as int];

      activity['venue_name'] = venue?['venue_name'];
      activity['latitude'] = venue?['latitude'];
      activity['longitude'] = venue?['longitude'];

      activities.add(activity);
    }

    return activities;
  }
}