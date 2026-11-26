import 'dart:math';

import '../core/constants/badge_definitions.dart';
import '../core/utils/date_utils.dart';
import '../data/models/daily_log.dart';
import 'streak_engine.dart';

/// Progress snapshot for a single badge on a task or overall summary.
class BadgeProgressInfo {
  const BadgeProgressInfo({
    required this.definition,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.currentValue,
    required this.targetValue,
    required this.progressText,
  });

  final BadgeDefinition definition;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int currentValue;
  final int targetValue;
  final String progressText;

  double get fraction =>
      targetValue <= 0 ? 0 : (currentValue / targetValue).clamp(0.0, 1.0);
}

/// Pure-Dart badge evaluator for the five Hot Fire / Cold milestone badges.
abstract final class BadgeEngine {
  /// Returns all [BadgeKey]s earned by [logs] given [createdAt] and [now].
  static List<BadgeKey> evaluateEarnedKeys({
    required List<DailyLog> logs,
    required DateTime createdAt,
    DateTime? now,
  }) {
    final stats = StreakEngine.fromLogs(
      logs,
      createdAt: createdAt,
      now: now,
    );
    final hasHistoricalComeback = _hasColdToHotComeback(
      logs: logs,
      createdAt: createdAt,
    );

    final earned = <BadgeKey>[];
    if (stats.totalCompletedDays >= 1) {
      earned.add(BadgeKey.firstSpark);
    }
    if (stats.bestStreak >= 3) {
      earned.add(BadgeKey.flame3);
    }
    if (hasHistoricalComeback ||
        (stats.currentStreak >= 3 && stats.wasColdBeforeCurrentRun)) {
      earned.add(BadgeKey.comebackPhoenix);
    }
    if (stats.bestStreak >= 7) {
      earned.add(BadgeKey.inferno7);
    }
    if (stats.bestStreak >= 30) {
      earned.add(BadgeKey.unstoppable30);
    }
    return earned;
  }

  /// Computes display progress for all 5 badges on a single task.
  static List<BadgeProgressInfo> buildProgressForTask({
    required StreakStats stats,
    required Map<BadgeKey, DateTime> unlockedDates,
  }) {
    return [
      for (final def in kBadgeDefinitions)
        _buildSingle(
          def: def,
          stats: stats,
          unlockedAt: unlockedDates[def.key],
        ),
    ];
  }

  static BadgeProgressInfo _buildSingle({
    required BadgeDefinition def,
    required StreakStats stats,
    required DateTime? unlockedAt,
  }) {
    final isUnlocked = unlockedAt != null;
    if (isUnlocked) {
      return BadgeProgressInfo(
        definition: def,
        isUnlocked: true,
        unlockedAt: unlockedAt,
        currentValue: def.targetDays,
        targetValue: def.targetDays,
        progressText: 'Unlocked',
      );
    }

    final int current;
    final String text;
    switch (def.key) {
      case BadgeKey.firstSpark:
        current = min(stats.totalCompletedDays, 1);
        text = '$current/1 day completed';
      case BadgeKey.flame3:
        current = min(stats.bestStreak, 3);
        text = '$current/3 day streak';
      case BadgeKey.comebackPhoenix:
        current = stats.wasColdBeforeCurrentRun
            ? min(stats.currentStreak, 3)
            : 0;
        text = stats.wasColdBeforeCurrentRun
            ? '$current/3 comeback days'
            : 'Reignite from Cold to 3 days';
      case BadgeKey.inferno7:
        current = min(stats.bestStreak, 7);
        text = '$current/7 day streak';
      case BadgeKey.unstoppable30:
        current = min(stats.bestStreak, 30);
        text = '$current/30 day streak';
    }

    return BadgeProgressInfo(
      definition: def,
      isUnlocked: false,
      unlockedAt: null,
      currentValue: current,
      targetValue: def.targetDays,
      progressText: text,
    );
  }

  static bool _hasColdToHotComeback({
    required List<DailyLog> logs,
    required DateTime createdAt,
  }) {
    if (logs.length < 3) return false;
    final createdDay = AppDateUtils.normalizeUtcDate(createdAt);
    final sortedDays = <DateTime>{
      for (final log in logs)
        AppDateUtils.normalizeUtcDate(AppDateUtils.fromDateKey(log.logDate)),
    }.toList()
      ..sort();

    if (sortedDays.isEmpty) return false;

    var sawColdGap = sortedDays.first.difference(createdDay).inDays >= 2;
    var run = 0;
    DateTime? prev;
    for (final day in sortedDays) {
      if (prev == null) {
        run = 1;
      } else {
        final diff = day.difference(prev).inDays;
        if (diff == 1) {
          run += 1;
        } else {
          sawColdGap = true;
          run = 1;
        }
      }
      if (sawColdGap && run >= 3) {
        return true;
      }
      prev = day;
    }
    return false;
  }
}
