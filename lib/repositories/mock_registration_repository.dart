import 'dart:math';

import '../models/registration.dart';
import 'registration_repository.dart';

// Pretends to save the registration and hands back a fake pass code.
// Later, create a SupabaseRegistrationRepository that implements the same
// RegistrationRepository contract and swap it in — no screen code needs
// to change.
class MockRegistrationRepository implements RegistrationRepository {
  final Random _random = Random();

  // Configurable so screen/widget tests can exercise both the
  // registered and unregistered states without a real backend.
  Registration? seedRegistration;

  MockRegistrationRepository({this.seedRegistration});

  @override
  Future<String> submit(Registration registration) async {
    // Simulates a network call so the Review step's loading state has
    // something to show.
    await Future.delayed(const Duration(seconds: 1));
    final sixDigits = _random.nextInt(900000) + 100000; // always 6 digits
    final passCode = 'GV-2025-$sixDigits';
    seedRegistration = registration.copyWith(passCode: passCode);
    return passCode;
  }

  @override
  Future<bool> hasActiveRegistration() async => seedRegistration != null;

  @override
  Future<Registration?> getMyRegistration() async => seedRegistration;
}
