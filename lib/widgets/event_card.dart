import 'package:flutter/material.dart';

import '../models/event.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/event_status.dart';
import 'event_status_badge.dart';
import 'skeleton_box.dart';

// A photo card used in the "Upcoming Events" horizontal list and the
// Events grid: cover image (Hero-tagged so tapping through to Event
// Details animates smoothly — see EventDetailsShellScreen's matching Hero
// and its previewEvent param), event name, date range, a status badge,
// and a location pin with the municipality.
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expanded (instead of a fixed AspectRatio) so the image
              // always shrinks to exactly whatever room is left after the
              // text block below takes what it needs — the card can never
              // overflow, whatever the card's height ends up being.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'event-image-${event.id}',
                      child: Image.network(
                        event.coverImageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SkeletonBox(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.zero,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: AppColors.surface,
                              child: Icon(Icons.image_not_supported_rounded),
                            ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: EventStatusBadge(
                        status: computeEventStatus(
                          event.startDate,
                          event.endDate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDateRange(event.startDate, event.endDate),
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: AppColors.accentOrange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.municipality,
                            style: theme.textTheme.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
