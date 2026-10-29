// A tourist's profile, mirroring the `profiles` table auto-created via a
// trigger on signup (see
// supabase/migrations/20260806000000_extend_arrival_itinerary_add_profiles_rsvp_favorites.sql).
// fullName/mobileNumber can legitimately be empty: the trigger only fills
// full_name from signup metadata, which register_screen.dart's signUp()
// call doesn't currently send, and mobile_number is never set by any
// current flow.
class UserProfile {
  final String fullName;
  final String email;
  final String mobileNumber;
  // Null/empty until the user uploads one via ProfileShellScreen's avatar
  // tap — see ProfileRepository.uploadAvatar().
  final String? avatarUrl;

  const UserProfile({
    required this.fullName,
    required this.email,
    required this.mobileNumber,
    this.avatarUrl,
  });

  /// Best available label for a name field: the real full_name if the user
  /// has one on file, otherwise their email rather than a blank string.
  String get displayName => fullName.isNotEmpty ? fullName : email;

  // Used to stamp in a freshly-uploaded avatarUrl without needing to
  // re-type every other field.
  UserProfile copyWith({String? avatarUrl}) {
    return UserProfile(
      fullName: fullName,
      email: email,
      mobileNumber: mobileNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
