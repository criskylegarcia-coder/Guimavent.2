// Shared date-formatting helpers so every widget/screen that shows a date
// formats it the same way instead of each rolling its own.

const List<String> monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "May 1 - May 3, 2025" when start and end differ,
/// or just "Jan 12, 2025" when they're the same day.
String formatDateRange(DateTime start, DateTime end) {
  final startLabel = '${monthNames[start.month - 1]} ${start.day}';
  final endLabel = '${monthNames[end.month - 1]} ${end.day}';
  final isSameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  if (isSameDay) {
    return '$startLabel, ${start.year}';
  }
  return '$startLabel - $endLabel, ${end.year}';
}

/// "May 1, 2025"
String formatSingleDate(DateTime date) {
  return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

/// "8:00 AM" — the time-of-day portion of `dateTime`.
String formatTimeOfDay(DateTime dateTime) {
  final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}
