import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/itinerary_entry.dart';
import '../../repositories/itinerary_repository.dart';
import '../../repositories/supabase_itinerary_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/error_snackbar.dart';
import '../../widgets/empty_state.dart';

// "My Itinerary": activities the user has added to their schedule, grouped
// by date. Reached via the bottom nav's Itinerary tab. RSVP Events (a
// second tab here, for events) was removed from scope — this used to be a
// two-tab screen; it's a single list now.
class MyItineraryShellScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves this null and gets
  // the mock data.
  final ItineraryRepository? repository;

  const MyItineraryShellScreen({super.key, this.repository});

  // Public (not the usual leading-underscore State) so main_shell_screen.dart
  // can hold a GlobalKey<MyItineraryShellScreenState> and call refresh()
  // directly — see itineraryScreenKey in main_shell_screen.dart for why.
  @override
  State<MyItineraryShellScreen> createState() => MyItineraryShellScreenState();
}

class MyItineraryShellScreenState extends State<MyItineraryShellScreen> {
  // Depends on the abstract ItineraryRepository only, same pattern as the
  // other screens.
  late final ItineraryRepository _repository =
      widget.repository ?? SupabaseItineraryRepository();
  late Future<List<ItineraryEntry>> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = _loadSchedule();
  }

  Future<List<ItineraryEntry>> _loadSchedule() {
    return withErrorFallback<List<ItineraryEntry>>(
      context,
      _repository.getMySchedule(),
      fallback: const [],
    );
  }

  /// Re-fetches My Schedule from scratch. StatefulShellRoute keeps this
  /// State alive across bottom-nav tab switches, so initState() only ever
  /// runs once on its own — without an explicit refresh, changes made
  /// elsewhere (e.g. "+ Add to Itinerary" on Activity Details) would never
  /// show up here. Called from two places: main_shell_screen.dart whenever
  /// the Itinerary tab is (re)selected, and RefreshIndicator's pull gesture
  /// below.
  Future<void> refresh() async {
    setState(() {
      _scheduleFuture = _loadSchedule();
    });
    await _scheduleFuture;
  }

  // Unscheduling here must make the row disappear (this list IS "activities
  // in my schedule"), not just change a heart icon's color — so this
  // re-fetches the schedule list rather than toggling a local Set.
  Future<void> _handleToggleActivitySchedule(String activityId) async {
    await _repository.removeFromSchedule(activityId);
    if (!mounted) return;
    setState(() {
      _scheduleFuture = _loadSchedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Itinerary')),
      body: _ScheduleList(
        future: _scheduleFuture,
        onToggleSchedule: _handleToggleActivitySchedule,
        onRefresh: refresh,
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final Future<List<ItineraryEntry>> future;
  final ValueChanged<String> onToggleSchedule;
  final Future<void> Function() onRefresh;

  const _ScheduleList({
    required this.future,
    required this.onToggleSchedule,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ItineraryEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyState(
                  icon: Icons.event_available_outlined,
                  message: 'No items yet',
                  detail:
                      'Activities you add to your schedule will show up here.',
                ),
              ],
            ),
          );
        }

        // Group by calendar day, earliest first.
        final grouped = <DateTime, List<ItineraryEntry>>{};
        for (final entry in entries) {
          final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
          grouped.putIfAbsent(day, () => []).add(entry);
        }
        final sortedDays = grouped.keys.toList()..sort();

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final day in sortedDays) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(
                    formatSingleDate(day),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final entry in grouped[day]!)
                  _ScheduleRow(
                    entry: entry,
                    onToggleSchedule: () => onToggleSchedule(entry.activityId),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Every entry in this list is, by definition, an activity the user has
// scheduled — so its heart is always filled. Tapping it removes it from
// the schedule (and this row; see
// MyItineraryShellScreenState._handleToggleActivitySchedule).
class _ScheduleRow extends StatelessWidget {
  final ItineraryEntry entry;
  final VoidCallback onToggleSchedule;

  const _ScheduleRow({required this.entry, required this.onToggleSchedule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/activities/${entry.activityId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  entry.activity.startTime,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.activity.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            entry.activity.venue,
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
              IconButton(
                onPressed: onToggleSchedule,
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.accentOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

