import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/arrival_model.dart';

class ArrivalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ArrivalPort>> getPorts() async {
    final response = await _supabase
        .from('arrival_port')
        .select()
        .order('port_name');

    return response
        .map<ArrivalPort>((e) => ArrivalPort.fromJson(e))
        .toList();
  }
}