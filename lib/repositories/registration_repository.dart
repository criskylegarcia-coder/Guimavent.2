import '../models/registration.dart';

// The contract RegistrationShellScreen depends on. Screens must only ever
// import THIS file, never MockRegistrationRepository or (later) a
// SupabaseRegistrationRepository directly.
abstract class RegistrationRepository {
  /// Submits the registration and returns a generated pass code in the
  /// format "GV-2025-######".
  Future<String> submit(Registration registration);

  /// Whether the current user has any Pre-Arrival Registration on file.
  /// Existence-based (not a valid_from/valid_to date-range check) — see
  /// getMyRegistration() doc comment for why.
  Future<bool> hasActiveRegistration();

  /// The current user's most recent registration, or null if they have
  /// none. Reconstructed from the arrival_cards row this user last
  /// submitted — some older rows may have null valid_from/valid_to (those
  /// columns were added after the table already had data, with no
  /// backfill), so callers should treat any returned Registration as "on
  /// file" rather than relying on validFrom/validTo being present.
  Future<Registration?> getMyRegistration();
}
