import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/field_label.dart';
import '../../widgets/primary_button.dart';

// Step 2 of registration: trip details. Same lifted-state pattern as
// PersonalInfoStep — values and their setters both come from
// RegistrationShellScreen.
class TravelInfoStep extends StatelessWidget {
  static const List<String> ports = [
    'Jordan Wharf',
    'Buenavista Port',
    'Iloilo-Guimaras Ferry Terminal',
  ];
  static const List<String> travelingWithOptions = [
    'Solo',
    'Family',
    'Friends',
    'Group Tour',
  ];
  static const List<String> purposes = [
    'Leisure/Vacation',
    'Business',
    'Event/Festival',
    'Other',
  ];
  static const List<String> municipalityOptions = [
    'Buenavista',
    'Jordan',
    'Nueva Valencia',
    'San Lorenzo',
    'Sibunag',
  ];

  final DateTime? dateOfArrival;
  final ValueChanged<DateTime> onDateOfArrivalChanged;
  final String? portOfEntry;
  final ValueChanged<String> onPortOfEntryChanged;
  final DateTime? dateOfDeparture;
  final ValueChanged<DateTime> onDateOfDepartureChanged;
  final String? travelingWith;
  final ValueChanged<String> onTravelingWithChanged;
  final String? purposeOfVisit;
  final ValueChanged<String> onPurposeOfVisitChanged;
  final List<String> municipalitiesToVisit;
  final ValueChanged<List<String>> onMunicipalitiesChanged;
  final bool isValid;
  final VoidCallback onNext;

  const TravelInfoStep({
    super.key,
    required this.dateOfArrival,
    required this.onDateOfArrivalChanged,
    required this.portOfEntry,
    required this.onPortOfEntryChanged,
    required this.dateOfDeparture,
    required this.onDateOfDepartureChanged,
    required this.travelingWith,
    required this.onTravelingWithChanged,
    required this.purposeOfVisit,
    required this.onPurposeOfVisitChanged,
    required this.municipalitiesToVisit,
    required this.onMunicipalitiesChanged,
    required this.isValid,
    required this.onNext,
  });

  bool get _departureBeforeArrival =>
      dateOfArrival != null &&
      dateOfDeparture != null &&
      !dateOfDeparture!.isAfter(dateOfArrival!);

  @override
  Widget build(BuildContext context) {
    final arrivalFloor = dateOfArrival ?? DateTime.now();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              const FieldLabel('Date of Arrival'),
              DatePickerField(
                value: dateOfArrival,
                placeholder: 'Select arrival date',
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onPicked: onDateOfArrivalChanged,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Port of Entry'),
              DropdownButtonFormField<String>(
                initialValue: portOfEntry,
                decoration: const InputDecoration(),
                hint: const Text('Select port of entry'),
                // Without this, long items like "Iloilo-Guimaras Ferry
                // Terminal" force the dropdown wider than the field,
                // overflowing at narrow widths.
                isExpanded: true,
                items: [
                  for (final port in ports)
                    DropdownMenuItem(
                      value: port,
                      child: Text(port, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onPortOfEntryChanged(value);
                },
              ),
              const SizedBox(height: 16),
              const FieldLabel('Date of Departure'),
              DatePickerField(
                value: dateOfDeparture,
                placeholder: 'Select departure date',
                firstDate: arrivalFloor,
                lastDate: arrivalFloor.add(const Duration(days: 365)),
                onPicked: onDateOfDepartureChanged,
              ),
              if (_departureBeforeArrival)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Departure must be after arrival',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const FieldLabel('Traveling With'),
              DropdownButtonFormField<String>(
                initialValue: travelingWith,
                decoration: const InputDecoration(),
                hint: const Text('Select an option'),
                isExpanded: true,
                items: [
                  for (final option in travelingWithOptions)
                    DropdownMenuItem(
                      value: option,
                      child: Text(option, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onTravelingWithChanged(value);
                },
              ),
              const SizedBox(height: 16),
              const FieldLabel('Purpose of Visit'),
              DropdownButtonFormField<String>(
                initialValue: purposeOfVisit,
                decoration: const InputDecoration(),
                hint: const Text('Select an option'),
                isExpanded: true,
                items: [
                  for (final purpose in purposes)
                    DropdownMenuItem(
                      value: purpose,
                      child: Text(purpose, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onPurposeOfVisitChanged(value);
                },
              ),
              const SizedBox(height: 16),
              const FieldLabel('Municipality(ies) to Visit'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final municipality in municipalityOptions)
                    FilterChip(
                      label: Text(municipality),
                      selected: municipalitiesToVisit.contains(municipality),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(
                        color: municipalitiesToVisit.contains(municipality)
                            ? AppColors.primary
                            : AppColors.textDark.withValues(alpha: 0.2),
                      ),
                      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: municipalitiesToVisit.contains(municipality)
                            ? AppColors.primary
                            : AppColors.textDark,
                        fontWeight: municipalitiesToVisit.contains(municipality)
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      onSelected: (selected) {
                        final updated = List<String>.from(municipalitiesToVisit);
                        if (selected) {
                          updated.add(municipality);
                        } else {
                          updated.remove(municipality);
                        }
                        onMunicipalitiesChanged(updated);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: PrimaryButton(label: 'Next', onPressed: isValid ? onNext : null),
        ),
      ],
    );
  }
}
