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
}
