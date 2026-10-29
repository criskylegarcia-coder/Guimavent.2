import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository_exception.dart';

// A tourist's arrival_cards row, as looked up by pass_code for the QR
// scanner. validFrom/validTo are nullable — older arrival_cards rows
// predate the columns Batch A added and were never backfilled, so a
// missing value means "no expiry info available", not "invalid forever".
class ArrivalCardLookup {
  final String id;
  final String fullName;
  final String nationality;
  final List<String> municipalitiesToVisit;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String passCode;

  const ArrivalCardLookup({
    required this.id,
    required this.fullName,
    required this.nationality,
    required this.municipalitiesToVisit,
    required this.validFrom,
    required this.validTo,
    required this.passCode,
  });
}

class ArrivalPort {
  final String id;
  final String name;

  const ArrivalPort({required this.id, required this.name});
}

// An existing admin_checkin_log entry for an arrival card, if any — used
// to warn staff before logging a second check-in for the same tourist.
class CheckinStatus {
  final DateTime checkedInAt;
  final String checkedInByName;

  const CheckinStatus({
    required this.checkedInAt,
    required this.checkedInByName,
  });
}

// Admin-only reads/writes for the QR Scanner check-in flow (Batch 3).
// Split into its own repository, same reasoning as Batch 2's
// AdminVenueRepository — a genuinely different concern from events/venues,
// kept focused.
abstract class AdminCheckinRepository {
  /// Looks up an arrival_cards row by its pass_code (what the tourist
  /// app's QR actually encodes — see registration_success_screen.dart).
  /// Null if no arrival card has this pass_code.
  Future<ArrivalCardLookup?> lookupArrivalCard(String passCode);

  /// The most recent existing check-in for this arrival card, if any.
  Future<CheckinStatus?> getCheckinStatus(String arrivalCardId);

  /// Logs a check-in for the current staff user. portId is optional — see
  /// QrScannerScreen's port picker.
  Future<void> recordCheckin({required String arrivalCardId, String? portId});

  Future<List<ArrivalPort>> getPorts();
}

class SupabaseAdminCheckinRepository implements AdminCheckinRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<ArrivalCardLookup?> lookupArrivalCard(String passCode) async {
    try {
      final row = await _client
          .from('arrival_cards')
          .select()
          .eq('pass_code', passCode)
          .maybeSingle();
      if (row == null) return null;
      return _arrivalCardFromRow(row);
    } catch (e) {
      throw RepositoryException('Could not look up pass code: $e');
    }
  }

  @override
  Future<CheckinStatus?> getCheckinStatus(String arrivalCardId) async {
    try {
      final row = await _client
          .from('admin_checkin_log')
          .select('checked_in_at, checked_in_by')
          .eq('arrival_card_id', arrivalCardId)
          .order('checked_in_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;

      // admin_checkin_log.checked_in_by references auth.users(id), not
      // profiles(id) — there's no FK from admin_checkin_log to profiles
      // for PostgREST to auto-embed through (confirmed: embedding
      // profiles(...) directly here throws PGRST200, "Could not find a
      // relationship"). Looked up separately instead.
      final checkedInBy = row['checked_in_by'] as String;
      var staffLabel = 'a staff member';
      try {
        final profileRow = await _client
            .from('profiles')
            .select('full_name, email')
            .eq('id', checkedInBy)
            .maybeSingle();
        final staffName = (profileRow?['full_name'] as String?)?.trim();
        final staffEmail = profileRow?['email'] as String?;
        if (staffName != null && staffName.isNotEmpty) {
          staffLabel = staffName;
        } else if (staffEmail != null && staffEmail.isNotEmpty) {
          staffLabel = staffEmail;
        }
      } catch (_) {
        // Non-critical — the check-in itself is still real and worth
        // reporting even if the staff member's name can't be resolved.
      }

      return CheckinStatus(
        checkedInAt: DateTime.parse(row['checked_in_at'] as String),
        checkedInByName: staffLabel,
      );
    } catch (e) {
      throw RepositoryException('Could not check check-in status: $e');
    }
  }

  @override
  Future<void> recordCheckin({
    required String arrivalCardId,
    String? portId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const RepositoryException('You must be signed in.');
      }
      await _client.from('admin_checkin_log').insert({
        'arrival_card_id': arrivalCardId,
        'checked_in_by': userId,
        if (portId != null) 'port_id': int.parse(portId),
      });
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not record check-in: $e');
    }
  }

  @override
  Future<List<ArrivalPort>> getPorts() async {
    try {
      final rows = await _client
          .from('arrival_port')
          .select('port_id, port_name')
          // ascending: true required — package:postgrest's order() defaults
          // to descending; see supabase_event_repository.dart's
          // getUpcomingEvents() for the full explanation.
          .order('port_name', ascending: true);
      return [
        for (final row in rows)
          ArrivalPort(
            id: row['port_id'].toString(),
            name: row['port_name'] as String,
          ),
      ];
    } catch (e) {
      throw RepositoryException('Could not load ports: $e');
    }
  }

  ArrivalCardLookup _arrivalCardFromRow(Map<String, dynamic> row) {
    final municipalities = row['municipalities_to_visit'];
    return ArrivalCardLookup(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? '',
      nationality: row['nationality'] as String? ?? '',
      municipalitiesToVisit: municipalities is List
          ? municipalities.map((e) => e.toString()).toList()
          : const [],
      validFrom: row['valid_from'] != null
          ? DateTime.parse(row['valid_from'] as String)
          : null,
      validTo: row['valid_to'] != null
          ? DateTime.parse(row['valid_to'] as String)
          : null,
      passCode: row['pass_code'] as String? ?? '',
    );
  }
}

// For tests/previews — no real Supabase connection needed.
class MockAdminCheckinRepository implements AdminCheckinRepository {
  final Map<String, ArrivalCardLookup> cardsByPassCode;
  final Map<String, CheckinStatus> checkinsByCardId;
  final List<ArrivalPort> ports;

  MockAdminCheckinRepository({
    Map<String, ArrivalCardLookup>? cardsByPassCode,
    Map<String, CheckinStatus>? checkinsByCardId,
    this.ports = const [],
  }) : cardsByPassCode = cardsByPassCode ?? {},
       checkinsByCardId = checkinsByCardId ?? {};

  @override
  Future<ArrivalCardLookup?> lookupArrivalCard(String passCode) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return cardsByPassCode[passCode];
  }

  @override
  Future<CheckinStatus?> getCheckinStatus(String arrivalCardId) async {
    return checkinsByCardId[arrivalCardId];
  }

  @override
  Future<void> recordCheckin({
    required String arrivalCardId,
    String? portId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    checkinsByCardId[arrivalCardId] = CheckinStatus(
      checkedInAt: DateTime.now(),
      checkedInByName: 'Test Officer',
    );
  }

  @override
  Future<List<ArrivalPort>> getPorts() async => ports;
}
