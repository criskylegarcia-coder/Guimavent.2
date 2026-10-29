import 'activity.dart';

// One day of an Event's itinerary, shown as one accordion row in the
// Event Details "Itinerary" tab — e.g. "Day 1 - May 1, 2025" with its
// activities in the order they happen.
class ItineraryDay {
  final String dayLabel;
  final DateTime date;
  final List<Activity> activities;

  const ItineraryDay({
    required this.dayLabel,
    required this.date,
    required this.activities,
  });
}
