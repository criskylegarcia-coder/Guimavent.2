import 'package:flutter/material.dart';

import '../../repositories/admin_activity_repository.dart';
import '../../repositories/admin_event_repository.dart';
import '../../repositories/admin_venue_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/time_picker_field.dart';

// Table/list view of every activity (sub_activity rows), with
// Create/Edit/Delete. Event and Venue options are read from the existing
// admin repositories, reused rather than duplicated — same pattern as
// venues_screen.dart reusing EventRepository for municipalities.
//
// start_time/end_time are full `timestamp` columns (date + time), but the
// form only asks for a time-of-day: the date is inferred from the selected
// event's startDate + (dayNumber - 1) days. Asking staff to also pick a
// full date independently would let day_number and the stored timestamp's
// actual calendar date disagree (e.g. day_number=2 but a manually-picked
// date that isn't the event's actual day 2) — an easy, silent way to
// corrupt the data with no validation catching it. Inferring the date
// removes an entire redundant, error-prone input; a live preview in the
// form ("Day 2 = May 17, 2026") shows staff exactly what date will be used
// before they save.
class ActivitiesScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final AdminActivityRepository? repository;
  final AdminEventRepository? eventRepository;
  final AdminVenueRepository? venueRepository;

  const ActivitiesScreen({
    super.key,
    this.repository,
    this.eventRepository,
    this.venueRepository,
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late final AdminActivityRepository _repository =
      widget.repository ?? SupabaseAdminActivityRepository();
  late final AdminEventRepository _eventRepository =
      widget.eventRepository ?? SupabaseAdminEventRepository();
  late final AdminVenueRepository _venueRepository =
      widget.venueRepository ?? SupabaseAdminVenueRepository();
  late Future<List<AdminActivity>> _activitiesFuture;
  late final Future<List<AdminEvent>> _eventsFuture;
  late final Future<List<AdminVenue>> _venuesFuture;
  // Shared with the Scrollbar below so it can show a persistent thumb —
  // with 6 columns (one more than Venues/Events) this table is wide enough
  // that Actions sits off-screen by default, and a scroll gesture with no
  // visible affordance reads as "the buttons are missing," not "scroll
  // right." The scrollbar makes that affordance visible instead of relying
  // on staff discovering they can scroll at all.
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _repository.getAllActivities();
    _eventsFuture = _eventRepository.getAllEvents();
    _venuesFuture = _venueRepository.getAllVenues();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _activitiesFuture = _repository.getAllActivities();
    });
  }

  Future<void> _openActivityForm({AdminActivity? existing}) async {
    final results = await Future.wait([_eventsFuture, _venuesFuture]);
    if (!mounted) return;
    final events = results[0] as List<AdminEvent>;
    final venues = results[1] as List<AdminVenue>;
    if (events.isEmpty || venues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            events.isEmpty
                ? 'Create an event first before adding activities.'
                : 'Create a venue first before adding activities.',
          ),
        ),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ActivityFormDialog(
        repository: _repository,
        events: events,
        venues: venues,
        existing: existing,
      ),
    );
    if (saved == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? 'Activity created' : 'Activity updated',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(AdminActivity activity) async {
    final referenceCount = await _repository.countReferencingItineraryItems(
      activity.id,
    );
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text(
          referenceCount > 0
              ? 'This will permanently delete "${activity.activityName}". '
                    "It is currently in $referenceCount ${referenceCount == 1 ? 'user’s' : 'users’'} "
                    'schedule — deleting it will automatically remove it '
                    'from their itinerary (this activity is not blocked '
                    'from deletion by that, unlike venues). This cannot be '
                    'undone.'
              : 'This will permanently delete "${activity.activityName}". '
                    'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteActivity(activity.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activity deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is RepositoryException
                  ? e.message
                  : 'Could not delete activity.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activities',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openActivityForm(),
                icon: const Icon(Icons.add),
                label: const Text('Create Activity'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<AdminActivity>>(
              future: _activitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final activities = snapshot.data ?? const [];
                if (activities.isEmpty) {
                  return const Center(child: Text('No activities yet.'));
                }
                // Nested scroll views: outer vertical, inner horizontal —
                // a single horizontal-only SingleChildScrollView silently
                // hard-clips (its default clipBehavior) any table content
                // that doesn't fit vertically, with no overflow warning and
                // no way to reach it (confirmed root cause on
                // VenuesScreen/AdminEventsScreen) — built correctly here
                // from the start rather than reintroducing that bug.
                return SingleChildScrollView(
                  child: Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Activity Name')),
                          DataColumn(label: Text('Event')),
                          DataColumn(label: Text('Venue')),
                          DataColumn(label: Text('Day')),
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final activity in activities)
                            DataRow(
                              cells: [
                                DataCell(Text(activity.activityName)),
                                DataCell(Text(activity.eventName)),
                                DataCell(Text(activity.venueName)),
                                DataCell(Text(activity.dayNumber.toString())),
                                DataCell(
                                  Text(
                                    '${formatTimeOfDay(activity.startTime)} - '
                                    '${formatTimeOfDay(activity.endTime)}',
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit',
                                        onPressed: () => _openActivityForm(
                                          existing: activity,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete',
                                        onPressed: () =>
                                            _handleDelete(activity),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
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

class _ActivityFormDialog extends StatefulWidget {
  final AdminActivityRepository repository;
  final List<AdminEvent> events;
  final List<AdminVenue> venues;
  final AdminActivity? existing;

  const _ActivityFormDialog({
    required this.repository,
    required this.events,
    required this.venues,
    this.existing,
  });

  @override
  State<_ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<_ActivityFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dayNumberController;
  String? _eventId;
  String? _venueId;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.activityName ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _dayNumberController = TextEditingController(
      text: existing != null ? existing.dayNumber.toString() : '1',
    );
    _eventId =
        existing?.eventId ??
        (widget.events.isNotEmpty ? widget.events.first.id : null);
    _venueId =
        existing?.venueId ??
        (widget.venues.isNotEmpty ? widget.venues.first.id : null);
    _startTime = existing != null
        ? TimeOfDay.fromDateTime(existing.startTime)
        : null;
    _endTime = existing != null
        ? TimeOfDay.fromDateTime(existing.endTime)
        : null;
    _dayNumberController.addListener(_refreshDatePreview);
  }

  @override
  void dispose() {
    _dayNumberController.removeListener(_refreshDatePreview);
    _nameController.dispose();
    _descriptionController.dispose();
    _dayNumberController.dispose();
    super.dispose();
  }

  // Just triggers a rebuild so the date preview below the Day Number field
  // stays in sync as the admin types — the preview itself is computed
  // fresh in build(), nothing to store here.
  void _refreshDatePreview() => setState(() {});

  AdminEvent? get _selectedEvent {
    for (final event in widget.events) {
      if (event.id == _eventId) return event;
    }
    return null;
  }

  DateTime? get _inferredDate {
    final event = _selectedEvent;
    final day = int.tryParse(_dayNumberController.text.trim());
    if (event == null || day == null || day < 1) return null;
    return event.startDate.add(Duration(days: day - 1));
  }

  int _timeOfDayMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  // "Day 2 = May 17, 2026" normally, or "Day 2 = May 17, 2026, 9:45 PM -
  // May 18, 2026, 12:45 AM" once both times are picked and the end time is
  // earlier than the start time (crossing midnight) — so staff see exactly
  // what will be saved before saving it.
  String _dayNumberHelperText(BuildContext context) {
    if (_selectedEvent == null) return 'Select an event to see the date';
    final date = _inferredDate;
    if (date == null) return 'Enter a valid day number';
    final dayLabel = 'Day ${_dayNumberController.text.trim()}';
    final start = _startTime;
    final end = _endTime;
    if (start == null || end == null) {
      return '$dayLabel = ${formatSingleDate(date)}';
    }
    if (_timeOfDayMinutes(end) >= _timeOfDayMinutes(start)) {
      return '$dayLabel = ${formatSingleDate(date)}';
    }
    final endDate = date.add(const Duration(days: 1));
    return '$dayLabel = ${formatSingleDate(date)}, ${start.format(context)} - '
        '${formatSingleDate(endDate)}, ${end.format(context)}';
  }

  Future<void> _handleSave() async {
    final formValid = _formKey.currentState!.validate();
    debugPrint(
      '[ActivityFormDialog] _handleSave: formValid=$formValid '
      'eventId=$_eventId venueId=$_venueId '
      'name="${_nameController.text}" '
      'dayNumberText="${_dayNumberController.text}" '
      'startTime=$_startTime endTime=$_endTime',
    );
    if (!formValid) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: ABORTED — form validation failed',
      );
      return;
    }
    if (_eventId == null) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: ABORTED — no event selected',
      );
      setState(() => _errorMessage = 'Please select an event.');
      return;
    }
    if (_venueId == null) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: ABORTED — no venue selected',
      );
      setState(() => _errorMessage = 'Please select a venue.');
      return;
    }
    if (_startTime == null || _endTime == null) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: ABORTED — missing time '
        '(startTime=$_startTime, endTime=$_endTime)',
      );
      setState(() => _errorMessage = 'Please pick both a start and end time.');
      return;
    }
    final date = _inferredDate;
    if (date == null) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: ABORTED — could not infer date '
        '(selectedEvent=$_selectedEvent, '
        'dayNumberText="${_dayNumberController.text}")',
      );
      setState(() => _errorMessage = 'Enter a valid day number.');
      return;
    }

    // A picked end time earlier than the start time (e.g. start 9:45 PM,
    // end 12:45 AM) means the activity runs past midnight into the next
    // calendar day — day_number's date + 1 — not an error. Equal times
    // (zero duration) still aren't valid.
    final crossesMidnight =
        _timeOfDayMinutes(_endTime!) < _timeOfDayMinutes(_startTime!);
    final endDateOnly = crossesMidnight
        ? date.add(const Duration(days: 1))
        : date;

    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final endDateTime = DateTime(
      endDateOnly.year,
      endDateOnly.month,
      endDateOnly.day,
      _endTime!.hour,
      _endTime!.minute,
    );
    if (!endDateTime.isAfter(startDateTime)) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: ABORTED — end time equals start '
        'time (start=$startDateTime, end=$endDateTime)',
      );
      setState(
        () => _errorMessage = 'End time must be different from start time.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final dayNumber = int.parse(_dayNumberController.text.trim());
      debugPrint(
        '[ActivityFormDialog] _handleSave: calling '
        '${widget.existing == null ? "createActivity" : "updateActivity"} '
        'eventId=$_eventId venueId=$_venueId dayNumber=$dayNumber '
        'activityName="${_nameController.text.trim()}" '
        'description="${_descriptionController.text.trim()}" '
        'startTime=$startDateTime endTime=$endDateTime',
      );
      if (widget.existing == null) {
        await widget.repository.createActivity(
          eventId: _eventId!,
          venueId: _venueId!,
          dayNumber: dayNumber,
          activityName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
        );
      } else {
        await widget.repository.updateActivity(
          widget.existing!.id,
          eventId: _eventId!,
          venueId: _venueId!,
          dayNumber: dayNumber,
          activityName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
        );
      }
      debugPrint('[ActivityFormDialog] _handleSave: repository call SUCCEEDED');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint(
        '[ActivityFormDialog] _handleSave: repository call THREW: $e\n$st',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = e is RepositoryException
            ? e.message
            : 'Could not save activity.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Create Activity' : 'Edit Activity',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _eventId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Event',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final event in widget.events)
                      DropdownMenuItem(
                        value: event.id,
                        child: Text(
                          event.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _eventId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _venueId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Venue',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final venue in widget.venues)
                      DropdownMenuItem(
                        value: venue.id,
                        child: Text(
                          venue.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _venueId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Activity Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dayNumberController,
                  decoration: InputDecoration(
                    labelText: 'Day Number',
                    hintText: 'e.g. 1, 2, 3 for a multi-day event',
                    border: const OutlineInputBorder(),
                    helperText: _dayNumberHelperText(context),
                    helperMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Required';
                    final parsed = int.tryParse(trimmed);
                    if (parsed == null || parsed < 1) {
                      return 'Must be a whole number, 1 or greater';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TimePickerField(
                        value: _startTime,
                        placeholder: 'Start time',
                        onPicked: (time) => setState(() => _startTime = time),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TimePickerField(
                        value: _endTime,
                        placeholder: 'End time',
                        onPicked: (time) => setState(() => _endTime = time),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
