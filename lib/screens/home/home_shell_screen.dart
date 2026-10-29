import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity.dart';
import '../../models/event.dart';
import '../../models/municipality.dart';
import '../../models/user_profile.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../repositories/supabase_profile_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_snackbar.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/event_card.dart';
import '../../widgets/municipality_circle.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_slide_in.dart';

// A Material icon per municipality, used until real icon assets exist
// (see the comment on Municipality.iconAsset).
const Map<String, IconData> _municipalityIcons = {
  'Buenavista': Icons.terrain_rounded,
  'Jordan': Icons.directions_boat_filled_rounded,
  'Nueva Valencia': Icons.eco_rounded,
  'San Lorenzo': Icons.church_rounded,
  'Sibunag': Icons.beach_access_rounded,
};

class HomeShellScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final EventRepository? repository;
  final ProfileRepository? profileRepository;

  const HomeShellScreen({super.key, this.repository, this.profileRepository});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  // Depends on the abstract EventRepository only.
  late final EventRepository _repository =
      widget.repository ?? SupabaseEventRepository();
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? SupabaseProfileRepository();

  late Future<List<Event>> _upcomingEventsFuture;
  late Future<List<Municipality>> _municipalitiesFuture;
  late Future<List<Activity>> _popularActivitiesFuture;
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _upcomingEventsFuture = withErrorFallback(
      context,
      _repository.getUpcomingEvents(),
      fallback: const [],
    );
    _municipalitiesFuture = withErrorFallback(
      context,
      _repository.getMunicipalities(),
      fallback: const [],
    );
    _popularActivitiesFuture = withErrorFallback(
      context,
      _repository.getPopularActivities(),
      fallback: const [],
    );
    // Just the greeting's name — not worth interrupting the user with an
    // error SnackBar over, so this fails quietly to the generic "Hello!"
    // rather than going through withErrorFallback.
    _profileFuture = _profileRepository.getMyProfile().catchError(
      (_) => null,
    );
  }

  Future<void> _handleRefresh() async {
    setState(_loadData);
    await _upcomingEventsFuture;
    await _municipalitiesFuture;
    await _popularActivitiesFuture;
    await _profileFuture;
  }

  // Home's search field doesn't filter anything itself — it just captures
  // the initial query and hands off to Events' own search/filter logic,
  // which already works. See EventsShellScreen's initialQuery param and
  // app_router.dart's '/events' route reading the 'q' query parameter.
  void _handleSearchSubmitted(String query) {
    context.push('/events?q=${Uri.encodeQueryComponent(query.trim())}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              _HomeHeader(theme: theme, profileFuture: _profileFuture),
              const SizedBox(height: 20),
              AppSearchField(
                hintText: 'Search events, activities, or places...',
                onSubmitted: _handleSearchSubmitted,
              ),
              const SizedBox(height: 28),

              SectionHeader(
                title: 'Upcoming Events',
                onViewAll: () => context.push('/events'),
              ),
              const SizedBox(height: 12),
              _EventList(future: _upcomingEventsFuture),
              const SizedBox(height: 28),

              SectionHeader(
                title: 'Explore by Municipality',
                onViewAll: () => context.push('/events'),
              ),
              const SizedBox(height: 12),
              _MunicipalityRow(future: _municipalitiesFuture),
              const SizedBox(height: 28),

              SectionHeader(title: 'Popular Activities', onViewAll: () {}),
              const SizedBox(height: 12),
              _ActivityList(future: _popularActivitiesFuture),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final ThemeData theme;
  final Future<UserProfile?> profileFuture;

  const _HomeHeader({required this.theme, required this.profileFuture});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<UserProfile?>(
                future: profileFuture,
                builder: (context, snapshot) {
                  final fullName = snapshot.data?.fullName ?? '';
                  final greeting = fullName.isNotEmpty
                      ? 'Hello, $fullName!'
                      : 'Hello!';
                  return Text(greeting, style: theme.textTheme.titleMedium);
                },
              ),
              const SizedBox(height: 2),
              Text(
                'Where are we exploring today?',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  final Future<List<Event>> future;

  const _EventList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Event>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _EventListSkeleton();
        }
        final events = snapshot.data!;
        return SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => StaggeredFadeSlideIn(
              index: index,
              child: EventCard(
                event: events[index],
                onTap: () => context.push(
                  '/events/${events[index].id}',
                  extra: events[index],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MunicipalityRow extends StatelessWidget {
  final Future<List<Municipality>> future;

  const _MunicipalityRow({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Municipality>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _MunicipalityRowSkeleton();
        }
        final municipalities = snapshot.data!;
        // Horizontally scrollable instead of a fixed spaceBetween Row —
        // 5 fixed-72px-wide circles don't fit in the available width on
        // narrow phones (spaceBetween doesn't shrink items, so it just
        // overflows once their combined width exceeds the screen).
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: municipalities.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final municipality = municipalities[index];
              return MunicipalityCircle(
                municipality: municipality,
                icon: _municipalityIcons[municipality.name] ??
                    Icons.location_city_rounded,
                // Hands off to Events' own municipality filter/chip row —
                // same pattern as the search field's handoff (see
                // _handleSearchSubmitted above) — rather than building a
                // second filtering mechanism here.
                onTap: () => context.push(
                  '/events?municipality=${Uri.encodeQueryComponent(municipality.name)}',
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ActivityList extends StatelessWidget {
  final Future<List<Activity>> future;

  const _ActivityList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Activity>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _ActivityListSkeleton();
        }
        final activities = snapshot.data!;
        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: activities.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _ActivityCard(activity: activities[index]),
          ),
        );
      },
    );
  }
}

// Simple image card for Popular Activities. Kept private to this file
// since the spec only calls out EventCard as a shared/reusable widget.
class _ActivityCard extends StatelessWidget {
  final Activity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
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
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: AppColors.surface,
                child: Icon(Icons.image_not_supported_rounded),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    activity.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mirrors EventCard's shape (a 220-wide image-over-text card) so the
// loading state doesn't jump around once real cards arrive.
class _EventListSkeleton extends StatelessWidget {
  const _EventListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: SkeletonBox(borderRadius: BorderRadius.zero)),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Mirrors MunicipalityCircle's shape (a circle with a label underneath).
class _MunicipalityRowSkeleton extends StatelessWidget {
  const _MunicipalityRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => const SizedBox(
          width: 64,
          child: Column(
            children: [
              SkeletonBox(
                width: 64,
                height: 64,
                borderRadius: BorderRadius.all(Radius.circular(32)),
              ),
              SizedBox(height: 8),
              SkeletonBox(width: 48, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// Mirrors _ActivityCard's shape (a 180-wide image tile).
class _ActivityListSkeleton extends StatelessWidget {
  const _ActivityListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: const SkeletonBox(width: 180, height: 150),
        ),
      ),
    );
  }
}
