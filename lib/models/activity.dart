// A single activity that belongs to an Event (e.g. a mango tour that's
// part of the Manggahan Festival). startTime/endTime are kept as plain
// strings (like "9:00 AM") since that's how a future API will send them.
class Activity {
  final String id;
  final String eventId;
  final String title;
  final DateTime activityDate;
  final String startTime;
  final String endTime;
  final String venue;
  final String imageUrl;
  final String description;
  // The venue's map coordinates, for Mapbox rendering (Map & Directions).
  // Nullable — not required so every existing Activity(...) call site
  // (mocks, kept tests) keeps compiling unchanged; null just means "no
  // real coordinates available yet" for that activity.
  final double? latitude;
  final double? longitude;

  const Activity({
    required this.id,
    required this.eventId,
    required this.title,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.imageUrl,
    required this.description,
    this.latitude,
    this.longitude,
  });
}
