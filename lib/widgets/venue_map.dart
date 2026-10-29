// Picks the right VenueMap implementation at compile time — real Mapbox
// rendering (venue_map_native.dart) on Android/iOS, the existing
// PlaceholderMap (venue_map_web.dart) on web.
//
// Why a conditional export instead of a runtime kIsWeb check: the stable
// release of mapbox_maps_flutter has no Flutter Web support at all (web
// support only exists in a pre-release alpha — see the batch this file
// came from for the investigation). A plain `if (kIsWeb) ... else ...`
// inside one shared widget would still require the web compiler to
// successfully compile the `else` branch's mapbox_maps_flutter imports,
// which isn't guaranteed to even compile for web in the stable release.
// Conditional export/import excludes venue_map_native.dart from the web
// build's compilation graph entirely, not just from what runs at runtime.
export 'venue_map_web.dart' if (dart.library.io) 'venue_map_native.dart';
// Unconditional — the same controller class is shared by both platform
// implementations, so screens get it from this one import regardless of
// which VenueMap they end up with.
export 'venue_map_controller.dart';
