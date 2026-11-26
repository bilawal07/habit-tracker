/// Date formatting and calendar key helpers using local calendar dates.
abstract final class AppDateUtils {
  /// Formats [date] as `YYYY-MM-DD` in local time for SQLite `log_date`.
  static String toDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses a `YYYY-MM-DD` string into a local midnight [DateTime].
  static DateTime fromDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date key: $key');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Normalizes [date] to a UTC midnight date so calendar-day math is DST-safe.
  static DateTime normalizeUtcDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// Returns whether [a] and [b] fall on the same local calendar day.
  static bool isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Formats [date] for the Home screen header, e.g. `Thursday, Nov 26`.
  static String formatHeaderDate(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }
}
