import 'package:flutter/material.dart';

import '../../models/municipality.dart';
import '../../repositories/admin_event_repository.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/date_picker_field.dart';

// Table/list view of every event, with Create/Edit/Delete. Municipality
// options are read from the existing (tourist-facing) EventRepository —
// reused rather than duplicated, per instructions — but all writes go
// through AdminEventRepository, which the tourist app never touches.
class AdminEventsScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final AdminEventRepository? repository;
  final EventRepository? eventRepository;

  const AdminEventsScreen({super.key, this.repository, this.eventRepository});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  late final AdminEventRepository _repository =
      widget.repository ?? SupabaseAdminEventRepository();
  late final EventRepository _eventRepository =
      widget.eventRepository ?? SupabaseEventRepository();
  late Future<List<AdminEvent>> _eventsFuture;
  late final Future<List<Municipality>> _municipalitiesFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _repository.getAllEvents();
    _municipalitiesFuture = _eventRepository.getMunicipalities();
  }

  void _refresh() {
    setState(() {
      _eventsFuture = _repository.getAllEvents();
    });
  }

  Future<void> _openEventForm({AdminEvent? existing}) async {
    final municipalities = await _municipalitiesFuture;
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EventFormDialog(
        repository: _repository,
        municipalities: municipalities,
        existing: existing,
      ),
    );
    if (saved == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'Event created' : 'Event updated'),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(AdminEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          'This will permanently delete "${event.name}". This cannot be undone.',
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
      await _repository.deleteEvent(event.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is RepositoryException ? e.message : 'Could not delete event.',
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
                  'Events',
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
                onPressed: () => _openEventForm(),
                icon: const Icon(Icons.add),
                label: const Text('Create Event'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<AdminEvent>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final events = snapshot.data ?? const [];
                if (events.isEmpty) {
                  return const Center(child: Text('No events yet.'));
                }
                // Nested scroll views: outer vertical, inner horizontal —
                // same fix as VenuesScreen. A horizontal-only
                // SingleChildScrollView silently hard-clips (its default
                // clipBehavior) any table content that doesn't fit
                // vertically, with no overflow warning and no way to reach
                // it, once there are enough rows to exceed the available
                // height.
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Event Name')),
                        DataColumn(label: Text('Municipality')),
                        DataColumn(label: Text('Dates')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final event in events)
                          DataRow(
                            cells: [
                              DataCell(Text(event.name)),
                              DataCell(Text(event.municipalityName)),
                              DataCell(
                                Text(formatDateRange(event.startDate, event.endDate)),
                              ),
                              DataCell(Text(event.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Edit',
                                      onPressed: () =>
                                          _openEventForm(existing: event),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () => _handleDelete(event),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
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

class _EventFormDialog extends StatefulWidget {
  final AdminEventRepository repository;
  final List<Municipality> municipalities;
  final AdminEvent? existing;

  const _EventFormDialog({
    required this.repository,
    required this.municipalities,
    this.existing,
  });

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _bannerUrlController;
  late final TextEditingController _statusController;
  String? _municipalityId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _bannerUrlController = TextEditingController(
      text: existing?.bannerImageUrl ?? '',
    );
    _statusController = TextEditingController(text: existing?.status ?? 'active');
    _municipalityId =
        existing?.municipalityId ??
        (widget.municipalities.isNotEmpty ? widget.municipalities.first.id : null);
    _startDate = existing?.startDate;
    _endDate = existing?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _bannerUrlController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Please pick both a start and end date.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(
        () => _errorMessage = 'End date must be on or after the start date.',
      );
      return;
    }
    if (_municipalityId == null) {
      setState(() => _errorMessage = 'Please select a municipality.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      if (widget.existing == null) {
        await widget.repository.createEvent(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          municipalityId: _municipalityId!,
          startDate: _startDate!,
          endDate: _endDate!,
          bannerImageUrl: _bannerUrlController.text.trim(),
          status: _statusController.text.trim(),
        );
      } else {
        await widget.repository.updateEvent(
          widget.existing!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          municipalityId: _municipalityId!,
          startDate: _startDate!,
          endDate: _endDate!,
          bannerImageUrl: _bannerUrlController.text.trim(),
          status: _statusController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is RepositoryException
            ? e.message
            : 'Could not save event.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create Event' : 'Edit Event'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _municipalityId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Municipality',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final municipality in widget.municipalities)
                      DropdownMenuItem(
                        value: municipality.id,
                        child: Text(
                          municipality.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _municipalityId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DatePickerField(
                        value: _startDate,
                        placeholder: 'Start date',
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        onPicked: (date) => setState(() => _startDate = date),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DatePickerField(
                        value: _endDate,
                        placeholder: 'End date',
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        onPicked: (date) => setState(() => _endDate = date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bannerUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Banner Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _statusController,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    hintText: 'e.g. active, upcoming, cancelled',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
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
