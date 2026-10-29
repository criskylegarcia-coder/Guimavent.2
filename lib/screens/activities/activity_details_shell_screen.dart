import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/event.dart';
import '../../models/nearby_activity.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/itinerary_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../repositories/supabase_itinerary_repository.dart';
import '../../repositories/supabase_registration_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/distance_format.dart';
import '../../utils/error_snackbar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/skeleton_box.dart';

// Loads one Activity by id and shows its hero image, title, date/time/venue,
// description, a link back to its parent Event, and a sticky
// "Add to Itinerary" button.
class ActivityDetailsShellScreen extends StatefulWidget {
  final String activityId;
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final EventRepository? repository;
  final ItineraryRepository? itineraryRepository;
  final RegistrationRepository? registrationRepository;

  const ActivityDetailsShellScreen({
    super.key,
    required this.activityId,
    this.repository,
    this.itineraryRepository,
    this.registrationRepository,
  });

  @override
  State<ActivityDetailsShellScreen> createState() =>
      _ActivityDetailsShellScreenState();
}

class _ActivityDetailsShellScreenState
    extends State<ActivityDetailsShellScreen> {
  // Depends on the abstract repositories only, same pattern as Home.
  late final EventRepository _repository =
      widget.repository ?? SupabaseEventRepository();
  late final ItineraryRepository _itineraryRepository =
      widget.itineraryRepository ?? SupabaseItineraryRepository();
  late final RegistrationRepository _registrationRepository =
      widget.registrationRepository ?? SupabaseRegistrationRepository();
  late final Future<Activity?> _activityFuture;
  bool _hasLoggedFirstRender = false;
  bool _isScheduled = false;
  bool _isAddingToSchedule = false;
  bool _isCheckingRegistration = false;

  @override
  void initState() {
    super.initState();
    final fetchStart = DateTime.now();
    debugPrint(
      '[ActivityDetailsShellScreen] fetch start for '
      'activityId=${widget.activityId}',
    );
    _activityFuture =
        withErrorFallback(
          context,
          _repository.getActivityById(widget.activityId),
          fallback: null,
        ).then((activity) {
          debugPrint(
            '[ActivityDetailsShellScreen] _activityFuture resolved after '
            '${DateTime.now().difference(fetchStart).inMilliseconds}ms',
          );
          return activity;
        });
    _itineraryRepository
        .isScheduled(widget.activityId)
        .then((value) {
          if (mounted) setState(() => _isScheduled = value);
        })
        .catchError((_) {});
  }

  // Drives BOTH the heart icon and the "+ Add to Itinerary" button — they're
  // the same action now (My Schedule), always in sync, tapping either
  // toggles both.
  Future<void> _handleToggleSchedule(Activity activity) async {
    if (_isAddingToSchedule) return;
    setState(() => _isAddingToSchedule = true);
    try {
      if (_isScheduled) {
        await _itineraryRepository.removeFromSchedule(activity.id);
      } else {
        await _itineraryRepository.addToSchedule(activity);
      }
      if (!mounted) return;
      final newValue = !_isScheduled;
      setState(() {
        _isScheduled = newValue;
        _isAddingToSchedule = false;
      });
      // Only on adding (favoriting), not removing — a subtle confirmation
      // nudge for the positive action, not every toggle.
      if (newValue) HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue ? 'Added to itinerary' : 'Removed from itinerary',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAddingToSchedule = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessageFor(e))));
    }
  }

  // Gates the "Get Directions" button on a Pre-Arrival Registration existing
  // for the current user, checked fresh on every tap rather than once on
  // load — matches the task's "check before navigating" ask and stays
  // correct even if the user just registered in another tab/screen.
  Future<void> _handleGetDirections(Activity activity) async {
    if (_isCheckingRegistration) return;
    setState(() => _isCheckingRegistration = true);
    bool hasActive;
    try {
      hasActive = await _registrationRepository.hasActiveRegistration();
    } catch (_) {
      // Fails closed: an unreadable check shows the registration gate
      // rather than silently letting an unverified tourist through.
      hasActive = false;
    }
    if (!mounted) return;
    setState(() => _isCheckingRegistration = false);
    if (hasActive) {
      context.push('/map/${activity.id}');
    } else {
      _showRegistrationRequiredDialog();
    }
  }

  void _showRegistrationRequiredDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registration Required'),
        content: const Text(
          'Complete Pre-Arrival Registration before accessing Map & '
          'Directions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/register');
            },
            child: const Text('Register Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Activity?>(
      future: _activityFuture,
      builder: (context, snapshot) {
        debugPrint(
          '[ActivityDetailsShellScreen] FutureBuilder rebuild: '
          'connectionState=${snapshot.connectionState}, '
          'hasData=${snapshot.hasData}, data=${snapshot.data}, '
          'hasError=${snapshot.hasError}',
        );
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ActivityDetailsSkeleton();
        }
        final activity = snapshot.data;
        if (activity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Activity not found')),
          );
        }
        if (!_hasLoggedFirstRender) {
          _hasLoggedFirstRender = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              '[ActivityDetailsShellScreen] first content frame painted',
            );
          });
        }
        return _ActivityDetailsScaffold(
          activity: activity,
          repository: _repository,
          isScheduled: _isScheduled,
          isAddingToSchedule: _isAddingToSchedule,
          onToggleSchedule: () => _handleToggleSchedule(activity),
          isCheckingRegistration: _isCheckingRegistration,
          onGetDirections: () => _handleGetDirections(activity),
        );
      },
    );
  }
}

// Roughly mirrors _ActivityDetailsScaffold's hero-image + title/meta shape,
// so the loading state doesn't jump around once the real activity arrives.
class _ActivityDetailsSkeleton extends StatelessWidget {
  const _ActivityDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 240, borderRadius: BorderRadius.zero),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 200, height: 22),
                    SizedBox(height: 16),
                    SkeletonBox(width: 140, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 120, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: 24),
                    SkeletonBox(height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 200, height: 14),
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

class _ActivityDetailsScaffold extends StatelessWidget {
  final Activity activity;
  final EventRepository repository;
  final bool isScheduled;
  final bool isAddingToSchedule;
  final VoidCallback onToggleSchedule;
  final bool isCheckingRegistration;
  final VoidCallback onGetDirections;

  const _ActivityDetailsScaffold({
    required this.activity,
    required this.repository,
    required this.isScheduled,
    required this.isAddingToSchedule,
    required this.onToggleSchedule,
    required this.isCheckingRegistration,
    required this.onGetDirections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            iconTheme: const IconThemeData(color: AppColors.white),
            actions: [
              IconButton(
                onPressed: isAddingToSchedule ? null : onToggleSchedule,
                icon: Icon(
                  isScheduled
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isScheduled ? AppColors.accentOrange : AppColors.white,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                activity.imageUrl,
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
                    const ColoredBox(color: AppColors.surface),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _MetaRow(
                    icon: Icons.calendar_today_rounded,
                    text: formatSingleDate(activity.activityDate),
                  ),
                  const SizedBox(height: 6),
                  _MetaRow(
                    icon: Icons.access_time_rounded,
                    text: '${activity.startTime} - ${activity.endTime}',
                  ),
                  const SizedBox(height: 6),
                  _MetaRow(
                    icon: Icons.location_on_rounded,
                    iconColor: AppColors.accentOrange,
                    text: activity.venue,
                  ),
                  const SizedBox(height: 20),
                  Text('About', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(activity.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  _RelatedEventCard(
                    repository: repository,
                    eventId: activity.eventId,
                  ),
                  const SizedBox(height: 20),
                  _NearbyActivitiesSection(
                    repository: repository,
                    activityId: activity.id,
                  ),
                  // Leaves room so content doesn't end up hidden behind the
                  // sticky button.
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: isAddingToSchedule
                      ? 'Updating...'
                      : (isScheduled
                            ? 'Remove from Itinerary'
                            : '+ Add to Itinerary'),
                  onPressed: isAddingToSchedule ? null : onToggleSchedule,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: isCheckingRegistration
                      ? 'Checking...'
                      : 'Get Directions',
                  onPressed: isCheckingRegistration ? null : onGetDirections,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _MetaRow({
    required this.icon,
    required this.text,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

// Small card linking back to the Event this activity belongs to.
class _RelatedEventCard extends StatelessWidget {
  final EventRepository repository;
  final String eventId;

  const _RelatedEventCard({required this.repository, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final fetchStart = DateTime.now();
    return FutureBuilder<Event?>(
      future: repository.getEventById(eventId).then((event) {
        debugPrint(
          '[_RelatedEventCard] getEventById resolved after '
          '${DateTime.now().difference(fetchStart).inMilliseconds}ms '
          '(independent of main activity content)',
        );
        return event;
      }),
      builder: (context, snapshot) {
        final event = snapshot.data;
        if (event == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => context.push('/events/${event.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      event.coverImageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SkeletonBox(
                          width: 56,
                          height: 56,
                          borderRadius: BorderRadius.zero,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: AppColors.surface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Part of', style: theme.textTheme.labelMedium),
                        Text(
                          event.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// "Nearby Activities": other sub_activity rows near this one's venue, via
// the nearby_activities Postgres RPC (see EventRepository). Shown even when
// empty ("No nearby activities" rather than hiding the section), since most
// current seed data is sparse and the feature should still be visible.
class _NearbyActivitiesSection extends StatelessWidget {
  final EventRepository repository;
  final String activityId;

  const _NearbyActivitiesSection({
    required this.repository,
    required this.activityId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fetchStart = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nearby Activities', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        FutureBuilder<List<NearbyActivity>>(
          future: repository.getNearbyActivities(activityId).then((nearby) {
            debugPrint(
              '[_NearbyActivitiesSection] getNearbyActivities resolved '
              'after ${DateTime.now().difference(fetchStart).inMilliseconds}ms '
              '(independent of main activity content, ${nearby.length} results)',
            );
            return nearby;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Column(
                children: [
                  SkeletonBox(height: 68),
                  SizedBox(height: 8),
                  SkeletonBox(height: 68),
                ],
              );
            }
            final nearby = snapshot.data ?? const [];
            if (nearby.isEmpty) {
              // A small inline row rather than the full-page EmptyState
              // widget — this is one section within a longer detail
              // screen, not a standalone empty screen.
              return Row(
                children: [
                  Icon(
                    Icons.near_me_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'No nearby activities',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textDark.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < nearby.length; i++) ...[
                  _NearbyActivityCard(activity: nearby[i]),
                  if (i != nearby.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// Compact card for one nearby activity: name, parent event, distance.
class _NearbyActivityCard extends StatelessWidget {
  final NearbyActivity activity;

  const _NearbyActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/activities/${activity.activityId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.activityName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Part of ${activity.eventName}',
                      style: theme.textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDistance(activity.distanceMeters),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
