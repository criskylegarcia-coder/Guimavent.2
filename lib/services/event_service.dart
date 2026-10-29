import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getEvents() async {
    final data = await _supabase
        .from('event')
        .select();

    debugPrint("SUPABASE DATA: $data");

    return List<Map<String, dynamic>>.from(data);
  }
}