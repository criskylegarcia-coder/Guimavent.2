import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/primary_button.dart';

// Step 3 of registration: a read-only summary of everything collected in
// steps 1-2, plus the "Generate QR Pass" submit action.
class ReviewStep extends StatelessWidget {
  final String fullName;
  final String nationality;
  final DateTime dateOfBirth;
  final String gender;
  final String email;
  final String mobileNumber;
  final DateTime dateOfArrival;
  final String portOfEntry;
  final DateTime dateOfDeparture;
  final String travelingWith;
  final String purposeOfVisit;
  final List<String> municipalitiesToVisit;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const ReviewStep({
    super.key,
    required this.fullName,
    required this.nationality,
    required this.dateOfBirth,
    required this.gender,
    required this.email,
    required this.mobileNumber,
    required this.dateOfArrival,
    required this.portOfEntry,
    required this.dateOfDeparture,
    required this.travelingWith,
    required this.purposeOfVisit,
    required this.municipalitiesToVisit,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              _ReviewGroup(
                title: 'Personal Info',
                rows: [
                  _ReviewRow('Full Name', fullName),
                  _ReviewRow('Nationality', nationality),
                  _ReviewRow('Date of Birth', formatSingleDate(dateOfBirth)),
                  _ReviewRow('Gender', gender),
                  _ReviewRow('Email Address', email),
                  _ReviewRow('Mobile Number', mobileNumber),
                ],
              ),
              const SizedBox(height: 16),
              _ReviewGroup(
                title: 'Travel Info',
                rows: [
                  _ReviewRow('Date of Arrival', formatSingleDate(dateOfArrival)),
                  _ReviewRow('Port of Entry', portOfEntry),
                  _ReviewRow(
                    'Date of Departure',
                    formatSingleDate(dateOfDeparture),
                  ),
                  _ReviewRow('Traveling With', travelingWith),
                  _ReviewRow('Purpose of Visit', purposeOfVisit),
                  _ReviewRow(
                    'Municipality(ies) to Visit',
                    municipalitiesToVisit.join(', '),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: PrimaryButton(
            label: isSubmitting ? 'Generating...' : 'Generate QR Pass',
            onPressed: isSubmitting ? null : onSubmit,
          ),
        ),
      ],
    );
  }
}

class _ReviewGroup extends StatelessWidget {
  final String title;
  final List<_ReviewRow> rows;

  const _ReviewGroup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
