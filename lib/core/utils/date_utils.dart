/// Utility functions for date/time operations
class DateTimeUtils {
  DateTimeUtils._();

  /// Format duration to a readable string (e.g., "2h 30m")
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  /// Format estimated wait time from queue position
  static String formatWaitTime(int position, int minutesPerCustomer) {
    final totalMinutes = position * minutesPerCustomer;
    return formatDuration(Duration(minutes: totalMinutes));
  }
}