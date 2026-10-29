import 'package:supabase_flutter/supabase_flutter.dart';

// Overridable in tests: set this to a fake () => true/false before pumping
// a widget test so route-guard tests don't need a real Supabase connection,
// then reset it to null (e.g. via addTearDown) afterward.
bool Function()? authSessionOverride;

/// Whether there's currently a signed-in Supabase session.
bool hasAuthSession() {
  if (authSessionOverride != null) return authSessionOverride!();
  return Supabase.instance.client.auth.currentSession != null;
}

// Same idea as authSessionOverride, for Profile's Logout button: lets tests
// verify sign-out was triggered without a real Supabase connection.
Future<void> Function()? signOutOverride;

/// Signs the current user out.
Future<void> signOut() async {
  if (signOutOverride != null) return signOutOverride!();
  await Supabase.instance.client.auth.signOut();
}
