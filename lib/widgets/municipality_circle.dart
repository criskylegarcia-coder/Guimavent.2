import 'package:flutter/material.dart';

import '../models/municipality.dart';
import '../theme/app_theme.dart';

// One circular icon item used in "Explore by Municipality". `icon` is
// passed in by the caller for now since we don't have real icon image
// assets yet (see the comment on Municipality.iconAsset).
class MunicipalityCircle extends StatelessWidget {
  final Municipality municipality;
  final IconData icon;
  final VoidCallback? onTap;

  const MunicipalityCircle({
    super.key,
    required this.municipality,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        width: 72,
        // Explicit height (icon + gap + up to 2 label lines, with a little
        // slack) so the label always has room to wrap and never gets
        // clipped, instead of relying on whatever height its parent Row
        // happens to give it.
        height: 96,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surface,
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              municipality.name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
