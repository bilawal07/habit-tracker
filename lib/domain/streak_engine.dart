import 'dart:math';

import '../core/utils/date_utils.dart';
import '../data/models/daily_log.dart';

/// Psychological streak states in the Hot Fire / Cold habit loop.
enum StreakState {
  ready('Ready', 'Check today to ignite your first spark!'),
  cold('Cold', 'Your streak is Cold! Check today to reignite.'),
  spark('Spark', 'Warming back up! Keep going to hit Hot Fire.'),
  hotFire('Hot Fire', 'Blazing momentum! Protect your streak today.'),
  blazing('Blazing', '7+ days unstoppable! Keep the inferno alive.');

  const StreakState(this.label, this.message);

  final String label;
  final String message;

  bool get isWarmOrHot =>
      this == StreakState.spark ||
      this == StreakState.hotFire ||
      this == StreakState.blazing;
}

/// Calculated streak metrics for a single habit task.
class StreakStats {
  const StreakStats({
    required this.state,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletedDays,
    required this.isCheckedToday,
    required this.wasColdBeforeCurrentRun,
  });

  final StreakState state;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletedDays;
  final bool isCheckedToday;

  /// True when the active streak began after a previous Cold gap.
  final bool wasColdBeforeCurrentRun;
}

/// Pure-Dart streak calculator from local SQLite completion logs.
abstract final class StreakEngine {
  static StreakStats fromLogs(
    List<DailyLog> logs, {
    required DateTime createdAt,
    DateTime? now,
  }) {
    final completedDates = logs.map((log) => AppDateUtils.fromDateKey(log.logDate));
    return calculate(
      completedDates: completedDates,
      createdAt: createdAt,
      now: now,
    );
  }

  static StreakStats calculate({
    required Iterable<DateTime> completedDates,
    required DateTime createdAt,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = AppDateUtils.normalizeUtcDate(reference);
    final yesterday = today.subtract(const Duration(days: 1));
    final createdDay = AppDateUtils.normalizeUtcDate(createdAt);

    final daySet = <DateTime>{
      for (final date in completedDates) AppDateUtils.normalizeUtcDate(date),
    };
    final sortedDays = daySet.toList()..sort();

    final bestStreak = _calculateBestStreak(sortedDays);
    final isCheckedToday = daySet.contains(today);

    final DateTime? anchorDay;
    if (isCheckedToday) {
      anchorDay = today;
    } else if (daySet.contains(yesterday)) {
      anchorDay = yesterday;
    } else {
      anchorDay = null;
    }

    var currentStreak = 0;
    if (anchorDay != null) {
      var cursor = anchorDay;
      while (daySet.contains(cursor)) {
        currentStreak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    final state = _resolveState(
      currentStreak: currentStreak,
      hasAnyCompletions: sortedDays.isNotEmpty,
      createdDay: createdDay,
      today: today,
    );

    final wasColdBeforeCurrentRun = _detectPriorColdGap(
      currentStreak: currentStreak,
      anchorDay: anchorDay,
      sortedDays: sortedDays,
      createdDay: createdDay,
    );

    return StreakStats(
      state: state,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalCompletedDays: sortedDays.length,
      isCheckedToday: isCheckedToday,
      wasColdBeforeCurrentRun: wasColdBeforeCurrentRun,
    );
  }

  static int _calculateBestStreak(List<DateTime> sortedDays) {
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final day in sortedDays) {
      if (prev != null && day.difference(prev).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      best = max(best, run);
      prev = day;
    }
    return best;
  }

  static StreakState _resolveState({
    required int currentStreak,
    required bool hasAnyCompletions,
    required DateTime createdDay,
    required DateTime today,
  }) {
    if (currentStreak >= 7) return StreakState.blazing;
    if (currentStreak >= 3) return StreakState.hotFire;
    if (currentStreak >= 1) return StreakState.spark;
    if (!hasAnyCompletions && !createdDay.isBefore(today)) {
      return StreakState.ready;
    }
    return StreakState.cold;
  }

  static bool _detectPriorColdGap({
    required int currentStreak,
    required DateTime? anchorDay,
    required List<DateTime> sortedDays,
    required DateTime createdDay,
  }) {
    if (currentStreak == 0 || anchorDay == null) return false;
    final runStart = anchorDay.subtract(Duration(days: currentStreak - 1));
    final hasEarlierLogWithGap = sortedDays.any((day) => day.isBefore(runStart));
    final missedAfterCreation = runStart.difference(createdDay).inDays >= 2;
    return hasEarlierLogWithGap || missedAfterCreation;
  }
}
