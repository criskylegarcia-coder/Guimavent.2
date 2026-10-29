import 'package:supabase_flutter/supabase_flutter.dart';

// Session guard for the admin portal's router — separate from
// lib/router/auth_guard.dart (tourist app), which has no concept of staff.
//
// A verified-staff session is tracked with a simple in-memory flag, set
// once by AdminLoginScreen right after AdminAuthRepository.signIn()
// succeeds (which already checked profiles.staff), rather than
// re-querying profiles.staff on every navigation. Simple and sufficient
// for Batch 1 — revisit if sessions need to react to being demoted
// mid-session.
bool _isVerifiedStaff = false;

// Overridable in tests, same pattern as lib/router/auth_guard.dart's
// authSessionOverride.
bool Function()? adminSessionOverride;

bool hasVerifiedStaffSession() {
  if (adminSessionOverride != null) return adminSessionOverride!();
  return _isVerifiedStaff &&
      Supabase.instance.client.auth.currentSession != null;
}

/// Called by AdminLoginScreen right after a successful, staff-verified
/// sign-in — marks this session as usable by the admin router's redirect
/// guard.
void markStaffSessionVerified() {
  _isVerifiedStaff = true;
}

// Overridable in tests, same idea as lib/router/auth_guard.dart's
// signOutOverride.
Future<void> Function()? adminSignOutOverride;

Future<void> adminSignOut() async {
  if (adminSignOutOverride != null) {
    await adminSignOutOverride!();
  } else {
    await Supabase.instance.client.auth.signOut();
  }
  _isVerifiedStaff = false;
}
