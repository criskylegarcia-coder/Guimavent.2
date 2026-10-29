import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../config/mapbox_config.dart';
import '../services/location_service.dart' show UserPosition;
import '../theme/app_theme.dart';
import 'venue_map_controller.dart';

// Real Mapbox rendering — Android/iOS only. See venue_map.dart for why
// this file is excluded from the web build's compilation entirely, not
// just unused at runtime there.
class VenueMap extends StatefulWidget {
  // The venue/destination marker — orange. Null falls back to a fixed
  // Guimaras-area center (e.g. TurnByTurnNavigationScreen, which has no
  // destination marker yet — that's Batch 3's route-to-venue work).
  final double? latitude;
  final double? longitude;

  // The user's live GPS position — green, a separate marker from the
  // venue. Null means "not known yet" (permission not granted, no fix
  // yet, or GPS unavailable) and simply omits this marker.
  final double? userLatitude;
  final double? userLongitude;

  // When true, the camera recenters on userLatitude/userLongitude as it
  // updates — until the user manually pans, at which point auto-follow
  // pauses until VenueMapController.recenter() is called again.
  final bool followUser;

  final VenueMapController? controller;

  // The route from origin to venue, as an ordered list of points — drawn
  // as a line. Null means "no route yet" (not calculated, or the
  // Directions API call failed) and simply omits the line, same as a null
  // marker position omits that marker.
  final List<UserPosition>? routeGeometry;

  // A picked arrival-port origin — yellow, distinct from both the venue
  // (orange) and live GPS (green) markers. Only MapDirectionsShellScreen's
  // origin picker sets this; null (the common case) simply omits it. Not
  // meant to be shown at the same time as userLatitude/userLongitude —
  // callers pick one active origin marker at a time.
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
  State<VenueMap> createState() => _VenueMapState();
}

class _VenueMapState extends State<VenueMap> {
  // Guimaras' rough center — used only when neither a venue nor a user
  // position is available yet.
  static const double _fallbackLatitude = 10.5929;
  static const double _fallbackLongitude = 122.5968;

  // MapboxOptions.setAccessToken is process-global, not per-widget — only
  // needs to run once no matter how many VenueMaps get built.
  static bool _accessTokenConfigured = false;

  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _annotationManager;
  CircleAnnotation? _venueMarker;
  CircleAnnotation? _userMarker;
  CircleAnnotation? _portMarker;
  PolylineAnnotationManager? _routeManager;
  PolylineAnnotation? _routeLine;

  // Auto-follow pauses the moment the user drags the map themselves, and
  // only resumes when they explicitly ask to recenter (the floating
  // my-location button, wired to VenueMapController.recenter()).
  bool _isFollowing = true;

  @override
  void initState() {
    super.initState();
    if (!_accessTokenConfigured) {
      MapboxOptions.setAccessToken(mapboxAccessToken);
      _accessTokenConfigured = true;
    }
    widget.controller?.attach(_handleRecenter);
  }

  @override
  void didUpdateWidget(covariant VenueMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_handleRecenter);
    }
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      debugPrint(
        '[VenueMap] didUpdateWidget: venue ${oldWidget.latitude},'
        '${oldWidget.longitude} -> ${widget.latitude},${widget.longitude} '
        '(annotationManager ready: ${_annotationManager != null})',
      );
      _updateVenueMarker();
    }
    if (widget.userLatitude != oldWidget.userLatitude ||
        widget.userLongitude != oldWidget.userLongitude) {
      debugPrint(
        '[VenueMap] didUpdateWidget: user ${oldWidget.userLatitude},'
        '${oldWidget.userLongitude} -> ${widget.userLatitude},'
        '${widget.userLongitude} (annotationManager ready: '
        '${_annotationManager != null})',
      );
      _updateUserMarker();
    }
    if (widget.routeGeometry != oldWidget.routeGeometry) {
      _updateRouteLine();
    }
    if (widget.portLatitude != oldWidget.portLatitude ||
        widget.portLongitude != oldWidget.portLongitude) {
      _updatePortMarker();
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  Future<void> _handleRecenter() async {
    _isFollowing = true;
    final lat = widget.userLatitude ?? widget.latitude ?? _fallbackLatitude;
    final lng = widget.userLongitude ?? widget.longitude ?? _fallbackLongitude;
    await _mapboxMap?.easeTo(
      CameraOptions(center: Point(coordinates: Position(lng, lat))),
      MapAnimationOptions(duration: 500),
    );
  }

  Future<void> _updateVenueMarker() async {
    final manager = _annotationManager;
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (manager == null || lat == null || lng == null) return;
    final point = Point(coordinates: Position(lng, lat));

    final marker = _venueMarker;
    if (marker == null) {
      try {
        _venueMarker = await manager.create(
          CircleAnnotationOptions(
            geometry: point,
            circleColor: AppColors.accentOrange.toARGB32(),
            circleRadius: 10.0,
            circleStrokeColor: AppColors.white.toARGB32(),
            circleStrokeWidth: 2.0,
          ),
        );
        debugPrint(
          '[VenueMap] venue marker CREATED id=${_venueMarker!.id} at '
          'lat=$lat, lng=$lng',
        );
      } catch (e, st) {
        // Logged explicitly (not left as an unhandled Future error) because
        // an uncaught throw here would otherwise print under Flutter's
        // generic error banner, not the [VenueMap] tag — easy to miss when
        // filtering logcat for that tag specifically.
        debugPrint('[VenueMap] venue marker creation THREW: $e\n$st');
      }
    } else {
      marker.geometry = point;
      await manager.update(marker);
      debugPrint(
        '[VenueMap] venue marker UPDATED id=${marker.id} at lat=$lat,'
        ' lng=$lng',
      );
    }
  }

  Future<void> _updateRouteLine() async {
    final manager = _routeManager;
    final geometry = widget.routeGeometry;
    if (manager == null || geometry == null || geometry.isEmpty) return;
    final line = LineString(
      coordinates: [
        for (final p in geometry) Position(p.longitude, p.latitude),
      ],
    );

    final existing = _routeLine;
    if (existing == null) {
      try {
        _routeLine = await manager.create(
          PolylineAnnotationOptions(
            geometry: line,
            lineColor: AppColors.primary.toARGB32(),
            lineWidth: 4.0,
          ),
        );
        debugPrint(
          '[VenueMap] route line CREATED id=${_routeLine!.id} with '
          '${geometry.length} points',
        );
      } catch (e, st) {
        debugPrint('[VenueMap] route line creation THREW: $e\n$st');
      }
    } else {
      existing.geometry = line;
      await manager.update(existing);
      debugPrint(
        '[VenueMap] route line UPDATED id=${existing.id} with '
        '${geometry.length} points',
      );
    }
  }

  // Unlike the venue/user markers (which only ever go null -> a value in
  // practice), the port marker genuinely toggles both ways as the origin
  // picker switches between "My Location" and a port — so this is the one
  // marker method that also deletes, not just creates/updates.
  Future<void> _updatePortMarker() async {
    final manager = _annotationManager;
    if (manager == null) return;
    final lat = widget.portLatitude;
    final lng = widget.portLongitude;

    if (lat == null || lng == null) {
      final marker = _portMarker;
      if (marker != null) {
        await manager.delete(marker);
        _portMarker = null;
        debugPrint('[VenueMap] port marker DELETED — origin no longer a port');
      }
      return;
    }

    final point = Point(coordinates: Position(lng, lat));
    final marker = _portMarker;
    if (marker == null) {
      try {
        _portMarker = await manager.create(
          CircleAnnotationOptions(
            geometry: point,
            circleColor: AppColors.accentYellow.toARGB32(),
            circleRadius: 9.0,
            circleStrokeColor: AppColors.white.toARGB32(),
            circleStrokeWidth: 2.0,
          ),
        );
        debugPrint(
          '[VenueMap] port marker CREATED id=${_portMarker!.id} at '
          'lat=$lat, lng=$lng',
        );
      } catch (e, st) {
        debugPrint('[VenueMap] port marker creation THREW: $e\n$st');
      }
    } else {
      marker.geometry = point;
      await manager.update(marker);
      debugPrint(
        '[VenueMap] port marker UPDATED id=${marker.id} at lat=$lat,'
        ' lng=$lng',
      );
    }
  }

  Future<void> _updateUserMarker() async {
    final manager = _annotationManager;
    final lat = widget.userLatitude;
    final lng = widget.userLongitude;
    if (manager == null || lat == null || lng == null) return;
    final point = Point(coordinates: Position(lng, lat));

    final marker = _userMarker;
    if (marker == null) {
      _userMarker = await manager.create(
        CircleAnnotationOptions(
          geometry: point,
          circleColor: AppColors.secondary.toARGB32(),
          circleRadius: 8.0,
          circleStrokeColor: AppColors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
      debugPrint(
        '[VenueMap] user marker CREATED id=${_userMarker!.id} at lat=$lat,'
        ' lng=$lng',
      );
    } else {
      marker.geometry = point;
      await manager.update(marker);
      debugPrint(
        '[VenueMap] user marker UPDATED id=${marker.id} at lat=$lat,'
        ' lng=$lng',
      );
    }

    if (widget.followUser && _isFollowing) {
      await _mapboxMap?.easeTo(
        CameraOptions(center: point),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude ?? widget.userLatitude ?? _fallbackLatitude;
    final lng = widget.longitude ?? widget.userLongitude ?? _fallbackLongitude;
    final initialPoint = Point(coordinates: Position(lng, lat));

    return MapWidget(
      // Fires repeatedly while the user drags the map — any manual pan
      // pauses auto-follow until they explicitly recenter. No setState:
      // this flag only affects the next marker-update's camera decision,
      // not anything currently on screen.
      onScrollListener: (_) => _isFollowing = false,
      onMapCreated: (MapboxMap mapboxMap) async {
        debugPrint(
          '[VenueMap] onMapCreated: venue=${widget.latitude},'
          '${widget.longitude} user=${widget.userLatitude},'
          '${widget.userLongitude}',
        );
        _mapboxMap = mapboxMap;
        await mapboxMap.setCamera(
          CameraOptions(center: initialPoint, zoom: widget.followUser ? 17 : 15),
        );

        // Route line created first so its layer sits below the marker
        // circles' layer — annotation managers created later render on top
        // of earlier ones, so this ordering keeps the line from covering
        // the markers.
        final routeManager = await mapboxMap.annotations
            .createPolylineAnnotationManager();
        _routeManager = routeManager;

        final manager = await mapboxMap.annotations
            .createCircleAnnotationManager();
        _annotationManager = manager;

        if (widget.latitude != null && widget.longitude != null) {
          await _updateVenueMarker();
        } else {
          debugPrint(
            '[VenueMap] venue marker SKIPPED at onMapCreated — not known yet',
          );
        }

        if (widget.userLatitude != null && widget.userLongitude != null) {
          await _updateUserMarker();
        } else {
          debugPrint(
            '[VenueMap] user marker SKIPPED at onMapCreated — not known yet',
          );
        }

        if (widget.routeGeometry != null && widget.routeGeometry!.isNotEmpty) {
          await _updateRouteLine();
        } else {
          debugPrint(
            '[VenueMap] route line SKIPPED at onMapCreated — not known yet',
          );
        }

        if (widget.portLatitude != null && widget.portLongitude != null) {
          await _updatePortMarker();
        }
      },
    );
  }
}
