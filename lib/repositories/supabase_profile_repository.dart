import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'profile_repository.dart';
import 'repository_exception.dart';
import 'supabase_row_mappers.dart';

// Real, Supabase-backed ProfileRepository. Reads the `profiles` table row
// created by the on_auth_user_created trigger — see
// supabase/migrations/20260806000000_extend_arrival_itinerary_add_profiles_rsvp_favorites.sql.
// Avatar uploads go to the "avatars" Storage bucket — see
// supabase/migrations/20260901000000_add_avatars_storage_bucket.sql.
class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<UserProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return userProfileFromRow(row);
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const RepositoryException('You must be signed in.');
    }
    try {
      // Fixed filename per user (not a timestamped one) so re-uploads
      // overwrite in place via upsert instead of accumulating orphaned
      // files in storage.
      final path = '$userId/avatar.jpg';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
      // The path (and so the URL) is the same on every re-upload — a
      // cache-busting query param forces Image.network (and any CDN in
      // front of Storage) to actually fetch the new bytes instead of
      // serving a stale cached copy of the previous photo at that URL.
      final freshUrl =
          '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';
      await _client
          .from('profiles')
          .update({'avatar_url': freshUrl})
          .eq('id', userId);
      return freshUrl;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('Could not upload your photo: $e');
    }
  }
}
