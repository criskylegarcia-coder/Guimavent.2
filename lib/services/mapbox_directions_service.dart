import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/mapbox_config.dart';
import 'directions_service.dart';
import 'location_service.dart';

// Real, HTTP-backed DirectionsService. Calls Mapbox's Directions API
// directly (https://docs.mapbox.com/api/navigation/directions/) — this is a
// separate REST API from the mapbox_maps_flutter SDK used for rendering,
// but uses the SAME public access token (confirmed live: the Directions API
// accepts the pk.* public token same as map rendering does — no separate
// secret token is needed here, unlike the Android SDK's Maven download
// token).
class MapboxDirectionsService implements DirectionsService {
  MapboxDirectionsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<TravelRoute?> getRoute({
    required UserPosition from,
    required UserPosition to,
    required TravelMode mode,
  }) async {
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/${mode.mapboxProfile}/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {
        'geometries': 'geojson',
        'overview': 'full',
        'access_token': mapboxAccessToken,
      },
    );

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      return (
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
        geometry: [
          for (final point in coordinates)
            (
              latitude: (point[1] as num).toDouble(),
              longitude: (point[0] as num).toDouble(),
            ),
        ],
      );
    } catch (_) {
      // Covers network failure, timeout, malformed response, and the API's
      // own "no route found" error payloads — a failed route just means
      // "fall back to the mock estimate", never a crash.
      return null;
    }
  }
}
