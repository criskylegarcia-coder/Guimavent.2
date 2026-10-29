// Deterministic, seed-based mock walking distance/time — used by the map
// screens until real routing/geolocation is wired up. The same seed (an
// activity id) always gives the same numbers, so the estimate shown on
// Map Directions matches what Turn-by-turn Navigation shows for the same
// activity.
typedef WalkEstimate = ({double km, int minutes});

WalkEstimate mockWalkEstimate(String seed) {
  final n = seed.hashCode.abs() % 18; // 0..17
  final km = 0.4 + n / 10; // 0.4 km .. 2.1 km
  final minutes = (km * 13).round(); // ~13 min per km, average walking pace
  return (km: km, minutes: minutes);
}

/// "6:15 PM" — the wall-clock time `minutesFromNow` minutes from now.
String formatArrivalTime(int minutesFromNow) {
  final arrival = DateTime.now().add(Duration(minutes: minutesFromNow));
  final hour12 = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
  final minute = arrival.minute.toString().padLeft(2, '0');
  final period = arrival.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}
