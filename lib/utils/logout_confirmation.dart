import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/auth_guard.dart';

/// Shows a "Log out" confirmation dialog and, if confirmed, signs the user
/// out and navigates to /login. Shared by ProfileShellScreen's Logout row
/// and SettingsScreen's Logout button, so both stay in sync.
Future<void> confirmAndLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await signOut();
  if (context.mounted) context.go('/login');
}
