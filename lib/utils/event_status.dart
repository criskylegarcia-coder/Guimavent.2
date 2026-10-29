/// An event's status relative to today, derived from its date range —
/// shown as a small colored badge on event cards and Event Details (see
/// widgets/event_status_badge.dart).
enum EventStatus { upcoming, ongoing, ended }

/// Compares [startDate]/[endDate] against [now] (defaults to the real
/// current time; pass an explicit [now] in tests for a deterministic
/// result) by calendar day, not exact time-of-day — an event starting
/// later today still counts as "Ongoing", not "Upcoming".
EventStatus computeEventStatus(
  DateTime startDate,
  DateTime endDate, {
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final start = _dateOnly(startDate);
  final end = _dateOnly(endDate);
  if (today.isBefore(start)) return EventStatus.upcoming;
  if (today.isAfter(end)) return EventStatus.ended;
  return EventStatus.ongoing;
}

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);
