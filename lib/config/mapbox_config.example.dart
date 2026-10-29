// Template — copy this file to mapbox_config.dart (same folder) and fill
// in your own Mapbox PUBLIC access token (starts with "pk.") from
// https://account.mapbox.com/access-tokens/.
//
// mapbox_config.dart is gitignored (see .gitignore) and required for the
// app to build — lib/widgets/venue_map_native.dart imports it directly.
// This .example file is the only one checked into version control.
//
// This is the public token only. It's safe-ish to ship in a client app
// (same security model as Supabase's anon key — restrict it by URL/rate
// limit in the Mapbox dashboard rather than treating it as fully secret).
// It is NOT the same as the separate secret "Downloads:Read" token needed
// to pull the Mapbox Android SDK during the build — that one goes in
// ~/.gradle/gradle.properties, never in this file or anywhere in the repo.
const String mapboxAccessToken = 'pk.YOUR_MAPBOX_PUBLIC_TOKEN_HERE';
