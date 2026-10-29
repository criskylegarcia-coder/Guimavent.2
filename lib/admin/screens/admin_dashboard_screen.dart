import 'package:flutter/material.dart';

import '../../repositories/admin_event_repository.dart';
import '../../repositories/admin_venue_repository.dart';
import '../../theme/app_theme.dart';

// Overview placeholder: simple counts only for Batch 1, per instructions —
// nothing fancier (no charts/trends) until a later batch asks for it.
class AdminDashboardScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final AdminEventRepository? repository;
  final AdminVenueRepository? venueRepository;

  const AdminDashboardScreen({super.key, this.repository, this.venueRepository});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminEventRepository _repository =
      widget.repository ?? SupabaseAdminEventRepository();
  late final AdminVenueRepository _venueRepository =
      widget.venueRepository ?? SupabaseAdminVenueRepository();
  late final Future<(int eventCount, int venueCount)> _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
  }

  Future<(int, int)> _loadCounts() async {
    final events = await _repository.getAllEvents();
    final venueCount = await _venueRepository.getVenueCount();
    return (events.length, venueCount);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          FutureBuilder<(int, int)>(
            future: _countsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final counts = snapshot.data;
              final eventCount = counts?.$1 ?? 0;
              final venueCount = counts?.$2 ?? 0;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _CountCard(
                    icon: Icons.event_outlined,
                    label: 'Total Events',
                    count: eventCount,
                  ),
                  _CountCard(
                    icon: Icons.place_outlined,
                    label: 'Total Venues',
                    count: venueCount,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _CountCard({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
