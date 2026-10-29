// How far a GPS position has strayed from a calculated route — used by
// TurnByTurnNavigationScreen to decide when to request a new route.
//
// latlong2 (already a dependency) only provides point-to-point distance,
// bearing, and offset (see Distance.dart) — no point-to-segment/path
// distance, so that part is written here. The actual meters measurement
// still goes through latlong2's Distance().distance(), not a hand-rolled
// haversine/vincenty formula: this file only adds the "find the nearest
// point on the route" geometry latlong2 doesn't have.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart' as ll;

import '../services/location_service.dart';

const ll.Distance _distance = ll.Distance();

// Meters per degree of latitude is ~constant; meters per degree of
// longitude shrinks toward the poles by cos(latitude). Fine as a local
// flat-plane approximation for finding the nearest point on a short (a few
// hundred meters, at most) route segment — Guimaras sits at ~10.6°N, where
// this introduces sub-meter error at the segment lengths involved. Only
// used to locate the projection point; the actual distance reported is
// still measured geodesically via latlong2 below.
const double _metersPerDegreeLat = 111320.0;

/// The shortest distance, in meters, from [point] to the nearest segment of
/// [route]. Returns `double.infinity` for an empty route (nothing to
/// deviate from).
double distanceToRoute(UserPosition point, List<UserPosition> route) {
  if (route.isEmpty) return double.infinity;
  if (route.length == 1) {
    return _distance.distance(_toLatLng(point), _toLatLng(route.first));
  }

  var shortest = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final d = _distanceToSegment(point, route[i], route[i + 1]);
    if (d < shortest) shortest = d;
  }
  return shortest;
}

double _distanceToSegment(UserPosition p, UserPosition a, UserPosition b) {
  final metersPerDegreeLng = _metersPerDegreeLat * math.cos(_toRadians(a.latitude));

  final ax = a.longitude * metersPerDegreeLng;
  final ay = a.latitude * _metersPerDegreeLat;
  final bx = b.longitude * metersPerDegreeLng;
  final by = b.latitude * _metersPerDegreeLat;
  final px = p.longitude * metersPerDegreeLng;
  final py = p.latitude * _metersPerDegreeLat;

  final abx = bx - ax;
  final aby = by - ay;
  final lengthSquared = abx * abx + aby * aby;

  final t = lengthSquared == 0
      ? 0.0
      : (((px - ax) * abx + (py - ay) * aby) / lengthSquared).clamp(0.0, 1.0);

  final closest = (
    latitude: a.latitude + t * (b.latitude - a.latitude),
    longitude: a.longitude + t * (b.longitude - a.longitude),
  );
  return _distance.distance(_toLatLng(p), _toLatLng(closest));
}

ll.LatLng _toLatLng(UserPosition p) => ll.LatLng(p.latitude, p.longitude);

double _toRadians(double degrees) => degrees * math.pi / 180;
