import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/arrival_port.dart';
import '../../repositories/arrival_port_repository.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/itinerary_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../repositories/supabase_arrival_port_repository.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../repositories/supabase_itinerary_repository.dart';
import '../../repositories/supabase_registration_repository.dart';
import '../../services/directions_service.dart';
import '../../services/geolocator_location_service.dart';
import '../../services/location_service.dart';
import '../../services/mapbox_directions_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_snackbar.dart';
import '../../utils/mock_walk_estimate.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/venue_map.dart';

// Shown either as the bottom nav's "Map" tab (no activityId — defaults to
// a generic destination) or pushed from Activity Details' "Get Directions"
// button (with a specific activityId). Renders a real Mapbox map centered
// on the activity's venue (Android/iOS) — see widgets/venue_map.dart. The
// mode/origin selector bar lets a tourist preview travel time by transport
// mode and from a specific arrival port, not just their live GPS position —
// see _fetchRoute() for how origin and mode both feed the same Directions
// API call.
class MapDirectionsShellScreen extends StatefulWidget {
  final String? activityId;
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase/Geolocator/Mapbox-backed implementations.
  final EventRepository? repository;
  final ItineraryRepository? itineraryRepository;
  final LocationService? locationService;
  final DirectionsService? directionsService;
  final ArrivalPortRepository? portRepository;
  final RegistrationRepository? registrationRepository;

  const MapDirectionsShellScreen({
    super.key,
    this.activityId,
    this.repository,
    this.itineraryRepository,
    this.locationService,
    this.directionsService,
    this.portRepository,
    this.registrationRepository,
  });

  @override
  State<MapDirectionsShellScreen> createState() =>
      _MapDirectionsShellScreenState();
}

class _MapDirectionsShellScreenState extends State<MapDirectionsShellScreen> {
  // Used when opened from the bottom nav tab with no specific destination —
  // "14" is a real sub_activity row (Opening Ceremony), not a mock id.
  static const String _defaultActivityId = '14';

  late final EventRepository _repository =
      widget.repository ?? SupabaseEventRepository();
  late final ItineraryRepository _itineraryRepository =
      widget.itineraryRepository ?? SupabaseItineraryRepository();
  late final LocationService _locationService =
      widget.locationService ?? const GeolocatorLocationService();
  late final DirectionsService _directionsService =
      widget.directionsService ?? MapboxDirectionsService();
  late final ArrivalPortRepository _portRepository =
      widget.portRepository ?? SupabaseArrivalPortRepository();
  late final RegistrationRepository _registrationRepository =
      widget.registrationRepository ?? SupabaseRegistrationRepository();
  late final String _effectiveActivityId;
  late final Future<Activity?> _activityFuture;
  late final Future<List<ArrivalPort>> _portsFuture = _portRepository.getPorts();
  // Null = still checking. Gates the whole screen (both the bottom-nav
  // Map tab and the pushed /map/:activityId route land here) rather than
  // just the ActivityDetails "Get Directions" button, since this screen is
  // reachable other ways too (deep link, back/forward) that never go
  // through that button's own check.
  bool? _hasActiveRegistration;
  // Reflects My Schedule (isScheduled), the same state
  // ActivityDetailsShellScreen's heart and the My Schedule tab use — not
  // the old activity-favorites system, so this stays in sync with both.
  bool _isScheduled = false;
  bool _isTogglingSchedule = false;
  // Null until a GPS fix is obtained — VenueMap treats null exactly like
  // Batch 1's static-center behavior, so no separate "loading" state is
  // needed here.
  UserPosition? _userPosition;
  // Null until the Directions API call succeeds — screens fall back to
  // mockWalkEstimate (and no route line) for as long as this stays null,
  // whether that's "still loading" or "the call failed."
  TravelRoute? _route;
  TravelMode _selectedMode = TravelMode.walking;
  // Null = "My Location" (the default, live-GPS origin). Non-null = the
  // user picked a specific arrival port as a hypothetical starting point
  // instead — see _effectiveOrigin.
  ArrivalPort? _selectedPort;

  // The coordinates a route should actually be calculated FROM: the
  // selected port's fixed location if one is chosen, otherwise whatever
  // live GPS fix is available (or null, if neither is ready yet).
  UserPosition? get _effectiveOrigin => _selectedPort != null
      ? (latitude: _selectedPort!.latitude, longitude: _selectedPort!.longitude)
      : _userPosition;

  @override
  void initState() {
    super.initState();
    _registrationRepository.hasActiveRegistration().then((value) {
      if (mounted) setState(() => _hasActiveRegistration = value);
    }).catchError((_) {
      // Fails closed: an unreadable check shows the registration gate
      // rather than silently letting an unverified tourist through.
      if (mounted) setState(() => _hasActiveRegistration = false);
    });
    _effectiveActivityId = widget.activityId ?? _defaultActivityId;
    _activityFuture = withErrorFallback(
      context,
      _repository.getActivityById(_effectiveActivityId),
      fallback: null,
    );
    // Failure here just leaves the heart unfilled — not worth a SnackBar of
    // its own.
    _itineraryRepository
        .isScheduled(_effectiveActivityId)
        .then((value) {
          if (mounted) setState(() => _isScheduled = value);
        })
        .catchError((_) {});
    // VenueMap on web is still just the Batch 1 placeholder (see
    // widgets/venue_map_web.dart) — skip requesting real browser
    // geolocation there, since there'd be nowhere to show it and it would
    // just be an unexplained permission prompt.
    if (!kIsWeb) _requestUserLocation();
  }

  Future<void> _requestUserLocation() async {
    final status = await _locationService.requestAccess();
    if (!mounted) return;
    if (status != LocationAccessStatus.granted) {
      _showLocationMessage(status);
      return;
    }
    final position = await _locationService.getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() => _userPosition = position);
    // If the user already picked a port while this was in flight, a
    // just-arrived GPS fix shouldn't silently override that choice.
    if (_selectedPort == null) _fetchRoute();
  }

  void _handleModeChanged(TravelMode mode) {
    if (mode == _selectedMode) return;
    setState(() => _selectedMode = mode);
    _fetchRoute();
  }

  void _handleOriginChanged(ArrivalPort? port) {
    if (port == _selectedPort) return;
    setState(() => _selectedPort = port);
    // A port origin needs no GPS/permission at all — _fetchRoute() reads
    // _effectiveOrigin, which resolves straight to the port's fixed
    // coordinates without touching _locationService.
    _fetchRoute();
  }

  // One-shot per mode/origin selection: recalculated whenever the mode or
  // origin changes (see _handleModeChanged/_handleOriginChanged), not
  // continuously — MapDirectionsShellScreen isn't a live-tracking view.
  // Deliberately doesn't clear _route before the new result arrives, so
  // switching mode/origin doesn't flash back to the mock estimate — the
  // previous selection's numbers stay on screen until the new ones land.
  Future<void> _fetchRoute() async {
    final origin = _effectiveOrigin;
    if (origin == null) return;
    final activity = await _activityFuture;
    if (!mounted || activity == null) return;
    final lat = activity.latitude;
    final lng = activity.longitude;
    if (lat == null || lng == null) return;
    final route = await _directionsService.getRoute(
      from: origin,
      to: (latitude: lat, longitude: lng),
      mode: _selectedMode,
    );
    if (!mounted || route == null) return;
    setState(() => _route = route);
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

  Future<void> _handleToggleSchedule() async {
    if (_isTogglingSchedule) return;
    setState(() => _isTogglingSchedule = true);
    try {
      if (_isScheduled) {
        await _itineraryRepository.removeFromSchedule(_effectiveActivityId);
      } else {
        final activity = await _activityFuture;
        if (activity == null) {
          throw const RepositoryException('Activity not found.');
        }
        await _itineraryRepository.addToSchedule(activity);
      }
      if (!mounted) return;
      final newValue = !_isScheduled;
      setState(() {
        _isScheduled = newValue;
        _isTogglingSchedule = false;
      });
      // Only on adding (favoriting), not removing — a subtle confirmation
      // nudge for the positive action, not every toggle.
      if (newValue) HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingSchedule = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessageFor(e))));
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Map layers coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    if (_hasActiveRegistration == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Directions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasActiveRegistration == false) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          title: const Text('Directions'),
        ),
        body: _RegistrationRequiredView(
          onRegister: () => context.push('/register'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
        title: const Text('Directions'),
        actions: [
          IconButton(
            onPressed: _isTogglingSchedule ? null : _handleToggleSchedule,
            icon: Icon(
              _isScheduled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isScheduled ? AppColors.accentOrange : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            onPressed: _showComingSoon,
          ),
        ],
      ),
      body: Column(
        children: [
          _SelectorBar(
            selectedMode: _selectedMode,
            selectedPort: _selectedPort,
            portsFuture: _portsFuture,
            onModeChanged: _handleModeChanged,
            onOriginChanged: _handleOriginChanged,
          ),
          Expanded(
            child: FutureBuilder<Activity?>(
              future: _activityFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final activity = snapshot.data;
                if (activity == null) {
                  return const Center(child: Text('Destination not found'));
                }
                return _MapDirectionsBody(
                  activity: activity,
                  userPosition: _userPosition,
                  route: _route,
                  mode: _selectedMode,
                  selectedPort: _selectedPort,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Shown instead of the map when the current user has no Pre-Arrival
// Registration on file — covers every way this screen can be reached (the
// bottom-nav Map tab, a pushed /map/:activityId, a deep link), not just the
// ActivityDetails "Get Directions" button's own pre-navigation check.
class _RegistrationRequiredView extends StatelessWidget {
  final VoidCallback onRegister;

  const _RegistrationRequiredView({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.app_registration_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Registration Required',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete Pre-Arrival Registration before accessing Map & '
              'Directions.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Register Now', onPressed: onRegister),
          ],
        ),
      ),
    );
  }
}

// Compact origin + mode controls, pinned between the AppBar and the map —
// doesn't touch the bottom sheet at all. Ports load asynchronously but the
// bar itself renders immediately with just "My Location" available; the
// port options appear once they arrive (a small, acceptable flash for a
// two-row Supabase query).
class _SelectorBar extends StatelessWidget {
  final TravelMode selectedMode;
  final ArrivalPort? selectedPort;
  final Future<List<ArrivalPort>> portsFuture;
  final ValueChanged<TravelMode> onModeChanged;
  final ValueChanged<ArrivalPort?> onOriginChanged;

  const _SelectorBar({
    required this.selectedMode,
    required this.selectedPort,
    required this.portsFuture,
    required this.onModeChanged,
    required this.onOriginChanged,
  });

  static const _modeIcons = {
    TravelMode.walking: Icons.directions_walk_rounded,
    TravelMode.cycling: Icons.directions_bike_rounded,
    TravelMode.driving: Icons.directions_car_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<List<ArrivalPort>>(
              future: portsFuture,
              builder: (context, snapshot) {
                final ports = snapshot.data ?? const <ArrivalPort>[];
                return DropdownButtonHideUnderline(
                  child: DropdownButton<ArrivalPort?>(
                    value: selectedPort,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    items: [
                      const DropdownMenuItem<ArrivalPort?>(
                        value: null,
                        child: _OriginLabel(
                          icon: Icons.my_location_rounded,
                          color: AppColors.secondary,
                          label: 'My Location',
                        ),
                      ),
                      for (final port in ports)
                        DropdownMenuItem<ArrivalPort?>(
                          value: port,
                          child: _OriginLabel(
                            icon: Icons.anchor_rounded,
                            color: AppColors.accentYellow,
                            label: port.name,
                          ),
                        ),
                    ],
                    onChanged: (port) => onOriginChanged(port),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<TravelMode>(
            segments: [
              for (final mode in TravelMode.values)
                ButtonSegment(value: mode, icon: Icon(_modeIcons[mode])),
            ],
            selected: {selectedMode},
            showSelectedIcon: false,
            onSelectionChanged: (modes) => onModeChanged(modes.first),
          ),
        ],
      ),
    );
  }
}

class _OriginLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _OriginLabel({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _MapDirectionsBody extends StatelessWidget {
  final Activity activity;
  final UserPosition? userPosition;
  final TravelRoute? route;
  final TravelMode mode;
  final ArrivalPort? selectedPort;

  const _MapDirectionsBody({
    required this.activity,
    this.userPosition,
    this.route,
    required this.mode,
    this.selectedPort,
  });

  static const _modeIcons = {
    TravelMode.walking: Icons.directions_walk_rounded,
    TravelMode.cycling: Icons.directions_bike_rounded,
    TravelMode.driving: Icons.directions_car_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Real Directions API result when available; the same deterministic
    // mock used before this batch otherwise (no fix yet, or the API call
    // failed) — never a blank/zero display.
    final estimate = route != null
        ? (km: route!.distanceMeters / 1000, minutes: (route!.durationSeconds / 60).round())
        : mockWalkEstimate(activity.id);
    // Start Navigation always launches live WALKING navigation from real
    // GPS (TurnByTurnNavigationScreen stays walking-only — see that
    // screen). Only meaningful when the preview actually matches that:
    // Walking mode, from My Location. Any other combination would send the
    // user to a screen that silently ignores what they just previewed.
    final canStartNavigation = mode == TravelMode.walking && selectedPort == null;
    debugPrint(
      '[MapDirectionsShellScreen] activity ${activity.id} venue '
      'lat=${activity.latitude}, lng=${activity.longitude} mode=$mode '
      'origin=${selectedPort?.name ?? "My Location"}',
    );

    return Stack(
      children: [
        Positioned.fill(
          child: VenueMap(
            latitude: activity.latitude,
            longitude: activity.longitude,
            // Only one of these two is ever active at a time: a picked
            // port suppresses the live-GPS marker in favor of its own
            // distinct style, since the route only has one real origin —
            // showing both would leave it ambiguous which one the
            // distance/line actually reflects.
            userLatitude: selectedPort == null ? userPosition?.latitude : null,
            userLongitude: selectedPort == null ? userPosition?.longitude : null,
            portLatitude: selectedPort?.latitude,
            portLongitude: selectedPort?.longitude,
            routeGeometry: route?.geometry,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              // theme.cardTheme.color (not the fixed AppColors.white) so
              // this panel actually matches its own text below, which
              // already correctly switches color via theme.textTheme —
              // a fixed-white panel behind theme-following light-in-dark-
              // mode text is unreadable.
              color: theme.cardTheme.color ?? AppColors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.cardRadius),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Navigation', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      activity.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppColors.accentOrange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            activity.venue,
                            style: theme.textTheme.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _modeIcons[mode],
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${estimate.km.toStringAsFixed(1)} km · ${estimate.minutes} min',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Start Navigation',
                      onPressed: canStartNavigation
                          ? () => context.push('/map/${activity.id}/navigate')
                          : null,
                    ),
                    // Disabling with no explanation would just look broken
                    // — this note is shown whenever the button is, so the
                    // reason is visible without needing to tap first.
                    if (!canStartNavigation) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Live navigation is walking-only, starting '
                              'from your current location.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
