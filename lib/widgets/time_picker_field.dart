import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// A text-field-styled button that opens Flutter's time picker when tapped.
// Mirrors DatePickerField's style/pattern. Used by the Admin Portal's
// Activities form for start/end time-of-day — see activities_screen.dart
// for why only time (not a full date) is asked for there.
class TimePickerField extends StatelessWidget {
  final TimeOfDay? value;
  final String placeholder;
  final ValueChanged<TimeOfDay> onPicked;

  const TimePickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.access_time_rounded, size: 18),
        ),
        child: Text(
          value != null ? value!.format(context) : placeholder,
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
