// The contract map screens depend on for GPS access. Screens must only
// ever import THIS file, never GeolocatorLocationService directly —
// mirrors the repository pattern used elsewhere (see lib/repositories/).

/// A location fix, decoupled from geolocator's own `Position` type (which
/// carries far more than this app currently uses — accuracy, altitude,
/// speed, heading, timestamp).
typedef UserPosition = ({double latitude, double longitude});

/// The outcome of asking for location access — covers every state a real
/// device can be in, not just granted/denied.
enum LocationAccessStatus {
  /// Permission granted and the device's location services are on — safe
  /// to call getCurrentPosition()/watchPosition().
  granted,

  /// The user denied the permission prompt, but can be asked again.
  denied,

  /// The user denied permanently ("Don't ask again" / iOS equivalent) —
  /// re-requesting is a no-op; only the OS app-settings screen can change
  /// this.
  deniedForever,

  /// Permission itself may be fine, but the device's location services
  /// (GPS) are switched off entirely — a different, orthogonal failure
  /// mode from permission.
  serviceDisabled,
}

abstract class LocationService {
  /// Ensures location access is available, requesting permission if
  /// needed. Always resolves — never throws — so callers can branch on
  /// the returned status instead of wrapping every call in try/catch.
  Future<LocationAccessStatus> requestAccess();

  /// A single position fix. Returns null if it couldn't be obtained (e.g.
  /// access was never granted, or the fix genuinely failed/timed out) —
  /// callers should treat null the same as "no GPS available yet" and
  /// fall back to the static map center.
  Future<UserPosition?> getCurrentPosition();

  /// Live position updates. Callers are responsible for cancelling their
  /// subscription (e.g. in State.dispose()) — this stream keeps the
  /// device's GPS sensor active for as long as something is listening.
  Stream<UserPosition> watchPosition();

  /// Opens the OS's app-settings screen — the only way to change a
  /// permanently-denied permission. Returns whether it could be opened.
  Future<bool> openAppSettings();

  /// Opens the OS's location-services settings screen (for when GPS
  /// itself is switched off device-wide, separate from app permission).
  /// Returns whether it could be opened.
  Future<bool> openLocationSettings();
}
