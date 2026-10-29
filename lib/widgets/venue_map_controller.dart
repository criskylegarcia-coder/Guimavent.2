import 'package:flutter/foundation.dart';

// A tiny imperative escape hatch for VenueMap, for the one thing screens
// need to trigger directly rather than express as a prop: "recenter on the
// user's position and resume auto-follow now" (the floating my-location
// button). Mirrors TextEditingController's shape — a plain controller
// object a screen owns and passes in, avoiding a GlobalKey typed to
// whichever of VenueMap's two conditionally-exported State classes
// (native vs web) happens to be compiled in.
class VenueMapController {
  VoidCallback? _onRecenter;

  /// Re-centers the map on the current user position (if known) and
  /// resumes auto-follow if a manual pan had paused it. No-ops if no
  /// VenueMap is currently bound to this controller — including on web,
  /// where VenueMap is a static placeholder with nothing to recenter.
  void recenter() => _onRecenter?.call();

  /// Called by VenueMap's State to bind itself as the recenter target.
  /// Private fields are file-private in Dart, so this (and [detach]) is
  /// how a VenueMap in a different file reaches _onRecenter — not meant
  /// for screens to call directly.
  void attach(VoidCallback onRecenter) => _onRecenter = onRecenter;

  /// Called by VenueMap's State when it's disposed, so a stale controller
  /// doesn't hold a reference to a dead State.
  void detach() => _onRecenter = null;
}
