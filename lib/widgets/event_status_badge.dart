import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/event_status.dart';

// A small pill showing an event's Upcoming/Ongoing/Ended status (see
// utils/event_status.dart). Colors: primary green for Upcoming (the
// default, "on the calendar" state), accent orange for Ongoing (matches
// the app's existing use of accentOrange as an attention/live-signal
// color, e.g. distance pins), and textDark at reduced alpha for Ended —
// the same "muted" convention already used for unselected bottom-nav
// items, standing in for a neutral gray since AppColors has no dedicated
// one. A near-opaque white background (rather than a tinted one) keeps the
// colored label legible over any hero photo, which is where this badge is
// placed both on EventCard and Event Details.
class EventStatusBadge extends StatelessWidget {
  final EventStatus status;

  const EventStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EventStatus.upcoming => ('Upcoming', AppColors.primary),
      EventStatus.ongoing => ('Ongoing', AppColors.accentOrange),
      EventStatus.ended => ('Ended', AppColors.textDark.withValues(alpha: 0.5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
