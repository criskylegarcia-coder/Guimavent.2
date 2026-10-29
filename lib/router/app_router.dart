import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/event.dart';
import '../models/registration.dart';
import '../screens/activities/activity_details_shell_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/events/event_details_shell_screen.dart';
import '../screens/events/events_shell_screen.dart';
import '../screens/home/home_shell_screen.dart';
import '../screens/itinerary/my_itinerary_shell_screen.dart';
import '../screens/map/map_directions_shell_screen.dart';
import '../screens/map/turn_by_turn_navigation_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/about_screen.dart';
import '../screens/profile/help_support_screen.dart';
import '../screens/profile/notification_center_screen.dart';
import '../screens/profile/profile_shell_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/registration/registration_shell_screen.dart';
import '../screens/registration/registration_success_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/welcome/welcome_screen.dart';
import 'auth_guard.dart';
import 'main_shell_screen.dart';
import 'page_transitions.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

// Routes reachable without being signed in. Everything else redirects to
// /login when there's no Supabase session.
const Set<String> _publicPaths = {
  '/splash',
  '/onboarding',
  '/welcome',
  '/login',
  '/signup',
};

// One route per bottom-nav tab. StatefulShellRoute keeps each tab's own
// navigation stack alive when you switch away and back.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  redirect: (context, state) {
    final target = state.matchedLocation;
    final hasSession = hasAuthSession();
    if (_publicPaths.contains(target)) {
      debugPrint('[Router] redirect: target=$target is public, hasSession=$hasSession -> no redirect');
      return null;
    }
    if (!hasSession) {
      debugPrint('[Router] redirect: target=$target, hasSession=false -> redirecting to /login');
      return '/login';
    }
    debugPrint('[Router] redirect: target=$target, hasSession=true -> no redirect');
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShellScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeShellScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => EventsShellScreen(
                initialQuery: state.uri.queryParameters['q'],
                initialMunicipality: state.uri.queryParameters['municipality'],
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/itinerary',
              builder: (context, state) =>
                  MyItineraryShellScreen(key: itineraryScreenKey),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MapDirectionsShellScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileShellScreen(),
            ),
          ],
        ),
      ],
    ),
    // Pushed on the root navigator (parentNavigatorKey) so these detail
    // screens cover the bottom nav bar instead of living inside a tab.
    GoRoute(
      path: '/events/:eventId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => EventDetailsShellScreen(
        eventId: state.pathParameters['eventId']!,
        previewEvent: state.extra is Event ? state.extra as Event : null,
      ),
    ),
    GoRoute(
      path: '/activities/:activityId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => ActivityDetailsShellScreen(
        activityId: state.pathParameters['activityId']!,
      ),
    ),
    GoRoute(
      path: '/map/:activityId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => MapDirectionsShellScreen(
        activityId: state.pathParameters['activityId'],
      ),
    ),
    GoRoute(
      path: '/map/:activityId/navigate',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => TurnByTurnNavigationScreen(
        activityId: state.pathParameters['activityId']!,
      ),
    ),
    // Profile's simple, single-purpose destination screens.
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationCenterScreen(),
    ),
    GoRoute(
      path: '/help',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const RegistrationShellScreen(),
    ),
    GoRoute(
      path: '/registration/success',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          RegistrationSuccessScreen(registration: state.extra as Registration),
    ),
    // Same screen as /registration/success, reused by ProfileShellScreen's
    // "My QR Pass" row to view an already-existing registration — distinct
    // path so isNewSubmission can default correctly per entry point without
    // needing a wrapper object through GoRouter's single `extra` slot.
    GoRoute(
      path: '/registration/my-pass',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => RegistrationSuccessScreen(
        registration: state.extra as Registration,
        isNewSubmission: false,
      ),
    ),
    // Public (unauthenticated) routes — see _publicPaths above. These wrap
    // the existing splash/welcome/login/signup screens as-is.
    //
    // Splash/Welcome/Login/Signup use a custom fade+slide pageBuilder
    // (see page_transitions.dart) instead of go_router's default —
    // reported as feeling abrupt between these full solid-color screens.
    // Scoped to just this flow, not applied elsewhere in the app.
    GoRoute(
      path: '/splash',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) =>
          fadeSlideTransitionPage(state: state, child: const SplashScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => fadeSlideTransitionPage(
        state: state,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/welcome',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) =>
          fadeSlideTransitionPage(state: state, child: const WelcomeScreen()),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) =>
          fadeSlideTransitionPage(state: state, child: const LoginScreen()),
    ),
    // Account sign-up — not to be confused with /register, which is the
    // tourist-facing Pre-Arrival Registration flow.
    GoRoute(
      path: '/signup',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) =>
          fadeSlideTransitionPage(state: state, child: const RegisterScreen()),
    ),
  ],
);
