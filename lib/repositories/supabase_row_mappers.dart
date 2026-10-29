// Pure row (Map) -> model mapping functions shared by every Supabase*
// repository, so the same Postgres row shape is always turned into the same
// Dart model the same way instead of each repository re-deriving it. Being
// plain functions with no SupabaseClient/network dependency also makes them
// directly unit-testable with hand-built maps standing in for real query
// results — see test/repositories/supabase_row_mappers_test.dart.

import 'dart:math';

import '../models/activity.dart';
import '../models/event.dart';
import '../models/itinerary_day.dart';
import '../models/itinerary_entry.dart';
import '../models/nearby_activity.dart';
import '../models/registration.dart';
import '../models/user_profile.dart';
import '../utils/date_format.dart';

// Reusable PostgREST embed fragments, so every query that needs an event's
// municipality name or an activity's event/venue names asks for exactly the
// same shape the mapper functions below expect.
const String eventSelectWithJoins = '*, municipality(municipality_name)';
const String subActivitySelectWithJoins =
    '*, event(banner_image_url), venue(venue_name, latitude, longitude)';

/// Expects a row from `event`, optionally joined with
/// `municipality(municipality_name)` (see [eventSelectWithJoins]).
Event eventFromRow(Map<String, dynamic> row, {List<ItineraryDay> itinerary = const []}) {
  final municipality = row['municipality'] as Map<String, dynamic>?;
  return Event(
    id: row['event_id'].toString(),
    name: row['event_name'] as String,
    startDate: DateTime.parse(row['start_date'] as String),
    endDate: DateTime.parse(row['end_date'] as String),
    municipality: municipality?['municipality_name'] as String? ?? '',
    coverImageUrl: row['banner_image_url'] as String? ?? '',
    // No popularity column exists yet — 'active' events are treated as
    // popular as a stand-in until a real signal (e.g. favorite/schedule
    // counts) is added.
    isPopular: row['status'] == 'active',
    description: row['description'] as String? ?? '',
    itinerary: itinerary,
  );
}

/// Expects a row from `sub_activity`, optionally joined with
/// `event(banner_image_url)` and `venue(venue_name)` (see
/// [subActivitySelectWithJoins]).
Activity activityFromRow(Map<String, dynamic> row) {
  final startTime = DateTime.parse(row['start_time'] as String);
  final endTime = DateTime.parse(row['end_time'] as String);
  final event = row['event'] as Map<String, dynamic>?;
  final venue = row['venue'] as Map<String, dynamic>?;
  return Activity(
    id: row['subactivity_id'].toString(),
    eventId: row['event_id'].toString(),
    title: row['activity_name'] as String,
    activityDate: startTime,
    startTime: formatTimeOfDay(startTime),
    endTime: formatTimeOfDay(endTime),
    venue: venue?['venue_name'] as String? ?? '',
    // sub_activity has no image column of its own — reusing the parent
    // event's banner image, per explicit decision (no per-activity images
    // exist yet).
    imageUrl: event?['banner_image_url'] as String? ?? '',
    description: row['description'] as String? ?? '',
    latitude: (venue?['latitude'] as num?)?.toDouble(),
    longitude: (venue?['longitude'] as num?)?.toDouble(),
  );
}

/// Parses `value` as a single date, tolerating a `"<date> - <date>"` range
/// string by using just the first date instead of crashing on it. Some
/// itinerary_items rows have been seeded (e.g. via manual test data) with a
/// display-style date range in event_date instead of a single date — that
/// range text is only ever meant for display (see formatDateRange), never
/// for feeding back into a date parser, so this is the one place that
/// tolerates it rather than every date field defensively guessing.
DateTime parseFlexibleDate(String value) {
  try {
    return DateTime.parse(value);
  } on FormatException {
    final parts = value.split(' - ');
    if (parts.length >= 2) {
      return DateTime.parse(parts.first.trim());
    }
    rethrow;
  }
}

/// Expects a row from `itinerary_items`, joined with
/// `sub_activity($subActivitySelectWithJoins)`. Returns null when there's no
/// linked sub_activity (subactivity_id is null — either never set, e.g. by
/// the legacy event-level itinerary_service.dart write path, or nulled out
/// by sub_activity's ON DELETE SET NULL) — such a row can't be resolved to
/// a real, navigable Activity, so it's skipped rather than shown as an
/// entry that would 404 if tapped.
ItineraryEntry? itineraryEntryFromRow(Map<String, dynamic> row) {
  final subActivityRow = row['sub_activity'] as Map<String, dynamic>?;
  if (subActivityRow == null) return null;

  final activity = activityFromRow(subActivityRow);
  final eventDate = parseFlexibleDate(row['event_date'] as String);

  return ItineraryEntry(
    activityId: activity.id,
    activity: activity,
    date: eventDate,
    addedAt: DateTime.parse(row['created_at'] as String),
  );
}

/// "GV-2025-######"
String generatePassCode() {
  final sixDigits = Random().nextInt(900000) + 100000; // always 6 digits
  return 'GV-2025-$sixDigits';
}

/// Age in whole years as of [now] (defaults to the real current time; pass
/// an explicit [now] in tests for a deterministic result).
int calculateAge(DateTime dateOfBirth, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dateOfBirth.year;
  final hasHadBirthdayThisYear = (today.month > dateOfBirth.month) ||
      (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
  if (!hasHadBirthdayThisYear) age--;
  return age;
}

/// "2026-08-06" — the way Postgres `date` columns expect a value over REST.
String formatDateForSupabase(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Expects a row returned by the `nearby_activities` RPC — see its
/// `RETURNS TABLE` shape in
/// supabase/migrations/20260807000000_add_postgis_venue_spatial_search.sql.
NearbyActivity nearbyActivityFromRow(Map<String, dynamic> row) {
  return NearbyActivity(
    activityId: row['subactivity_id'].toString(),
    activityName: row['activity_name'] as String,
    eventId: row['event_id'].toString(),
    eventName: row['event_name'] as String,
    venueName: row['venue_name'] as String? ?? '',
    distanceMeters: (row['distance_meters'] as num).toDouble(),
  );
}

/// Maps a [Registration] to the row shape `arrival_cards` expects, filling
/// both the pre-existing thin columns (full_name, age, sex, duration,
/// municipality) and the columns added for the full registration flow.
Map<String, dynamic> registrationToArrivalCardRow(
  Registration registration, {
  required String userId,
  required String passCode,
  DateTime? now,
}) {
  return {
    'user_id': userId,
    // Pre-existing columns, kept filled for backward compatibility with the
    // original Tourist Arrival Card feature that still reads this table.
    'full_name': registration.fullName,
    'age': calculateAge(registration.dateOfBirth, now: now),
    'sex': registration.gender,
    'duration': registration.dateOfDeparture
        .difference(registration.dateOfArrival)
        .inDays,
    'municipality': registration.municipalitiesToVisit.isNotEmpty
        ? registration.municipalitiesToVisit.first
        : null,
    // Columns added for the full Pre-Arrival Registration flow.
    'nationality': registration.nationality,
    'date_of_birth': formatDateForSupabase(registration.dateOfBirth),
    'email': registration.email,
    'mobile_number': registration.mobileNumber,
    'date_of_arrival': formatDateForSupabase(registration.dateOfArrival),
    'port_of_entry': registration.portOfEntry,
    'date_of_departure': formatDateForSupabase(registration.dateOfDeparture),
    'traveling_with': registration.travelingWith,
    'purpose_of_visit': registration.purposeOfVisit,
    'municipalities_to_visit': registration.municipalitiesToVisit,
    'pass_code': passCode,
    'valid_from': formatDateForSupabase(registration.dateOfArrival),
    'valid_to': formatDateForSupabase(registration.dateOfDeparture),
  };
}

/// Inverse of [registrationToArrivalCardRow] — reconstructs a [Registration]
/// from an `arrival_cards` row. Reads the full-flow columns (nationality,
/// date_of_birth, etc.) rather than the older thin columns (full_name, age,
/// sex), since every row written by submit() fills both, and the full-flow
/// columns are the ones with the shape Registration actually needs.
/// municipalities_to_visit falls back to a single-item list built from the
/// legacy `municipality` column when null, so rows from before that array
/// column existed still round-trip into a non-empty list.
Registration registrationFromArrivalCardRow(Map<String, dynamic> row) {
  final municipalitiesToVisit = row['municipalities_to_visit'] as List<dynamic>?;
  final legacyMunicipality = row['municipality'] as String?;
  return Registration(
    fullName: row['full_name'] as String? ?? '',
    nationality: row['nationality'] as String? ?? '',
    dateOfBirth: DateTime.parse(row['date_of_birth'] as String),
    gender: row['sex'] as String? ?? '',
    email: row['email'] as String? ?? '',
    mobileNumber: row['mobile_number'] as String? ?? '',
    dateOfArrival: DateTime.parse(row['date_of_arrival'] as String),
    portOfEntry: row['port_of_entry'] as String? ?? '',
    dateOfDeparture: DateTime.parse(row['date_of_departure'] as String),
    travelingWith: row['traveling_with'] as String? ?? '',
    purposeOfVisit: row['purpose_of_visit'] as String? ?? '',
    municipalitiesToVisit: municipalitiesToVisit != null
        ? municipalitiesToVisit.cast<String>()
        : (legacyMunicipality != null ? [legacyMunicipality] : const []),
    passCode: row['pass_code'] as String?,
    validFrom: row['valid_from'] != null
        ? DateTime.parse(row['valid_from'] as String)
        : null,
    validTo: row['valid_to'] != null
        ? DateTime.parse(row['valid_to'] as String)
        : null,
  );
}

/// Expects a row from `profiles`. full_name/mobile_number are frequently
/// empty in practice — see the doc comment on [UserProfile] for why — so
/// this maps them to '' rather than leaving null, keeping UserProfile's
/// fields non-nullable and pushing the "what to show instead" decision to
/// the UI layer (UserProfile.displayName).
UserProfile userProfileFromRow(Map<String, dynamic> row) {
  return UserProfile(
    fullName: row['full_name'] as String? ?? '',
    email: row['email'] as String? ?? '',
    mobileNumber: row['mobile_number'] as String? ?? '',
    // Left nullable (unlike the fields above) — avatarUrl == null is the
    // real "no photo uploaded yet" state UserProfile/ProfileShellScreen
    // check for, not just a blank-string placeholder.
    avatarUrl: row['avatar_url'] as String?,
  );
}
