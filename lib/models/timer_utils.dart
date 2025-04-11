import 'package:intl/intl.dart';

class TimerUtils {
  // Format seconds to MM:SS
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // Format seconds to readable text (e.g., 1 hour 30 minutes)
  static String formatDurationText(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return remainingSeconds > 0 
          ? '$minutes ${_pluralize(minutes, 'minute')}, $remainingSeconds ${_pluralize(remainingSeconds, 'second')}'
          : '$minutes ${_pluralize(minutes, 'minute')}';
    } else {
      final hours = seconds ~/ 3600;
      final remainingMinutes = (seconds % 3600) ~/ 60;
      return remainingMinutes > 0 
          ? '$hours ${_pluralize(hours, 'hour')}, $remainingMinutes ${_pluralize(remainingMinutes, 'minute')}'
          : '$hours ${_pluralize(hours, 'hour')}';
    }
  }
  
  // Format datetime to readable text
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (dateToCheck == today) {
      return 'Today, ${DateFormat.jm().format(dateTime)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else {
      return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
    }
  }
  
  // Helper method for pluralization
  static String _pluralize(int count, String word) {
    return count == 1 ? word : '${word}s';
  }
}