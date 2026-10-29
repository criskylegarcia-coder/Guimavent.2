import '../models/activity.dart';
import '../models/event.dart';
import '../models/itinerary_day.dart';
import '../models/municipality.dart';
import '../models/nearby_activity.dart';
import 'event_repository.dart';

// Hardcoded data so the UI has something to show before Supabase is wired
// up. Later, create a SupabaseEventRepository that implements the same
// EventRepository contract and swap it in where MockEventRepository is
// created — no screen code needs to change.
//
// _events and _popularActivities are built once and reused by every method
// below (including the by-id lookups), so there's only ever one copy of
// each hardcoded Event/Activity.
class MockEventRepository implements EventRepository {
  static final List<Event> _events = [
    Event(
      id: 'evt-1',
      name: 'Manggahan Festival 2025',
      startDate: DateTime(2025, 5, 1),
      endDate: DateTime(2025, 5, 3),
      municipality: 'Nueva Valencia',
      coverImageUrl: 'https://picsum.photos/seed/manggahan/600/400',
      isPopular: true,
      description:
          "Guimaras' biggest celebration of its world-famous sweet mangoes: "
          'three days of street dancing, a mango trade fair, live music, '
          'and food stalls across Nueva Valencia.',
      itinerary: [
        ItineraryDay(
          dayLabel: 'Day 1 - May 1, 2025',
          date: DateTime(2025, 5, 1),
          activities: [
            Activity(
              id: 'itin-1-1',
              eventId: 'evt-1',
              title: 'Opening Ceremony',
              activityDate: DateTime(2025, 5, 1),
              startTime: '8:00 AM',
              endTime: '9:00 AM',
              venue: 'Municipal Plaza',
              imageUrl: 'https://picsum.photos/seed/manggahan-open/600/400',
              description:
                  'The official start of Manggahan Festival 2025, with a '
                  'welcome address from the mayor and a ribbon-cutting at '
                  'the Municipal Plaza.',
            ),
            Activity(
              id: 'itin-1-2',
              eventId: 'evt-1',
              title: 'Street Dancing Parade',
              activityDate: DateTime(2025, 5, 1),
              startTime: '9:30 AM',
              endTime: '12:00 PM',
              venue: 'Poblacion, Nueva Valencia',
              imageUrl: 'https://picsum.photos/seed/manggahan-parade/600/400',
              description:
                  'Contingents from every barangay dance through the '
                  'streets of Poblacion in mango-themed costumes.',
            ),
            Activity(
              id: 'itin-1-3',
              eventId: 'evt-1',
              title: 'Mango Exhibit & Trade Fair',
              activityDate: DateTime(2025, 5, 1),
              startTime: '1:00 PM',
              endTime: '5:00 PM',
              venue: 'NV Cultural Center',
              imageUrl: 'https://picsum.photos/seed/manggahan-fair/600/400',
              description:
                  'Local growers and vendors showcase mango produce and '
                  'products, from fresh fruit to mango wine and preserves.',
            ),
            Activity(
              id: 'itin-1-4',
              eventId: 'evt-1',
              title: 'Live Band Night',
              activityDate: DateTime(2025, 5, 1),
              startTime: '7:00 PM',
              endTime: '10:00 PM',
              venue: 'Municipal Plaza',
              imageUrl: 'https://picsum.photos/seed/manggahan-band/600/400',
              description:
                  'Local bands close out Day 1 with a free concert at the '
                  'Municipal Plaza.',
            ),
          ],
        ),
        ItineraryDay(
          dayLabel: 'Day 2 - May 2, 2025',
          date: DateTime(2025, 5, 2),
          activities: [
            Activity(
              id: 'itin-2-1',
              eventId: 'evt-1',
              title: 'Mango Cooking Contest',
              activityDate: DateTime(2025, 5, 2),
              startTime: '9:00 AM',
              endTime: '12:00 PM',
              venue: 'NV Cultural Center',
              imageUrl:
                  'https://picsum.photos/seed/manggahan-cooking/600/400',
              description:
                  'Home cooks and local chefs compete to create the best '
                  'mango-inspired dish.',
            ),
            Activity(
              id: 'itin-2-2',
              eventId: 'evt-1',
              title: 'Sports Fest',
              activityDate: DateTime(2025, 5, 2),
              startTime: '2:00 PM',
              endTime: '6:00 PM',
              venue: 'Nueva Valencia Gym',
              imageUrl: 'https://picsum.photos/seed/manggahan-sports/600/400',
              description:
                  'Friendly barangay-versus-barangay games at the Nueva '
                  'Valencia Gym.',
            ),
          ],
        ),
        ItineraryDay(
          dayLabel: 'Day 3 - May 3, 2025',
          date: DateTime(2025, 5, 3),
          activities: [
            Activity(
              id: 'itin-3-1',
              eventId: 'evt-1',
              title: 'Closing Ceremony & Fireworks',
              activityDate: DateTime(2025, 5, 3),
              startTime: '7:00 PM',
              endTime: '9:00 PM',
              venue: 'Municipal Plaza',
              imageUrl:
                  'https://picsum.photos/seed/manggahan-closing/600/400',
              description:
                  'Awarding of festival winners followed by a fireworks '
                  'display over the Municipal Plaza.',
            ),
          ],
        ),
      ],
    ),
    Event(
      id: 'evt-2',
      name: 'Balsahan Festival 2025',
      startDate: DateTime(2025, 4, 25),
      endDate: DateTime(2025, 4, 27),
      municipality: 'Buenavista',
      coverImageUrl: 'https://picsum.photos/seed/balsahan/600/400',
      isPopular: false,
      description:
          "A tribute to Buenavista's fishing and boat-building heritage, "
          'featuring bamboo raft (balsa) races along the coast.',
    ),
    Event(
      id: 'evt-3',
      name: 'Asinan Festival',
      startDate: DateTime(2025, 1, 12),
      endDate: DateTime(2025, 1, 12),
      municipality: 'Jordan',
      coverImageUrl: 'https://picsum.photos/seed/asinan/600/400',
      isPopular: true,
      description:
          "Jordan's one-day celebration of traditional salt-making, with "
          'demonstrations at the historic Jordan salt beds.',
    ),
  ];

  static final List<Activity> _popularActivities = [
    Activity(
      id: 'act-1',
      eventId: 'evt-1',
      title: 'Mango Harvest Tour',
      activityDate: DateTime(2025, 5, 1),
      startTime: '9:00 AM',
      endTime: '11:00 AM',
      venue: 'Nueva Valencia Plaza',
      imageUrl: 'https://picsum.photos/seed/activity1/600/400',
      description:
          'A guided walk through a working mango orchard, with a tasting '
          'stop at the end.',
    ),
    Activity(
      id: 'act-2',
      eventId: 'evt-2',
      title: 'Balsa Boat Race',
      activityDate: DateTime(2025, 4, 26),
      startTime: '1:00 PM',
      endTime: '4:00 PM',
      venue: 'Buenavista Riverside',
      imageUrl: 'https://picsum.photos/seed/activity2/600/400',
      description:
          'Teams race hand-built bamboo rafts along the Buenavista '
          'coastline.',
    ),
    Activity(
      id: 'act-3',
      eventId: 'evt-3',
      title: 'Salt Making Demo',
      activityDate: DateTime(2025, 1, 12),
      startTime: '8:00 AM',
      endTime: '10:00 AM',
      venue: 'Jordan Salt Beds',
      imageUrl: 'https://picsum.photos/seed/activity3/600/400',
      description:
          'Local salt farmers demonstrate the traditional sun-evaporation '
          'process still used in Jordan today.',
    ),
  ];

  @override
  Future<List<Event>> getUpcomingEvents() async => _events;

  @override
  Future<List<Municipality>> getMunicipalities() async {
    return const [
      Municipality(
        id: 'buenavista',
        name: 'Buenavista',
        iconAsset: 'assets/icons/buenavista.png',
      ),
      Municipality(
        id: 'jordan',
        name: 'Jordan',
        iconAsset: 'assets/icons/jordan.png',
      ),
      Municipality(
        id: 'nueva_valencia',
        name: 'Nueva Valencia',
        iconAsset: 'assets/icons/nueva_valencia.png',
      ),
      Municipality(
        id: 'san_lorenzo',
        name: 'San Lorenzo',
        iconAsset: 'assets/icons/san_lorenzo.png',
      ),
      Municipality(
        id: 'sibunag',
        name: 'Sibunag',
        iconAsset: 'assets/icons/sibunag.png',
      ),
    ];
  }

  // Fixed fake dataset for the "Nearby Activities" section — ids match real
  // activities elsewhere in this mock repo, so tapping through to one still
  // resolves to a real detail screen in main_preview.dart.
  static const List<NearbyActivity> _nearbyActivities = [
    NearbyActivity(
      activityId: 'act-2',
      activityName: 'Balsa Boat Race',
      eventId: 'evt-2',
      eventName: 'Balsahan Festival 2025',
      venueName: 'Buenavista Riverside',
      distanceMeters: 180,
    ),
    NearbyActivity(
      activityId: 'act-3',
      activityName: 'Salt Making Demo',
      eventId: 'evt-3',
      eventName: 'Asinan Festival',
      venueName: 'Jordan Salt Beds',
      distanceMeters: 640,
    ),
    NearbyActivity(
      activityId: 'itin-1-3',
      activityName: 'Mango Exhibit & Trade Fair',
      eventId: 'evt-1',
      eventName: 'Manggahan Festival 2025',
      venueName: 'NV Cultural Center',
      distanceMeters: 1450,
    ),
  ];

  @override
  Future<List<Activity>> getPopularActivities() async => _popularActivities;

  @override
  Future<Event?> getEventById(String id) async {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<Activity?> getActivityById(String id) async {
    for (final activity in _popularActivities) {
      if (activity.id == id) return activity;
    }
    for (final event in _events) {
      for (final day in event.itinerary) {
        for (final activity in day.activities) {
          if (activity.id == id) return activity;
        }
      }
    }
    return null;
  }

  @override
  Future<List<NearbyActivity>> getNearbyActivities(
    String activityId, {
    double radiusMeters = 1000,
    int maxResults = 10,
  }) async {
    final results = [
      for (final activity in _nearbyActivities)
        if (activity.activityId != activityId) activity,
    ];
    return results.take(maxResults).toList();
  }
}
