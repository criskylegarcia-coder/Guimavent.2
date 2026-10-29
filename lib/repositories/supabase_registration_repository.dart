import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registration.dart';
import 'registration_repository.dart';
import 'repository_exception.dart';
import 'supabase_row_mappers.dart';

// Real, Supabase-backed RegistrationRepository. Writes into arrival_cards —
// the same table the original Tourist Arrival Card feature
// (arrival_card_screen.dart) uses, extended with the full registration
// flow's columns. See registrationToArrivalCardRow() in
// supabase_row_mappers.dart for the exact field mapping.
class SupabaseRegistrationRepository implements RegistrationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<String> submit(Registration registration) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const RepositoryException('You must be signed in to register.');
    }

    final passCode = generatePassCode();
    try {
      await _client.from('arrival_cards').insert(
        registrationToArrivalCardRow(
          registration,
          userId: userId,
          passCode: passCode,
        ),
      );
      return passCode;
    } catch (e) {
      throw RepositoryException('Could not submit registration: $e');
    }
  }

  @override
  Future<bool> hasActiveRegistration() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    // Existence-based, not a valid_from/valid_to range check: those columns
    // were added to arrival_cards later via ADD COLUMN IF NOT EXISTS with
    // no backfill, so older rows may have them null — a strict date-range
    // check would wrongly treat a real, on-file registration as inactive.
    final rows = await _client
        .from('arrival_cards')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  @override
  Future<Registration?> getMyRegistration() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _client
        .from('arrival_cards')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return registrationFromArrivalCardRow(list.first as Map<String, dynamic>);
  }
}
