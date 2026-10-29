// Shared distance-formatting helper, same idea as date_format.dart.

/// "180 m away" under 1000 meters, "1.2 km away" at or above it.
String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m away';
  }
  final km = meters / 1000;
  return '${km.toStringAsFixed(1)} km away';
}
