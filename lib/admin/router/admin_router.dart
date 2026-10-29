import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/activities_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_events_screen.dart';
import '../screens/admin_login_screen.dart';
import '../screens/admin_shell_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/venues_screen.dart';
import 'admin_auth_guard.dart';

final GlobalKey<NavigatorState> adminRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'admin-root');

// Only route reachable without a verified staff session — everything else
// redirects to it. Mirrors lib/router/app_router.dart's _publicPaths, but
// this is a completely separate router/session concept (see
// admin_auth_guard.dart) — an admin session here has no bearing on the
// tourist app's auth_guard.dart, and vice versa.
const String _adminLoginPath = '/admin/login';

final GoRouter adminRouter = GoRouter(
  navigatorKey: adminRootNavigatorKey,
  initialLocation: _adminLoginPath,
  redirect: (context, state) {
    final target = state.matchedLocation;
    if (target == _adminLoginPath) return null;
    if (!hasVerifiedStaffSession()) return _adminLoginPath;
    return null;
  },
  routes: [
    GoRoute(
      path: _adminLoginPath,
      builder: (context, state) => const AdminLoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AdminShellScreen(currentPath: state.matchedLocation, child: child),
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/events',
          builder: (context, state) => const AdminEventsScreen(),
        ),
        GoRoute(
          path: '/admin/venues',
          builder: (context, state) => const VenuesScreen(),
        ),
        GoRoute(
          path: '/admin/activities',
          builder: (context, state) => const ActivitiesScreen(),
        ),
        GoRoute(
          path: '/admin/qr-scanner',
          builder: (context, state) => const QrScannerScreen(),
        ),
      ],
    ),
  ],
);
