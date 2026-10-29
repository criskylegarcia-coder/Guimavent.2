import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_exception.dart';

// One venue row, admin-shape — raw municipality_id (not just the display
// name) so the edit form can pre-select the right dropdown item.
class AdminVenue {
  final String id;
  final String name;
  final String municipalityId;
  final String municipalityName;
  final String venueType;
  final String addressDescription;
  final double latitude;
  final double longitude;

  const AdminVenue({
    required this.id,
    required this.name,
    required this.municipalityId,
    required this.municipalityName,
    required this.venueType,
    required this.addressDescription,
    required this.latitude,
    required this.longitude,
  });
}

// Admin-only writes for `venue` (Batch 2). Split out from
// AdminEventRepository (which originally carried a stopgap getVenueCount()
// for the dashboard, now moved here) — same reasoning as Batch 1's
// event/tourist EventRepository split: venue reads/writes are a genuinely
// different concern from events, and this keeps each repository focused.
//
// venue.location (the PostGIS geography column) is not written here at
// all — it auto-syncs from latitude/longitude via the trigger added in an
// earlier migration, so this repository only ever needs to write plain
// lat/lng, same as the tourist app already does implicitly by never
// touching PostGIS directly.
abstract class AdminVenueRepository {
  Future<List<AdminVenue>> getAllVenues();

  Future<int> getVenueCount();

  Future<void> createVenue({
    required String name,
    required String municipalityId,
    required String venueType,
    required String addressDescription,
    required double latitude,
    required double longitude,
  });

  Future<void> updateVenue(
    String venueId, {
    required String name,
    required String municipalityId,
    required String venueType,
    required String addressDescription,
    required double latitude,
    required double longitude,
  });

  Future<void> deleteVenue(String venueId);

  /// How many sub_activity rows currently reference this venue — used to
  /// warn staff before a delete. Postgres' default FK behavior (NO ACTION,
  /// unless a migration says otherwise) rejects the delete outright with a
  /// constraint-violation error if this is non-zero; either way, staff
  /// should see this before attempting it, not after a cryptic DB error.
  Future<int> countReferencingSubActivities(String venueId);
}

class SupabaseAdminVenueRepository implements AdminVenueRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<AdminVenue>> getAllVenues() async {
    const selectClause = '*, municipality(municipality_name)';
    debugPrint(
      "[SupabaseAdminVenueRepository] getAllVenues: querying "
      "venue?select=$selectClause&order=venue_name",
    );
    try {
      final rows = await _client
          .from('venue')
          .select(selectClause)
          // ascending: true required — package:postgrest's order() defaults
          // to descending; see supabase_event_repository.dart's
          // getUpcomingEvents() for the full explanation.
          .order('venue_name', ascending: true);
      debugPrint(
        '[SupabaseAdminVenueRepository] getAllVenues: raw response has '
        '${rows.length} row(s)',
      );
      final venues = [for (final row in rows) _adminVenueFromRow(row)];
      debugPrint(
        '[SupabaseAdminVenueRepository] getAllVenues: mapped '
        '${venues.length} AdminVenue object(s): '
        '${venues.map((v) => '${v.id}:${v.name}').join(', ')}',
      );
      return venues;
    } catch (e, st) {
      debugPrint('[SupabaseAdminVenueRepository] getAllVenues: THREW: $e\n$st');
      throw RepositoryException('Could not load venues: $e');
    }
  }

  @override
  Future<int> getVenueCount() async {
    try {
      final rows = await _client.from('venue').select('venue_id');
      return rows.length;
    } catch (e) {
      throw RepositoryException('Could not load venue count: $e');
    }
  }

  @override
  Future<void> createVenue({
    required String name,
    required String municipalityId,
    required String venueType,
    required String addressDescription,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // registered_by_user_id (int, referencing the legacy pre-Auth `users`
      // table, same situation as event.created_by_user_id in Batch 1) is
      // deliberately omitted — no valid value to derive from a Supabase
      // Auth uuid. If venue creation fails on a NOT NULL violation for this
      // column, it needs a real default or to be made nullable — flagging
      // rather than guessing.
      await _client.from('venue').insert({
        'venue_name': name,
        'municipality_id': int.parse(municipalityId),
        'venue_type': venueType,
        'address_description': addressDescription,
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      throw RepositoryException('Could not create venue: $e');
    }
  }

  @override
  Future<void> updateVenue(
    String venueId, {
    required String name,
    required String municipalityId,
    required String venueType,
    required String addressDescription,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final venueIdInt = int.parse(venueId);
      await _client
          .from('venue')
          .update({
            'venue_name': name,
            'municipality_id': int.parse(municipalityId),
            'venue_type': venueType,
            'address_description': addressDescription,
            'latitude': latitude,
            'longitude': longitude,
          })
          .eq('venue_id', venueIdInt);
    } catch (e) {
      throw RepositoryException('Could not update venue: $e');
    }
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    try {
      final venueIdInt = int.parse(venueId);
      await _client.from('venue').delete().eq('venue_id', venueIdInt);
    } catch (e) {
      throw RepositoryException('Could not delete venue: $e');
    }
  }

  @override
  Future<int> countReferencingSubActivities(String venueId) async {
    try {
      final venueIdInt = int.parse(venueId);
      final rows = await _client
          .from('sub_activity')
          .select('subactivity_id')
          .eq('venue_id', venueIdInt);
      return rows.length;
    } catch (e) {
      throw RepositoryException('Could not check venue references: $e');
    }
  }

  AdminVenue _adminVenueFromRow(Map<String, dynamic> row) {
    final municipality = row['municipality'] as Map<String, dynamic>?;
    return AdminVenue(
      id: row['venue_id'].toString(),
      name: row['venue_name'] as String,
      municipalityId: row['municipality_id'].toString(),
      municipalityName: municipality?['municipality_name'] as String? ?? '',
      venueType: row['venue_type'] as String? ?? '',
      addressDescription: row['address_description'] as String? ?? '',
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
    );
  }
}

// For tests/previews — no real Supabase connection needed.
class MockAdminVenueRepository implements AdminVenueRepository {
  // id -> name, so created/updated venues can show a real municipality
  // name the same way the Supabase implementation's join would.
  final Map<String, String> municipalityNames;
  final List<AdminVenue> _venues;
  // Simulates which venues have referencing sub_activity rows, for testing
  // the delete-warning/rejection flow without a real DB.
  final Set<String> referencedVenueIds;
  int _nextId;

  MockAdminVenueRepository({
    required this.municipalityNames,
    List<AdminVenue>? seedVenues,
    Set<String>? referencedVenueIds,
  }) : _venues = seedVenues ?? [],
       referencedVenueIds = referencedVenueIds ?? {},
       _nextId = 1000;

  @override
  Future<List<AdminVenue>> getAllVenues() async => List.unmodifiable(_venues);

  @override
  Future<int> getVenueCount() async => _venues.length;

  @override
  Future<void> createVenue({
    required String name,
    required String municipalityId,
    required String venueType,
    required String addressDescription,
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _venues.add(
      AdminVenue(
        id: (_nextId++).toString(),
        name: name,
        municipalityId: municipalityId,
        municipalityName: municipalityNames[municipalityId] ?? '',
        venueType: venueType,
        addressDescription: addressDescription,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  Future<void> updateVenue(
    String venueId, {
    required String name,
    required String municipalityId,
    required String venueType,
    required String addressDescription,
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _venues.indexWhere((venue) => venue.id == venueId);
    if (index == -1) {
      throw const RepositoryException('Venue not found.');
    }
    _venues[index] = AdminVenue(
      id: venueId,
      name: name,
      municipalityId: municipalityId,
      municipalityName: municipalityNames[municipalityId] ?? '',
      venueType: venueType,
      addressDescription: addressDescription,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (referencedVenueIds.contains(venueId)) {
      throw const RepositoryException(
        'Could not delete venue: it is still referenced by one or more '
        'scheduled activities.',
      );
    }
    _venues.removeWhere((venue) => venue.id == venueId);
  }

  @override
  Future<int> countReferencingSubActivities(String venueId) async {
    return referencedVenueIds.contains(venueId) ? 1 : 0;
  }
}
