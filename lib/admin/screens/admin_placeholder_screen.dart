import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

// "Coming soon" stand-in for sections not built yet — Venues (Batch 2) and
// QR Scanner (Batch 3).
class AdminPlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const AdminPlaceholderScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textDark.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
