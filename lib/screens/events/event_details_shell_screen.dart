import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity.dart';
import '../../models/event.dart';
import '../../models/itinerary_day.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/itinerary_repository.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../repositories/supabase_itinerary_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/error_snackbar.dart';
import '../../utils/event_status.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/event_status_badge.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/skeleton_box.dart';

// Loads one Event by id and shows its hero image and an Overview /
// Itinerary / Activities / Gallery tab bar, plus a Reels-style floating
// save/like/share action bar over the hero image (see
// _ReelsActionBar/_ReelsActionButton below). Save is real, backed by the
// same `favorites` table ActivityDetailsShellScreen's own favoriting uses
// (target_type='event' here — see ItineraryRepository.toggleEventFavorite).
// Like is deliberately local/visual-only — there's no "like" concept
// anywhere else in this app's backend, so it isn't persisted.
//
// The sticky bottom button is a real entry point into Pre-Arrival
// Registration (/register) — previously the RSVP button's slot, empty
// since RSVP was removed. Shown unconditionally: there's no repository
// method yet to check whether the current user already has an arrival
// card, and adding one is out of scope here (this batch only wires up
// navigation, not the registration flow itself).
class EventDetailsShellScreen extends StatefulWidget {
  final String eventId;
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final EventRepository? repository;
  final ItineraryRepository? itineraryRepository;
  // Passed via GoRouter's `extra` from the card that was tapped (see
  // EventCard's call sites in HomeShellScreen/EventsShellScreen) so the
  // Hero-tagged image below can render immediately on this screen's first
  // frame. Flutter's Hero animation needs the destination Hero mounted
  // before the push transition's first frame is captured — the
  // FutureBuilder-gated fetch below can't guarantee that on its own, since
  // even a fast fetch takes some real time. Superseded by the freshly
  // fetched Event once that resolves — this preview may have an empty
  // itinerary (see EventRepository.getUpcomingEvents), so its Itinerary/
  // Activities tabs can briefly show empty before the real data lands.
  final Event? previewEvent;

  const EventDetailsShellScreen({
    super.key,
    required this.eventId,
    this.repository,
    this.itineraryRepository,
    this.previewEvent,
  });

  @override
  State<EventDetailsShellScreen> createState() =>
      _EventDetailsShellScreenState();
}

class _EventDetailsShellScreenState extends State<EventDetailsShellScreen> {
  // Depends on the abstract repository only, same pattern as Home.
  late final EventRepository _repository =
      widget.repository ?? SupabaseEventRepository();
  late final ItineraryRepository _itineraryRepository =
      widget.itineraryRepository ?? SupabaseItineraryRepository();
  late final Future<Event?> _eventFuture;
  bool _hasLoggedFirstRender = false;

  // Null = still checking. Real, persisted state (see class doc comment).
  bool? _isSaved;
  bool _isTogglingSave = false;
  // Local/visual-only — never persisted, see class doc comment.
  bool _isLiked = false;
  bool _showSavedBadge = false;
  Timer? _savedBadgeTimer;

  @override
  void initState() {
    super.initState();
    final fetchStart = DateTime.now();
    debugPrint(
      '[EventDetailsShellScreen] fetch start for eventId=${widget.eventId}',
    );
    _eventFuture = withErrorFallback(
      context,
      _repository.getEventById(widget.eventId),
      fallback: null,
    ).then((event) {
      debugPrint(
        '[EventDetailsShellScreen] _eventFuture resolved after '
        '${DateTime.now().difference(fetchStart).inMilliseconds}ms',
      );
      return event;
    });
    _itineraryRepository.isEventFavorited(widget.eventId).then((value) {
      if (mounted) setState(() => _isSaved = value);
    }).catchError((_) {
      if (mounted) setState(() => _isSaved = false);
    });
  }

  @override
  void dispose() {
    _savedBadgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleToggleSave() async {
    if (_isTogglingSave) return;
    setState(() => _isTogglingSave = true);
    try {
      final newValue = await _itineraryRepository.toggleEventFavorite(
        widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _isSaved = newValue;
        _isTogglingSave = false;
      });
      // Only on saving, not un-saving — a confirmation nudge for the
      // positive action, not every toggle.
      if (newValue) {
        HapticFeedback.lightImpact();
        _savedBadgeTimer?.cancel();
        setState(() => _showSavedBadge = true);
        _savedBadgeTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showSavedBadge = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingSave = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessageFor(e))));
    }
  }

  void _handleToggleLike() {
    setState(() => _isLiked = !_isLiked);
    if (_isLiked) HapticFeedback.lightImpact();
  }

  Future<void> _handleShare(Event event) async {
    final text =
        'Check out ${event.name} in ${event.municipality}, Guimaras! '
        '${formatDateRange(event.startDate, event.endDate)} — via GuimaVent';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Event?>(
      future: _eventFuture,
      builder: (context, snapshot) {
        final isDone = snapshot.connectionState == ConnectionState.done;
        // While still loading, fall back to the handed-off preview (if
        // any) so the Hero-tagged image renders immediately; once done,
        // only the real fetch result counts — a stale preview must not
        // mask a genuine "not found".
        final event = isDone ? snapshot.data : widget.previewEvent;
        if (!isDone && event == null) {
          return const _EventDetailsSkeleton();
        }
        if (isDone && snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Event not found')),
          );
        }
        if (!_hasLoggedFirstRender) {
          _hasLoggedFirstRender = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              '[EventDetailsShellScreen] first content frame painted',
            );
          });
        }
        return _EventDetailsScaffold(
          event: event!,
          isSaved: _isSaved ?? false,
          isLiked: _isLiked,
          showSavedBadge: _showSavedBadge,
          onToggleSave: _handleToggleSave,
          onToggleLike: _handleToggleLike,
          onShare: () => _handleShare(event),
        );
      },
    );
  }
}

// Roughly mirrors _EventDetailsScaffold's hero-image + title/meta shape,
// so the loading state doesn't jump around once the real event arrives.
class _EventDetailsSkeleton extends StatelessWidget {
  const _EventDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 220, borderRadius: BorderRadius.zero),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 220, height: 22),
                    SizedBox(height: 12),
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

class _EventDetailsScaffold extends StatelessWidget {
  final Event event;
  final bool isSaved;
  final bool isLiked;
  final bool showSavedBadge;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;

  const _EventDetailsScaffold({
    required this.event,
    required this.isSaved,
    required this.isLiked,
    required this.showSavedBadge,
    required this.onToggleSave,
    required this.onToggleLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final activities = [for (final day in event.itinerary) ...day.activities];

    return Stack(
      children: [
        _buildScaffold(context, activities),
        // Screen-level (not just over the hero image) so it stays visible
        // near the top-right regardless of scroll position when it fires.
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: IgnorePointer(
                  ignoring: !showSavedBadge,
                  child: AnimatedOpacity(
                    opacity: showSavedBadge ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const _SavedConfirmationPill(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context, List<Activity> activities) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              iconTheme: const IconThemeData(color: AppColors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'event-image-${event.id}',
                      child: Image.network(
                        event.coverImageUrl,
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
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EventStatusBadge(
                            status: computeEventStatus(
                              event.startDate,
                              event.endDate,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, right: 12),
                          child: _ReelsActionBar(
                            isSaved: isSaved,
                            isLiked: isLiked,
                            onToggleSave: onToggleSave,
                            onToggleLike: onToggleLike,
                            onShare: onShare,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        formatDateRange(event.startDate, event.endDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppColors.accentOrange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.municipality,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeaderDelegate(
                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textDark,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Itinerary'),
                    Tab(text: 'Activities'),
                    Tab(text: 'Gallery'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(event: event),
              _ItineraryTab(itinerary: event.itinerary),
              _ActivitiesTab(activities: activities),
              _GalleryTab(event: event),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: PrimaryButton(
              label: 'Register for Arrival',
              onPressed: () => context.push('/register'),
            ),
          ),
        ),
      ),
    );
  }
}

// Reels-style vertical action bar floating over the hero image: save
// (real, persisted), like (visual-only), share (native share sheet).
class _ReelsActionBar extends StatelessWidget {
  final bool isSaved;
  final bool isLiked;
  final VoidCallback onToggleSave;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;

  const _ReelsActionBar({
    required this.isSaved,
    required this.isLiked,
    required this.onToggleSave,
    required this.onToggleLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReelsActionButton(
          icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          onTap: onToggleSave,
        ),
        const SizedBox(height: 12),
        _ReelsActionButton(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          onTap: onToggleLike,
        ),
        const SizedBox(height: 12),
        _ReelsActionButton(icon: Icons.share_rounded, onTap: onShare),
      ],
    );
  }
}

// A single frosted-glass circular icon button — always a green outline (or
// green-filled, for save/like's active state) icon, per the brand-color
// consistency this was asked to keep, never the conventional red heart.
class _ReelsActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ReelsActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: AppColors.white.withValues(alpha: 0.35),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// A small pill confirming the save, shown briefly near the top-right of
// the screen (see _EventDetailsScaffold.build) — fades in/out, not a
// SnackBar, so it doesn't compete with the sticky "Register for Arrival"
// button at the bottom.
class _SavedConfirmationPill extends StatelessWidget {
  const _SavedConfirmationPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bookmark_rounded,
            color: AppColors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Saved',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Keeps the TabBar pinned below the hero image while the tab content
// underneath scrolls.
class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _OverviewTab extends StatelessWidget {
  final Event event;

  const _OverviewTab({required this.event});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text(event.description, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _ItineraryTab extends StatelessWidget {
  final List<ItineraryDay> itinerary;

  const _ItineraryTab({required this.itinerary});

  @override
  Widget build(BuildContext context) {
    if (itinerary.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        message: 'No itinerary yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: itinerary.length,
      itemBuilder: (context, index) => _ItineraryDayTile(
        day: itinerary[index],
        // Day 1 opens expanded, the rest start collapsed.
        initiallyExpanded: index == 0,
      ),
    );
  }
}

class _ItineraryDayTile extends StatelessWidget {
  final ItineraryDay day;
  final bool initiallyExpanded;

  const _ItineraryDayTile({
    required this.day,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(day.dayLabel, style: Theme.of(context).textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (var i = 0; i < day.activities.length; i++)
            _TimelineActivityRow(
              activity: day.activities[i],
              isLast: i == day.activities.length - 1,
            ),
        ],
      ),
    );
  }
}

// One activity in a day's timeline: a dot + connecting line on the left,
// title/time/venue on the right.
class _TimelineActivityRow extends StatelessWidget {
  final Activity activity;
  final bool isLast;

  const _TimelineActivityRow({required this.activity, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/activities/${activity.id}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activity.startTime} - ${activity.endTime}',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppColors.accentOrange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            activity.venue,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitiesTab extends StatelessWidget {
  final List<Activity> activities;

  const _ActivitiesTab({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const EmptyState(
        icon: Icons.local_activity_outlined,
        message: 'No activities yet',
      );
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => context.push('/activities/${activity.id}'),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Image.network(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activity.startTime} - ${activity.endTime}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GalleryTab extends StatelessWidget {
  final Event event;

  const _GalleryTab({required this.event});

  @override
  Widget build(BuildContext context) {
    // No gallery data on the model yet — placeholder images generated from
    // the event id so each event at least shows different pictures.
    final images = List.generate(
      6,
      (i) => 'https://picsum.photos/seed/${event.id}-gallery-$i/400/400',
    );
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          images[index],
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
    );
  }
}
