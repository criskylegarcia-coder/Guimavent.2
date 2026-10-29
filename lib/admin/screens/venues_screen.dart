import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/municipality.dart';
import '../../repositories/admin_venue_repository.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../repositories/supabase_event_repository.dart';
import '../../theme/app_theme.dart';

// Guimaras' actual geographic area, roughly — used only to WARN (not
// block) if entered coordinates look like a typo (e.g. a missing decimal
// point placing a pin in the ocean or another country). Real-world venues
// could legitimately fall just outside this box, so it's a confirmation
// prompt, not a hard validator.
const double _guimarasMinLat = 10.5;
const double _guimarasMaxLat = 10.8;
const double _guimarasMinLng = 122.3;
const double _guimarasMaxLng = 122.7;

// Known venue_type values confirmed live (read-only query) before building
// this: only "landmark" and "local_spot" exist in the current data, from a
// small sample (6 rows) with no CHECK constraint confirmed either way — so
// this offers those two plus a free-text "Other" rather than inventing a
// fixed list that might not match what's actually allowed.
const List<String> _knownVenueTypes = ['landmark', 'local_spot'];
const String _otherVenueType = 'Other';

// Table/list view of every venue, with Create/Edit/Delete. Municipality
// options are read from the existing (tourist-facing) EventRepository,
// reused rather than duplicated, same pattern as admin_events_screen.dart.
class VenuesScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final AdminVenueRepository? repository;
  final EventRepository? eventRepository;

  const VenuesScreen({super.key, this.repository, this.eventRepository});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  late final AdminVenueRepository _repository =
      widget.repository ?? SupabaseAdminVenueRepository();
  late final EventRepository _eventRepository =
      widget.eventRepository ?? SupabaseEventRepository();
  late Future<List<AdminVenue>> _venuesFuture;
  late final Future<List<Municipality>> _municipalitiesFuture;

  @override
  void initState() {
    super.initState();
    _venuesFuture = _fetchVenues();
    _municipalitiesFuture = _eventRepository.getMunicipalities();
  }

  void _refresh() {
    setState(() {
      _venuesFuture = _fetchVenues();
    });
  }

  Future<List<AdminVenue>> _fetchVenues() {
    debugPrint('[VenuesScreen] _fetchVenues: calling repository.getAllVenues()');
    return _repository
        .getAllVenues()
        .then((venues) {
          debugPrint(
            '[VenuesScreen] _fetchVenues: received ${venues.length} '
            'venue(s): ${venues.map((v) => v.name).join(', ')}',
          );
          return venues;
        })
        .catchError((Object e, StackTrace st) {
          debugPrint('[VenuesScreen] _fetchVenues: THREW: $e\n$st');
          throw e;
        });
  }

  Future<void> _openVenueForm({AdminVenue? existing}) async {
    final municipalities = await _municipalitiesFuture;
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _VenueFormDialog(
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
            content: Text(existing == null ? 'Venue created' : 'Venue updated'),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(AdminVenue venue) async {
    final referenceCount = await _repository.countReferencingSubActivities(
      venue.id,
    );
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete venue?'),
        content: Text(
          referenceCount > 0
              ? 'This will permanently delete "${venue.name}". It is currently '
                    'used by $referenceCount scheduled ${referenceCount == 1 ? 'activity' : 'activities'} '
                    '— deleting it will likely be rejected by the database '
                    'until those activities are moved to a different venue '
                    'or removed. This cannot be undone.'
              : 'This will permanently delete "${venue.name}". This cannot be undone.',
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
      await _repository.deleteVenue(venue.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Venue deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is RepositoryException ? e.message : 'Could not delete venue.',
            ),
          ),
        );
      }
    }
  }

  // Explicit loop (not a list-literal `for`) specifically so a debugPrint
  // can sit right at the point each DataRow is actually constructed — the
  // most direct possible check of whether all 13 venues really reach this
  // exact call, one at a time.
  List<DataRow> _buildRows(List<AdminVenue> venues) {
    final rows = <DataRow>[];
    for (final venue in venues) {
      debugPrint(
        '[VenuesScreen] _buildRows: constructing DataRow for '
        '${venue.id}:${venue.name}',
      );
      rows.add(
        DataRow(
          cells: [
            DataCell(Text(venue.name)),
            DataCell(Text(venue.municipalityName)),
            DataCell(Text(venue.venueType)),
            DataCell(
              Text(
                '${venue.latitude.toStringAsFixed(5)}, '
                '${venue.longitude.toStringAsFixed(5)}',
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _openVenueForm(existing: venue),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _handleDelete(venue),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    debugPrint('[VenuesScreen] _buildRows: constructed ${rows.length} DataRow(s) total');
    return rows;
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
                  'Venues',
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
                onPressed: () => _openVenueForm(),
                icon: const Icon(Icons.add),
                label: const Text('Create Venue'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<AdminVenue>>(
              future: _venuesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final venues = snapshot.data ?? const [];
                if (venues.isEmpty) {
                  return const Center(child: Text('No venues yet.'));
                }
                debugPrint(
                  '[VenuesScreen] build: about to construct DataRows for '
                  '${venues.length} venue(s)',
                );
                // Nested scroll views: outer vertical, inner horizontal.
                // A single horizontal-only SingleChildScrollView silently
                // hard-clips (its default clipBehavior) any table content
                // that doesn't fit vertically, with no overflow warning and
                // no way to reach it — confirmed root cause of venues (e.g.
                // "Igang Plaza") going missing from the list once there were
                // enough rows to exceed the available height. The vertical
                // ScrollView here fixes that regardless of row count.
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Venue Name')),
                        DataColumn(label: Text('Municipality')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Coordinates')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _buildRows(venues),
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

class _VenueFormDialog extends StatefulWidget {
  final AdminVenueRepository repository;
  final List<Municipality> municipalities;
  final AdminVenue? existing;

  const _VenueFormDialog({
    required this.repository,
    required this.municipalities,
    this.existing,
  });

  @override
  State<_VenueFormDialog> createState() => _VenueFormDialogState();
}

class _VenueFormDialogState extends State<_VenueFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _otherVenueTypeController;
  String? _municipalityId;
  String? _venueTypeSelection;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(
      text: existing?.addressDescription ?? '',
    );
    _latController = TextEditingController(
      text: existing != null ? existing.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: existing != null ? existing.longitude.toString() : '',
    );
    final existingType = existing?.venueType;
    final isKnownType = existingType != null && _knownVenueTypes.contains(existingType);
    _venueTypeSelection = existing == null
        ? (_knownVenueTypes.isNotEmpty ? _knownVenueTypes.first : _otherVenueType)
        : (isKnownType ? existingType : _otherVenueType);
    _otherVenueTypeController = TextEditingController(
      text: (existing != null && !isKnownType) ? existingType ?? '' : '',
    );
    _municipalityId =
        existing?.municipalityId ??
        (widget.municipalities.isNotEmpty ? widget.municipalities.first.id : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _otherVenueTypeController.dispose();
    super.dispose();
  }

  Future<void> _previewOnMap() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      setState(
        () => _errorMessage = 'Enter valid coordinates first to preview them.',
      );
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _looksOutsideGuimaras(double lat, double lng) {
    return lat < _guimarasMinLat ||
        lat > _guimarasMaxLat ||
        lng < _guimarasMinLng ||
        lng > _guimarasMaxLng;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_municipalityId == null) {
      setState(() => _errorMessage = 'Please select a municipality.');
      return;
    }

    final lat = double.parse(_latController.text.trim());
    final lng = double.parse(_lngController.text.trim());

    if (_looksOutsideGuimaras(lat, lng)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Coordinates look unusual'),
          content: Text(
            '$lat, $lng is outside Guimaras\' typical area. Double-check '
            'for a typo (e.g. a missing decimal point) before continuing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final venueType = _venueTypeSelection == _otherVenueType
        ? _otherVenueTypeController.text.trim()
        : _venueTypeSelection!;
    if (venueType.isEmpty) {
      setState(() => _errorMessage = 'Please enter a venue type.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      if (widget.existing == null) {
        await widget.repository.createVenue(
          name: _nameController.text.trim(),
          municipalityId: _municipalityId!,
          venueType: venueType,
          addressDescription: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
        );
      } else {
        await widget.repository.updateVenue(
          widget.existing!.id,
          name: _nameController.text.trim(),
          municipalityId: _municipalityId!,
          venueType: venueType,
          addressDescription: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is RepositoryException
            ? e.message
            : 'Could not save venue.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Create Venue' : 'Edit Venue'),
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
                    labelText: 'Venue Name',
                    border: OutlineInputBorder(),
                  ),
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
                DropdownButtonFormField<String>(
                  initialValue: _venueTypeSelection,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Venue Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final type in _knownVenueTypes)
                      DropdownMenuItem(value: type, child: Text(type)),
                    const DropdownMenuItem(
                      value: _otherVenueType,
                      child: Text(_otherVenueType),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _venueTypeSelection = value),
                ),
                if (_venueTypeSelection == _otherVenueType) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherVenueTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Venue Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'e.g. 10.5929',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          final parsed = double.tryParse(trimmed);
                          if (parsed == null) return 'Not a number';
                          if (parsed < -90 || parsed > 90) {
                            return 'Must be between -90 and 90';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'e.g. 122.5968',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Required';
                          final parsed = double.tryParse(trimmed);
                          if (parsed == null) return 'Not a number';
                          if (parsed < -180 || parsed > 180) {
                            return 'Must be between -180 and 180';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _previewOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Preview on map'),
                  ),
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
