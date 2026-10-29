// The contract map screens depend on for real route calculation. Screens
// must only ever import THIS file, never MapboxDirectionsService directly —
// mirrors location_service.dart and the repository pattern used elsewhere.

import 'location_service.dart';

/// A calculated route for a given [TravelMode]. [geometry] is the ordered
/// list of points tracing the path, for drawing as a line on the map.
typedef TravelRoute = ({
  double distanceMeters,
  double durationSeconds,
  List<UserPosition> geometry,
});

/// The transport mode a route is calculated for — maps directly to one of
/// Mapbox's Directions API profiles.
enum TravelMode {
  walking('mapbox/walking'),
  cycling('mapbox/cycling'),
  driving('mapbox/driving');

  const TravelMode(this.mapboxProfile);

  /// The Directions API profile segment, e.g. "mapbox/walking".
  final String mapboxProfile;
}

abstract class DirectionsService {
  /// Requests a [mode] route from [from] to [to]. Returns null if no route
  /// could be calculated — network failure, API error, or genuinely no
  /// route found — never throws. Callers should fall back to
  /// mockWalkEstimate and a marker-only map (no line) when null.
  Future<TravelRoute?> getRoute({
    required UserPosition from,
    required UserPosition to,
    required TravelMode mode,
  });
}
