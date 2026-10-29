// A sub_activity near another activity's venue, as returned by the
// nearby_activities Postgres RPC (see
// supabase/migrations/20260807000000_add_postgis_venue_spatial_search.sql).
class NearbyActivity {
  final String activityId;
  final String activityName;
  final String eventId;
  final String eventName;
  final String venueName;
  final double distanceMeters;

  const NearbyActivity({
    required this.activityId,
    required this.activityName,
    required this.eventId,
    required this.eventName,
    required this.venueName,
    required this.distanceMeters,
  });
}
