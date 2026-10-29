import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// A section title with a "View All" link on the right, e.g. "Upcoming
// Events                                          View All".
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const SectionHeader({super.key, required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Expanded + ellipsis so a long title (e.g. "Explore by
        // Municipality") shrinks to fit instead of overflowing the Row —
        // at narrow widths it was pushing the "View All" button off-screen
        // entirely, making it untappable.
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
          child: const Text('View All'),
        ),
      ],
    );
  }
}
