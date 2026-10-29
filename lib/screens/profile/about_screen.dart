import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_info.dart';

// Reached from Profile's "About GuimaVent" row. Static content only.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About GuimaVent')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('GuimaVent', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Explore. Experience. Guimaras.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('About', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            'GuimaVent helps tourists discover events, activities, and '
            'municipalities across Guimaras — with an interactive map, '
            'route planning, a personal itinerary, and a streamlined '
            'Pre-Arrival Registration process for local tourism officers.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(
            'Version $appVersion',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textDark.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
