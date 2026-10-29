import 'dart:typed_data';

import '../models/user_profile.dart';

// The contract ProfileShellScreen depends on. Screens must only ever import
// THIS file, never MockProfileRepository or SupabaseProfileRepository
// directly.
abstract class ProfileRepository {
  /// The current user's profile, or null if they have none on file (should
  /// only happen if the profiles row somehow wasn't created at signup).
  Future<UserProfile?> getMyProfile();

  /// Uploads [imageBytes] (already center-cropped to a square — see
  /// utils/image_crop.dart) as the current user's avatar, stamps the
  /// resulting public URL onto their profile record, and returns that URL.
  Future<String> uploadAvatar(Uint8List imageBytes);
}
