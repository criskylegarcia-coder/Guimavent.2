import 'dart:typed_data';

import '../models/user_profile.dart';
import 'profile_repository.dart';

// Configurable so screen/widget tests can exercise both a filled-in and an
// empty profile without a real backend.
class MockProfileRepository implements ProfileRepository {
  UserProfile? seedProfile;

  MockProfileRepository({this.seedProfile});

  @override
  Future<UserProfile?> getMyProfile() async => seedProfile;

  @override
  Future<String> uploadAvatar(Uint8List imageBytes) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final url =
        'https://example.com/mock-avatar-${imageBytes.length}.jpg';
    seedProfile = (seedProfile ??
            const UserProfile(fullName: '', email: '', mobileNumber: ''))
        .copyWith(avatarUrl: url);
    return url;
  }
}
