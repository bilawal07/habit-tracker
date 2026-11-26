import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/badge_definitions.dart';
import 'package:habit_tracker/data/models/daily_log.dart';
import 'package:habit_tracker/domain/badge_engine.dart';
import 'package:habit_tracker/domain/streak_engine.dart';

List<DailyLog> _makeLogs(List<DateTime> dates) {
  return [
    for (final d in dates)
      DailyLog(
        taskId: 1,
        logDate:
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        completedAt: d,
      ),
  ];
}

void main() {
  test('unlocks First Spark on day 1 and 3-Day Flame on day 3 without comeback', () {
    final created = DateTime(2026, 11, 1);

    final day1 = BadgeEngine.evaluateEarnedKeys(
      logs: _makeLogs([DateTime(2026, 11, 1)]),
      createdAt: created,
      now: DateTime(2026, 11, 1, 20),
    );
    expect(day1, [BadgeKey.firstSpark]);

    final day3 = BadgeEngine.evaluateEarnedKeys(
      logs: _makeLogs([
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
      ]),
      createdAt: created,
      now: DateTime(2026, 11, 3, 20),
    );
    expect(day3, containsAll([BadgeKey.firstSpark, BadgeKey.flame3]));
    expect(day3, isNot(contains(BadgeKey.comebackPhoenix)));
  });

  test('unlocks Comeback Phoenix when turning a Cold streak back into Hot Fire', () {
    final created = DateTime(2026, 11, 1);
    final logs = _makeLogs([
      DateTime(2026, 11, 1),
      // Missed Nov 2 & 3 -> went Cold
      DateTime(2026, 11, 4),
      DateTime(2026, 11, 5),
      DateTime(2026, 11, 6),
    ]);

    final earned = BadgeEngine.evaluateEarnedKeys(
      logs: logs,
      createdAt: created,
      now: DateTime(2026, 11, 6, 20),
    );
    expect(
      earned,
      containsAll([
        BadgeKey.firstSpark,
        BadgeKey.flame3,
        BadgeKey.comebackPhoenix,
      ]),
    );
  });

  test('unlocks 7-Day Inferno and 30-Day Unstoppable at 7 and 30 days', () {
    final created = DateTime(2026, 10, 1);
    final sevenDays = _makeLogs([
      for (var i = 0; i < 7; i++) created.add(Duration(days: i)),
    ]);
    expect(
      BadgeEngine.evaluateEarnedKeys(
        logs: sevenDays,
        createdAt: created,
        now: DateTime(2026, 10, 7, 20),
      ),
      containsAll([BadgeKey.firstSpark, BadgeKey.flame3, BadgeKey.inferno7]),
    );

    final thirtyDays = _makeLogs([
      for (var i = 0; i < 30; i++) created.add(Duration(days: i)),
    ]);
    expect(
      BadgeEngine.evaluateEarnedKeys(
        logs: thirtyDays,
        createdAt: created,
        now: DateTime(2026, 10, 30, 20),
      ),
      containsAll([
        BadgeKey.firstSpark,
        BadgeKey.flame3,
        BadgeKey.inferno7,
        BadgeKey.unstoppable30,
      ]),
    );
  });

  test('buildProgressForTask computes accurate locked fractions and unlocked state', () {
    final stats = StreakEngine.calculate(
      completedDates: [DateTime(2026, 11, 25), DateTime(2026, 11, 26)],
      createdAt: DateTime(2026, 11, 25),
      now: DateTime(2026, 11, 26, 20),
    );

    final progress = BadgeEngine.buildProgressForTask(
      stats: stats,
      unlockedDates: {BadgeKey.firstSpark: DateTime(2026, 11, 25)},
    );

    expect(progress.length, 5);
    expect(progress[0].isUnlocked, isTrue);
    expect(progress[1].currentValue, 2);
    expect(progress[1].targetValue, 3);
    expect(progress[1].progressText, '2/3 day streak');
    expect(progress[3].progressText, '2/7 day streak');
  });
}
