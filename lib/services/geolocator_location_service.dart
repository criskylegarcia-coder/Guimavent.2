import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationAccessStatus> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessStatus.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccessStatus.granted;
      case LocationPermission.deniedForever:
        return LocationAccessStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccessStatus.denied;
    }
  }

  @override
  Future<UserPosition?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      // Covers LocationServiceDisabledException, TimeoutException, and any
      // platform-specific failure — a failed fix just means "no GPS yet",
      // never a crash.
      return null;
    }
  }

  @override
  Stream<UserPosition> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Ignore sub-5m jitter so the marker/camera aren't fighting GPS
        // noise while the user is standing still.
        distanceFilter: 5,
      ),
    ).map((position) => (latitude: position.latitude, longitude: position.longitude));
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
