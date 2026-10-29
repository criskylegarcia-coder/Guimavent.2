import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/date_format.dart';

// A text-field-styled button that opens Flutter's date picker when tapped.
// Reused by every date field across the registration steps.
class DatePickerField extends StatelessWidget {
  final DateTime? value;
  final String placeholder;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  const DatePickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
        ),
        child: Text(
          value != null ? formatSingleDate(value!) : placeholder,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value != null
                ? AppColors.textDark
                : AppColors.textDark.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
