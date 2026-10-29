import 'activity.dart';

// One activity the user has added to "My Schedule", shown grouped by date
// on the My Itinerary screen.
class ItineraryEntry {
  final String activityId;
  final Activity activity;
  final DateTime date;
  final DateTime addedAt;

  const ItineraryEntry({
    required this.activityId,
    required this.activity,
    required this.date,
    required this.addedAt,
  });
}
