import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../router/admin_auth_guard.dart';

class _AdminDestination {
  final String path;
  final IconData icon;
  final String label;

  const _AdminDestination({
    required this.path,
    required this.icon,
    required this.label,
  });
}

// Persistent side navigation wrapping every route under /admin except
// /admin/login — web-appropriate (NavigationRail, not the tourist app's
// bottom nav). Swapped in via ShellRoute in admin_router.dart.
class AdminShellScreen extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const AdminShellScreen({
    super.key,
    required this.currentPath,
    required this.child,
  });

  static const List<_AdminDestination> _destinations = [
    _AdminDestination(
      path: '/admin/dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
    ),
    _AdminDestination(
      path: '/admin/events',
      icon: Icons.event_outlined,
      label: 'Events',
    ),
    _AdminDestination(
      path: '/admin/venues',
      icon: Icons.place_outlined,
      label: 'Venues',
    ),
    _AdminDestination(
      path: '/admin/activities',
      icon: Icons.local_activity_outlined,
      label: 'Activities',
    ),
    _AdminDestination(
      path: '/admin/qr-scanner',
      icon: Icons.qr_code_scanner_outlined,
      label: 'QR Scanner',
    ),
  ];

  int get _selectedIndex {
    for (var i = 0; i < _destinations.length; i++) {
      if (currentPath.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  Future<void> _handleLogout(BuildContext context) async {
    await adminSignOut();
    if (context.mounted) context.go('/admin/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              context.go(_destinations[index].path);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.surface,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Icon(
                Icons.location_on_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: 'Logout',
                    onPressed: () => _handleLogout(context),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
