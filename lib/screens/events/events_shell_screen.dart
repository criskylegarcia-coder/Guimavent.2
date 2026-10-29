import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/event.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_slide_in.dart';

// The "Events" tab of the bottom-nav shell — replaces the Batch 1
// placeholder of the same name. A browsable grid of every event, distinct
// from Home's "Upcoming Events" horizontal preview.
class EventsShellScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves this null and gets
  // the real Supabase-backed repository.
  final EventRepository? repository;
  // Pre-fills the search field and filter on load — set from the '/events'
  // route's ?q= query parameter, which is how Home's search field hands
  // off a query (see app_router.dart and HomeShellScreen). Only read once,
  // on init: StatefulShellRoute.indexedStack keeps this screen's State
  // alive across tab switches, so a second Home search submitted while
  // this tab is already active won't re-apply — a known, minor limitation
  // of the simplest wiring, not handled here.
  final String? initialQuery;
  // Same idea, for the municipality chip row — set from the '/events'
  // route's ?municipality= query parameter, which is how Home's
  // "Explore by Municipality" circles hand off a filter (see
  // app_router.dart and HomeShellScreen's _MunicipalityRow). Same
  // once-on-init caveat as initialQuery above.
  final String? initialMunicipality;

  const EventsShellScreen({
    super.key,
    this.repository,
    this.initialQuery,
    this.initialMunicipality,
  });

  @override
  State<EventsShellScreen> createState() => _EventsShellScreenState();
}

class _EventsShellScreenState extends State<EventsShellScreen> {
  static const List<String> _municipalityFilters = [
    'All',
    'Buenavista',
    'Jordan',
    'Nueva Valencia',
    'San Lorenzo',
    'Sibunag',
  ];

  late final EventRepository _repository =
      widget.repository ?? SupabaseEventRepository();
  late Future<List<Event>> _eventsFuture;
  late String _selectedMunicipality;
  late String _searchQuery;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery?.trim() ?? '';
    // Falls back to 'All' if the handed-off name isn't one of the known
    // filter chips, rather than silently selecting nothing/an invalid chip.
    _selectedMunicipality = _municipalityFilters.contains(
      widget.initialMunicipality,
    )
        ? widget.initialMunicipality!
        : 'All';
    _eventsFuture = _repository.getUpcomingEvents();
  }

  void _handleRetry() {
    setState(() {
      _eventsFuture = _repository.getUpcomingEvents();
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _eventsFuture = _repository.getUpcomingEvents();
    });
    await _eventsFuture;
  }

  @override
  Widget build(BuildContext context) {
    // The search field and municipality filters don't depend on the fetch
    // at all — pulled out of the FutureBuilder below so they're available
    // immediately instead of hiding behind the loading skeleton too.
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              12,
              AppSpacing.screenPadding,
              12,
            ),
            child: AppSearchField(
              hintText: 'Search events...',
              initialValue: widget.initialQuery,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim()),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              itemCount: _municipalityFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final municipality = _municipalityFilters[index];
                final selected = municipality == _selectedMunicipality;
                return ChoiceChip(
                  label: Text(municipality),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedMunicipality = municipality),
                  // Explicit colors instead of Material 3's auto-derived
                  // defaults — an unset background falls back to a tone
                  // generated from the primary-green seed color, which
                  // sits too close to the scaffold's own light gray
                  // background to read clearly, especially on narrow
                  // screens with little surrounding context. White
                  // matches how every other surface (cards, the search
                  // field) already contrasts against AppColors.surface.
                  backgroundColor: AppColors.white,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textDark.withValues(alpha: 0.3),
                  ),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? AppColors.primary : AppColors.textDark,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Event>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _EventsGridSkeleton();
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return _ErrorState(
                    message: error is RepositoryException
                        ? error.message
                        : 'Something went wrong. Please try again.',
                    onRetry: _handleRetry,
                  );
                }

                final events = snapshot.data ?? const [];
                final filtered = events.where((event) {
                  final matchesMunicipality =
                      _selectedMunicipality == 'All' ||
                      event.municipality == _selectedMunicipality;
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      event.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                  return matchesMunicipality && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyState(
                          icon: Icons.event_busy_outlined,
                          message: events.isEmpty
                              ? 'No events yet'
                              : 'No events match your search or filter.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return StaggeredFadeSlideIn(
                        index: index,
                        child: EventCard(
                          event: event,
                          onTap: () => context.push(
                            '/events/${event.id}',
                            extra: event,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Mirrors the post-load 2-column EventCard grid's shape, so the loading
// state doesn't jump around once real cards arrive.
class _EventsGridSkeleton extends StatelessWidget {
  const _EventsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: SkeletonBox(borderRadius: BorderRadius.zero)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
