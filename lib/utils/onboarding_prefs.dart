import 'package:shared_preferences/shared_preferences.dart';

const String _hasSeenOnboardingKey = 'has_seen_onboarding';

/// Whether the user has ever completed or skipped the onboarding
/// walkthrough — checked once by SplashScreen so it only ever shows on the
/// very first launch, not on every restart.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hasSeenOnboardingKey) ?? false;
}

/// Marks onboarding as seen, whether the user finished it or tapped Skip —
/// either way there's no reason to show it again.
Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hasSeenOnboardingKey, true);
}
