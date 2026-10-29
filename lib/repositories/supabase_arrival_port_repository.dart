import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/arrival_port.dart';
import 'arrival_port_repository.dart';
import 'repository_exception.dart';

class SupabaseArrivalPortRepository implements ArrivalPortRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<ArrivalPort>> getPorts() async {
    try {
      final rows = await _client
          .from('arrival_port')
          .select('port_id, port_name, latitude, longitude')
          // ascending: true required — package:postgrest's order() defaults
          // to descending; see supabase_event_repository.dart's
          // getUpcomingEvents() for the full explanation.
          .order('port_name', ascending: true);
      return [
        for (final row in rows)
          ArrivalPort(
            id: row['port_id'].toString(),
            name: row['port_name'] as String,
            latitude: (row['latitude'] as num).toDouble(),
            longitude: (row['longitude'] as num).toDouble(),
          ),
      ];
    } catch (e) {
      throw RepositoryException('Could not load arrival ports: $e');
    }
  }
}
