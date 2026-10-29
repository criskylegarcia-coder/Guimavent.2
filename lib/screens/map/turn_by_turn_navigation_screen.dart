import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../services/directions_service.dart';
import '../../services/geolocator_location_service.dart';
import '../../services/location_service.dart';
import '../../services/mapbox_directions_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mock_walk_estimate.dart';
import '../../utils/route_deviation.dart';
import '../../widgets/venue_map.dart';

// Opened from MapDirectionsShellScreen's "Start Navigation" button. Renders
// a real Mapbox map (Android/iOS) tracking the user's live GPS position,
// camera auto-following until they manually pan, with a real destination
// marker and route line once the venue and a GPS fix are both known. The
// initial route is one-shot (see _maybeFetchRoute()); once it exists, every
// subsequent GPS update is checked against it and a new route is requested
// only if the user has strayed far enough (see _maybeReroute()). The
// turn-by-turn instruction banner itself is still static/mock — live
// step-by-step guidance isn't part of this batch.
class TurnByTurnNavigationScreen extends StatefulWidget {
  final String activityId;
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase/Geolocator/Mapbox-backed implementations.
  final EventRepository? repository;
  final LocationService? locationService;
  final DirectionsService? directionsService;

  const TurnByTurnNavigationScreen({
    super.key,
    required this.activityId,
    this.repository,
    this.locationService,
    this.directionsService,
  });

  @override
  State<TurnByTurnNavigationScreen> createState() =>
      _TurnByTurnNavigationScreenState();
}

class _TurnByTurnNavigationScreenState
    extends State<TurnByTurnNavigationScreen> {
  late final EventRepository _repository =
      widget.repository ?? SupabaseEventRepository();
  late final LocationService _locationService =
      widget.locationService ?? const GeolocatorLocationService();
  late final DirectionsService _directionsService =
      widget.directionsService ?? MapboxDirectionsService();
  final VenueMapController _mapController = VenueMapController();

  bool _isMuted = false;
  // Null until a GPS fix arrives — VenueMap just shows its fallback
  // center until then, same as MapDirectionsShellScreen.
  UserPosition? _userPosition;
  StreamSubscription<UserPosition>? _positionSubscription;
  // Null until the activity/venue loads — best-effort: the screen still
  // works with just the live position marker if this fails.
  Activity? _activity;
  // Null until the Directions API call succeeds — calculated once, from
  // whichever of (activity, first GPS fix) resolves last. See
  // _maybeFetchRoute() for why this stays one-shot despite watchPosition()
  // emitting continuously.
  TravelRoute? _route;
  bool _routeFetchInFlight = false;
  // True only while a *reroute* call is in flight (not the initial fetch)
  // — drives the "Rerouting..." indicator.
  bool _isRerouting = false;
  DateTime? _lastRerouteAt;

  // GPS accuracy for a phone walking outdoors is typically 5-15m in the
  // open, degrading to 20-50m under tree cover or between buildings —
  // common in parts of Guimaras. 40m sits comfortably above that noise
  // floor (avoiding reroutes triggered by GPS jitter alone) while still
  // catching a genuine wrong turn within well under a minute of walking.
  static const double _rerouteThresholdMeters = 40;
  // Long enough that a user briefly bouncing around the threshold (GPS
  // jitter right at the edge, or a short detour around an obstacle)
  // doesn't trigger repeated API calls; short enough that a real wrong
  // turn gets corrected promptly rather than leaving a stale route
  // on-screen for too long.
  static const Duration _rerouteCooldown = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _loadActivity();
    // VenueMap on web is still just the Batch 1 placeholder (see
    // widgets/venue_map_web.dart) — skip requesting real browser
    // geolocation there, since there'd be nowhere to show or follow it.
    if (!kIsWeb) _startTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    try {
      final activity = await _repository.getActivityById(widget.activityId);
      if (!mounted || activity == null) return;
      setState(() => _activity = activity);
      _maybeFetchRoute();
    } catch (_) {
      // Best-effort — no venue marker/route this batch is a graceful
      // degradation (same spirit as a failed GPS fix), not a crash.
    }
  }

  Future<void> _startTracking() async {
    final status = await _locationService.requestAccess();
    if (!mounted) return;
    if (status != LocationAccessStatus.granted) {
      _showLocationMessage(status);
      return;
    }
    _positionSubscription = _locationService.watchPosition().listen(
      (position) {
        if (!mounted) return;
        setState(() => _userPosition = position);
        if (_route == null) {
          _maybeFetchRoute();
        } else {
          _maybeReroute(position);
        }
      },
      onError: (_) {
        if (!mounted) return;
        _showSnack('Lost GPS signal — showing your last known position.');
      },
    );
  }

  // The initial route: fires from both _loadActivity() and the first few
  // watchPosition() updates, but only ever issues one Directions API call
  // — it no-ops once a route exists (_route != null) or while one is
  // already in flight, and only proceeds once BOTH the venue and a GPS fix
  // are available. Live rerouting once this initial route exists is
  // _maybeReroute()'s job, not this one's.
  Future<void> _maybeFetchRoute() async {
    if (_route != null || _routeFetchInFlight) return;
    final position = _userPosition;
    final activity = _activity;
    if (position == null || activity == null) return;
    final lat = activity.latitude;
    final lng = activity.longitude;
    if (lat == null || lng == null) return;
    await _requestRoute(position, lat, lng, isReroute: false);
  }

  // Checks the user's current position against the existing route on every
  // GPS update, and requests a new one only when they've strayed past
  // _rerouteThresholdMeters AND the cooldown has elapsed — not on every
  // update, which would spam the Directions API for GPS noise alone.
  Future<void> _maybeReroute(UserPosition position) async {
    final route = _route;
    final activity = _activity;
    if (route == null || activity == null || _routeFetchInFlight) return;
    final lat = activity.latitude;
    final lng = activity.longitude;
    if (lat == null || lng == null) return;

    final deviation = distanceToRoute(position, route.geometry);
    if (deviation < _rerouteThresholdMeters) return;

    final now = DateTime.now();
    final lastReroute = _lastRerouteAt;
    if (lastReroute != null && now.difference(lastReroute) < _rerouteCooldown) {
      return;
    }
    // Set before the await starts, not after it completes — the cooldown
    // is measured from when the reroute was triggered, so a slow/failed
    // API call can't itself extend how soon the next attempt is allowed.
    _lastRerouteAt = now;
    await _requestRoute(position, lat, lng, isReroute: true);
  }

  Future<void> _requestRoute(
    UserPosition from,
    double venueLat,
    double venueLng, {
    required bool isReroute,
  }) async {
    _routeFetchInFlight = true;
    if (isReroute && mounted) setState(() => _isRerouting = true);

    final route = await _directionsService.getRoute(
      from: from,
      to: (latitude: venueLat, longitude: venueLng),
      // Turn-by-turn live navigation stays walking-only for now — driving
      // and cycling would need speed-appropriate rerouting thresholds and
      // road-snapping this batch doesn't add; mode selection lives on
      // MapDirectionsShellScreen only, before the user commits to a route.
      mode: TravelMode.walking,
    );

    _routeFetchInFlight = false;
    if (!mounted) return;
    setState(() {
      _isRerouting = false;
      // On failure, keep showing the last known good route rather than
      // clearing it — a failed recalculation shouldn't erase a still-valid
      // (if slightly stale) one.
      if (route != null) _route = route;
    });
  }

  void _showLocationMessage(LocationAccessStatus status) {
    final messenger = ScaffoldMessenger.of(context);
    switch (status) {
      case LocationAccessStatus.denied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location access is needed to show your position on the map '
              'and calculate directions.',
            ),
          ),
        );
      case LocationAccessStatus.deniedForever:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Location access is turned off for GuimaVent.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: _locationService.openAppSettings,
            ),
          ),
        );
      case LocationAccessStatus.serviceDisabled:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Turn on your device\'s location services.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: _locationService.openLocationSettings,
            ),
          ),
        );
      case LocationAccessStatus.granted:
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _showSnack(_isMuted ? 'Voice guidance muted' : 'Voice guidance on');
  }

  void _handleRecenter() {
    _mapController.recenter();
    _showSnack('Recentering map...');
  }

  void _handleExit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Real Directions API result when available; the same deterministic
    // mock used before this batch otherwise (venue/GPS not resolved yet,
    // or the API call failed) — never a blank/zero display.
    final estimate = _route != null
        ? (km: _route!.distanceMeters / 1000, minutes: (_route!.durationSeconds / 60).round())
        : mockWalkEstimate(widget.activityId);
    final arrivalTime = formatArrivalTime(estimate.minutes);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: VenueMap(
              latitude: _activity?.latitude,
              longitude: _activity?.longitude,
              userLatitude: _userPosition?.latitude,
              userLongitude: _userPosition?.longitude,
              followUser: true,
              controller: _mapController,
              routeGeometry: _route?.geometry,
            ),
          ),

          // Top instruction banner.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.textDark,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.turn_slight_right_rounded,
                      color: AppColors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Head northeast on Rizal Street',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '120 m',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Small, non-intrusive "Rerouting..." pill — shown only while a
          // deviation-triggered reroute call is in flight, so the sudden
          // change in the route line has an obvious explanation. The
          // initial route fetch (before the user has started walking off
          // it) doesn't show this — only _maybeReroute() sets _isRerouting.
          if (_isRerouting)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 96),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rerouting...',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Floating circular controls.
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.32,
            child: Column(
              children: [
                _MapControlButton(
                  icon: _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: _toggleMute,
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.my_location_rounded,
                  onTap: _handleRecenter,
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.report_gmailerrorred_rounded,
                  onTap: () => _showSnack('Report submitted. Thank you!'),
                ),
              ],
            ),
          ),

          // Bottom bar: ETA on the left, Exit on the right.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                // theme.cardTheme.color (not the fixed AppColors.white) so
                // this bar matches its own text below, which already
                // correctly switches color via theme.textTheme — a
                // fixed-white bar behind theme-following light-in-dark-
                // mode text is unreadable.
                color: theme.cardTheme.color ?? AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${estimate.minutes} min · ${estimate.km.toStringAsFixed(1)} km',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Arrive $arrivalTime',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _handleExit,
                      style: ElevatedButton.styleFrom(
                        // Overrides AppTheme's app-wide full-width default
                        // (minimumSize: Size(double.infinity, 52)) — this
                        // button sits inline next to the ETA text, not
                        // full-width like PrimaryButton.
                        minimumSize: const Size(0, 44),
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.buttonRadius,
                          ),
                        ),
                      ),
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.textDark, size: 22),
        ),
      ),
    );
  }
}
