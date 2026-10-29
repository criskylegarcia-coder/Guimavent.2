import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';

// Reached from Profile's "Notification Center" row. There's no real
// notification system/backend yet — this just wires the navigation and a
// clean empty state, using the shared EmptyState widget. Building actual
// notifications is out of scope.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Center')),
      body: const EmptyState(
        icon: Icons.notifications_none_rounded,
        message: 'No notifications yet',
        detail:
            'Updates about your registration, itinerary, and events will '
            'show up here.',
      ),
    );
  }
}
