import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/field_label.dart';
import '../../widgets/primary_button.dart';

// Step 1 of registration: who's registering. All the field values live in
// RegistrationShellScreen's State — this widget just renders them and
// reports changes back up via the on...Changed callbacks.
class PersonalInfoStep extends StatelessWidget {
  static const List<String> countries = [
    'Philippines',
    'United States',
    'Japan',
    'South Korea',
    'China',
    'Australia',
    'United Kingdom',
    'Canada',
    'Singapore',
    'Other',
  ];

  final TextEditingController fullNameController;
  final String nationality;
  final ValueChanged<String> onNationalityChanged;
  final DateTime? dateOfBirth;
  final ValueChanged<DateTime> onDateOfBirthChanged;
  final String? gender;
  final ValueChanged<String> onGenderChanged;
  final TextEditingController emailController;
  final TextEditingController mobileController;
  final bool isValid;
  final VoidCallback onNext;

  const PersonalInfoStep({
    super.key,
    required this.fullNameController,
    required this.nationality,
    required this.onNationalityChanged,
    required this.dateOfBirth,
    required this.onDateOfBirthChanged,
    required this.gender,
    required this.onGenderChanged,
    required this.emailController,
    required this.mobileController,
    required this.isValid,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              const FieldLabel('Full Name'),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(hintText: 'Juan Dela Cruz'),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Nationality'),
              DropdownButtonFormField<String>(
                initialValue: nationality,
                decoration: const InputDecoration(),
                // Without this, the dropdown sizes itself to its widest
                // item's natural width instead of the available field
                // width — "United Kingdom" was overflowing at narrow
                // widths as a result.
                isExpanded: true,
                items: [
                  for (final country in countries)
                    DropdownMenuItem(
                      value: country,
                      child: Text(country, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onNationalityChanged(value);
                },
              ),
              const SizedBox(height: 16),
              const FieldLabel('Date of Birth'),
              DatePickerField(
                value: dateOfBirth,
                placeholder: 'Select date of birth',
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                onPicked: onDateOfBirthChanged,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Gender'),
              RadioGroup<String>(
                groupValue: gender,
                onChanged: (value) {
                  if (value != null) onGenderChanged(value);
                },
                child: Row(
                  children: [
                    for (final option in const ['Male', 'Female', 'Others'])
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            option,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: option,
                          activeColor: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Email Address'),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'juan@email.com'),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Mobile Number'),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '09XX XXX XXXX'),
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
