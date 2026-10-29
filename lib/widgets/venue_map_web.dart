import 'package:flutter/material.dart';

import '../services/location_service.dart' show UserPosition;
import 'placeholder_map.dart';
import 'venue_map_controller.dart';

// Web implementation of VenueMap — see venue_map.dart for why this exists
// separately from venue_map_native.dart. Keeps the Batch 1 PlaceholderMap
// behavior unchanged; real Mapbox rendering (venue marker, live user
// position, camera-follow, route line) is Android/iOS only. The
// GPS/route-related parameters below are accepted only so screens can call
// VenueMap the same way on every platform — they're inert here.
class VenueMap extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double? userLatitude;
  final double? userLongitude;
  final bool followUser;
  final VenueMapController? controller;
  final List<UserPosition>? routeGeometry;
  final double? portLatitude;
  final double? portLongitude;

  const VenueMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.userLatitude,
    this.userLongitude,
    this.followUser = false,
    this.controller,
    this.routeGeometry,
    this.portLatitude,
    this.portLongitude,
  });

  @override
  Widget build(BuildContext context) {
    return const PlaceholderMap();
  }
}
