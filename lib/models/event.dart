import 'itinerary_day.dart';

// A festival/event shown in the app (e.g. "Manggahan Festival 2025").
class Event {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String municipality;
  final String coverImageUrl;
  final bool isPopular;
  final String description;
  // Day-by-day schedule shown in Event Details' "Itinerary" tab. Empty for
  // events that don't have one yet.
  final List<ItineraryDay> itinerary;

  const Event({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.municipality,
    required this.coverImageUrl,
    required this.isPopular,
    required this.description,
    this.itinerary = const [],
  });
}
