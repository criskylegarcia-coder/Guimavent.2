import 'package:flutter/material.dart';

// A centered icon + message (+ optional detail line), shared by every
// "No X yet" empty state in the app so they all look and read the same way
// instead of each screen rolling its own. Pick an icon that's contextually
// appropriate for what's missing (see call sites for examples).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? detail;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
