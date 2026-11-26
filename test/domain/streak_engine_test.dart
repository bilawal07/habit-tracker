import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/models/daily_log.dart';
import 'package:habit_tracker/domain/streak_engine.dart';

void main() {
  final createdToday = DateTime(2026, 11, 26, 8, 0);

  test('new task created today with zero logs is Ready', () {
    final stats = StreakEngine.calculate(
      completedDates: const [],
      createdAt: createdToday,
      now: DateTime(2026, 11, 26, 22, 0),
    );

    expect(stats.state, StreakState.ready);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 0);
    expect(stats.totalCompletedDays, 0);
    expect(stats.isCheckedToday, isFalse);
  });

  test('task created yesterday with zero logs is Cold after midnight', () {
    final stats = StreakEngine.calculate(
      completedDates: const [],
      createdAt: DateTime(2026, 11, 25, 23, 55),
      now: DateTime(2026, 11, 26, 0, 2),
    );

    expect(stats.state, StreakState.cold);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 0);
  });

  test('1-2 consecutive days produce Spark state', () {
    final day1 = StreakEngine.calculate(
      completedDates: [DateTime(2026, 11, 25)],
      createdAt: DateTime(2026, 11, 25),
      now: DateTime(2026, 11, 25, 21, 0),
    );
    expect(day1.state, StreakState.spark);
    expect(day1.currentStreak, 1);
    expect(day1.isCheckedToday, isTrue);

    // Next day before checking in: yesterday still keeps 1-day spark alive.
    final nextDayPending = StreakEngine.calculate(
      completedDates: [DateTime(2026, 11, 25)],
      createdAt: DateTime(2026, 11, 25),
      now: DateTime(2026, 11, 26, 9, 0),
    );
    expect(nextDayPending.state, StreakState.spark);
    expect(nextDayPending.currentStreak, 1);
    expect(nextDayPending.isCheckedToday, isFalse);
  });

  test('missed 1 day turns streak Cold across midnight edge', () {
    final beforeMidnight = StreakEngine.calculate(
      completedDates: [
        DateTime(2026, 11, 22),
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 24),
      ],
      createdAt: DateTime(2026, 11, 22),
      now: DateTime(2026, 11, 25, 23, 58),
    );
    expect(beforeMidnight.state, StreakState.hotFire);
    expect(beforeMidnight.currentStreak, 3);

    // Missed Nov 25 -> at 12:02 AM on Nov 26, streak is Cold.
    final afterMidnight = StreakEngine.calculate(
      completedDates: [
        DateTime(2026, 11, 22),
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 24),
      ],
      createdAt: DateTime(2026, 11, 22),
      now: DateTime(2026, 11, 26, 0, 2),
    );
    expect(afterMidnight.state, StreakState.cold);
    expect(afterMidnight.currentStreak, 0);
    expect(afterMidnight.bestStreak, 3);
    expect(afterMidnight.totalCompletedDays, 3);
  });

  test('missed 3 days then comeback transitions Cold -> Spark -> Hot Fire', () {
    final logs = [
      DateTime(2026, 11, 18),
      DateTime(2026, 11, 19),
      DateTime(2026, 11, 20),
      // Missed Nov 21, 22, 23 (3 days)
      DateTime(2026, 11, 24),
    ];

    final reigniteDay1 = StreakEngine.calculate(
      completedDates: logs,
      createdAt: DateTime(2026, 11, 18),
      now: DateTime(2026, 11, 24, 18, 0),
    );
    expect(reigniteDay1.state, StreakState.spark);
    expect(reigniteDay1.currentStreak, 1);
    expect(reigniteDay1.bestStreak, 3);
    expect(reigniteDay1.wasColdBeforeCurrentRun, isTrue);

    final comebackHotFire = StreakEngine.calculate(
      completedDates: [
        ...logs,
        DateTime(2026, 11, 25),
        DateTime(2026, 11, 26),
      ],
      createdAt: DateTime(2026, 11, 18),
      now: DateTime(2026, 11, 26, 20, 0),
    );
    expect(comebackHotFire.state, StreakState.hotFire);
    expect(comebackHotFire.currentStreak, 3);
    expect(comebackHotFire.bestStreak, 3);
    expect(comebackHotFire.totalCompletedDays, 6);
    expect(comebackHotFire.wasColdBeforeCurrentRun, isTrue);
  });

  test('7+ consecutive days reaches Blazing tier and deduplicates same-day logs', () {
    final logs = List.generate(
      7,
      (i) => DailyLog(
        taskId: 1,
        logDate: '2026-11-${(20 + i).toString().padLeft(2, '0')}',
        completedAt: DateTime(2026, 11, 20 + i, 9),
      ),
    );

    final stats = StreakEngine.fromLogs(
      logs,
      createdAt: DateTime(2026, 11, 20),
      now: DateTime(2026, 11, 26, 19, 0),
    );

    expect(stats.state, StreakState.blazing);
    expect(stats.currentStreak, 7);
    expect(stats.bestStreak, 7);
    expect(stats.totalCompletedDays, 7);
  });
}
