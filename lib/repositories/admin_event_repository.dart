import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_exception.dart';
import 'supabase_row_mappers.dart';

// One event row, admin-shape: unlike models/event.dart's Event (built for
// the tourist app's display needs — municipality NAME, derived isPopular
// bool), this carries the raw municipality_id and status string the admin
// create/edit form and list actually need to round-trip writes correctly.
// Intentionally not reusing Event — it would lose exactly the fields admin
// writes require.
class AdminEvent {
  final String id;
  final String name;
  final String description;
  final String municipalityId;
  final String municipalityName;
  final DateTime startDate;
  final DateTime endDate;
  final String bannerImageUrl;
  final String status;

  const AdminEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.municipalityId,
    required this.municipalityName,
    required this.startDate,
    required this.endDate,
    required this.bannerImageUrl,
    required this.status,
  });
}

// Admin-only writes for `event` (Batch 1). Deliberately separate from
// EventRepository (lib/repositories/event_repository.dart), which the
// tourist app's screens depend on — adding createEvent/updateEvent/
// deleteEvent there would force every tourist-side implementer (including
// MockEventRepository, used throughout the tourist app's tests) to
// implement admin-only write methods it never needs. Read access for the
// tourist app is untouched; this repository adds its own getAllEvents()
// because it needs the raw municipality_id/status shape above, not
// EventRepository's display-ready Event.
abstract class AdminEventRepository {
  Future<List<AdminEvent>> getAllEvents();

  Future<void> createEvent({
    required String name,
    required String description,
    required String municipalityId,
    required DateTime startDate,
    required DateTime endDate,
    required String bannerImageUrl,
    required String status,
  });

  Future<void> updateEvent(
    String eventId, {
    required String name,
    required String description,
    required String municipalityId,
    required DateTime startDate,
    required DateTime endDate,
    required String bannerImageUrl,
    required String status,
  });

  Future<void> deleteEvent(String eventId);
}

class SupabaseAdminEventRepository implements AdminEventRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<AdminEvent>> getAllEvents() async {
    try {
      final rows = await _client
          .from('event')
          .select('*, municipality(municipality_name)')
          // ascending: true required — package:postgrest's order() defaults
          // to descending; see supabase_event_repository.dart's
          // getUpcomingEvents() for the full explanation.
          .order('start_date', ascending: true);
      return [for (final row in rows) _adminEventFromRow(row)];
    } catch (e) {
      throw RepositoryException('Could not load events: $e');
    }
  }

  @override
  Future<void> createEvent({
    required String name,
    required String description,
    required String municipalityId,
    required DateTime startDate,
    required DateTime endDate,
    required String bannerImageUrl,
    required String status,
  }) async {
    try {
      // created_by_user_id (int, referencing the legacy pre-Auth `users`
      // table — see supabase_registration_repository.dart's notes on other
      // deprecated tables) is deliberately omitted: there's no valid value
      // to derive from a Supabase Auth uuid for it. If event creation fails
      // on a NOT NULL violation for this column, it needs a real default or
      // to be made nullable in Table Editor — flagging rather than guessing.
      await _client.from('event').insert({
        'event_name': name,
        'description': description,
        'municipality_id': int.parse(municipalityId),
        'start_date': formatDateForSupabase(startDate),
        'end_date': formatDateForSupabase(endDate),
        'banner_image_url': bannerImageUrl,
        'status': status,
      });
    } catch (e) {
      throw RepositoryException('Could not create event: $e');
    }
  }

  @override
  Future<void> updateEvent(
    String eventId, {
    required String name,
    required String description,
    required String municipalityId,
    required DateTime startDate,
    required DateTime endDate,
    required String bannerImageUrl,
    required String status,
  }) async {
    try {
      final eventIdInt = int.parse(eventId);
      await _client
          .from('event')
          .update({
            'event_name': name,
            'description': description,
            'municipality_id': int.parse(municipalityId),
            'start_date': formatDateForSupabase(startDate),
            'end_date': formatDateForSupabase(endDate),
            'banner_image_url': bannerImageUrl,
            'status': status,
          })
          .eq('event_id', eventIdInt);
    } catch (e) {
      throw RepositoryException('Could not update event: $e');
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      final eventIdInt = int.parse(eventId);
      await _client.from('event').delete().eq('event_id', eventIdInt);
    } catch (e) {
      throw RepositoryException('Could not delete event: $e');
    }
  }

  AdminEvent _adminEventFromRow(Map<String, dynamic> row) {
    final municipality = row['municipality'] as Map<String, dynamic>?;
    return AdminEvent(
      id: row['event_id'].toString(),
      name: row['event_name'] as String,
      description: row['description'] as String? ?? '',
      municipalityId: row['municipality_id'].toString(),
      municipalityName:
          municipality?['municipality_name'] as String? ?? '',
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      bannerImageUrl: row['banner_image_url'] as String? ?? '',
      status: row['status'] as String? ?? 'active',
    );
  }
}

// For tests/previews — no real Supabase connection needed.
class MockAdminEventRepository implements AdminEventRepository {
  // id -> name, so created/updated events can show a real municipality name
  // the same way the Supabase implementation's join would.
  final Map<String, String> municipalityNames;
  final List<AdminEvent> _events;
  int _nextId;

  MockAdminEventRepository({
    required this.municipalityNames,
    List<AdminEvent>? seedEvents,
  }) : _events = seedEvents ?? [],
       _nextId = 1000;

  @override
  Future<List<AdminEvent>> getAllEvents() async => List.unmodifiable(_events);

  @override
  Future<void> createEvent({
    required String name,
    required String description,
    required String municipalityId,
    required DateTime startDate,
    required DateTime endDate,
    required String bannerImageUrl,
    required String status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _events.add(
      AdminEvent(
        id: (_nextId++).toString(),
        name: name,
        description: description,
        municipalityId: municipalityId,
        municipalityName: municipalityNames[municipalityId] ?? '',
        startDate: startDate,
        endDate: endDate,
        bannerImageUrl: bannerImageUrl,
        status: status,
      ),
    );
  }

  @override
  Future<void> updateEvent(
    String eventId, {
    required String name,
    required String description,
    required String municipalityId,
    required DateTime startDate,
    required DateTime endDate,
    required String bannerImageUrl,
    required String status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index == -1) {
      throw const RepositoryException('Event not found.');
    }
    _events[index] = AdminEvent(
      id: eventId,
      name: name,
      description: description,
      municipalityId: municipalityId,
      municipalityName: municipalityNames[municipalityId] ?? '',
      startDate: startDate,
      endDate: endDate,
      bannerImageUrl: bannerImageUrl,
      status: status,
    );
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _events.removeWhere((event) => event.id == eventId);
  }
}
