import '../models/hub_event.dart';

// Short, uppercase-friendly date and time text for event cards.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "09:30"
String clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// "Today", "Tomorrow", "Yesterday" or "Thu 30 Oct".
String dayName(DateTime t, DateTime now) {
  // Rounded, so a daylight-saving day of 23 or 25 hours still counts as one.
  final days = (DateTime(t.year, t.month, t.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inHours /
          24)
      .round();
  return switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}',
  };
}

/// "28 Oct 2026"
String calendarDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

/// "2 h", "45 min", "3 days"
String span(Duration d) {
  if (d.inDays >= 2) return '${d.inDays} days';
  if (d.inHours >= 1) return '${d.inHours} h';
  return '${d.inMinutes < 1 ? 1 : d.inMinutes} min';
}

/// When it happens: "Today 09:30–11:00" for events, "Due tomorrow 18:00" for challenges.
String scheduleLine(HubEvent e, DateTime now) {
  if (e.isChallenge) return 'Due ${dayName(e.endsAt, now).toLowerCase()} ${clock(e.endsAt)}';
  final sameDay = dayName(e.startsAt, now) == dayName(e.endsAt, now);
  final end = sameDay ? clock(e.endsAt) : '${dayName(e.endsAt, now)} ${clock(e.endsAt)}';
  return '${dayName(e.startsAt, now)} ${clock(e.startsAt)}–$end';
}

/// How far away it is: "Starts in 2 h", "Ends in 45 min", "Ended".
String countdown(HubEvent e, DateTime now) => switch (e.state) {
      EventState.upcoming => '${e.isChallenge ? 'Opens' : 'Starts'} in ${span(e.startsAt.difference(now))}',
      EventState.live => '${e.isChallenge ? 'Closes' : 'Ends'} in ${span(e.endsAt.difference(now))}',
      EventState.ended => e.isChallenge ? 'Closed' : 'Ended',
    };

/// How long ago, compactly: "now", "12m", "3h", "2d", then "28 Oct".
String timeAgo(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day} ${_months[t.month - 1]}';
}
