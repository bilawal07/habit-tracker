import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/date_utils.dart';
import 'package:habit_tracker/data/models/habit_task.dart';
import 'package:habit_tracker/domain/notification_plan.dart';

void main() {
  final tasks = [
    HabitTask(
      id: 1,
      title: 'Speak English',
      reminderMode: ReminderMode.strict,
      createdAt: DateTime(2026, 11, 26),
    ),
    HabitTask(
      id: 2,
      title: 'Read 10 Pages',
      reminderMode: ReminderMode.standard,
      createdAt: DateTime(2026, 11, 26),
    ),
    HabitTask(
      id: 3,
      title: 'Meditate',
      reminderMode: ReminderMode.off,
      createdAt: DateTime(2026, 11, 26),
    ),
  ];

  test('bundled mode schedules remaining today slots and full tomorrow schedule', () {
    // 10:00 AM on Nov 26 -> 6am passed; remaining today are 1pm, 8pm, 11pm.
    final now = DateTime(2026, 11, 26, 10, 0);
    final plan = NotificationPlanner.buildPlan(
      tasks: tasks,
      checkedTodayTaskIds: const {},
      bundleNotifications: true,
      now: now,
      horizonDays: 2,
    );

    // Today: 1pm (strict only), 8pm (strict+standard), 11pm (strict only) -> 3 items
    // Tomorrow: 6am, 1pm, 8pm, 11pm -> 4 items
    expect(plan.length, 7);

    expect(plan[0].id, 202611261); // 2026-11-26 slot 1 (1pm)
    expect(plan[0].body, '1 habit still Cold today: Speak English');

    expect(plan[1].id, 202611262); // 2026-11-26 slot 2 (8pm)
    expect(plan[1].body, '2 habits still Cold today: Speak English, Read 10 Pages');

    expect(plan[2].id, 202611263); // 2026-11-26 slot 3 (11pm)
    expect(plan[3].id, 202611270); // 2026-11-27 slot 0 (6am)
  });

  test('checking all tasks today cancels today slots while keeping tomorrow', () {
    final now = DateTime(2026, 11, 26, 10, 0);
    final plan = NotificationPlanner.buildPlan(
      tasks: tasks,
      checkedTodayTaskIds: {1, 2},
      bundleNotifications: true,
      now: now,
      horizonDays: 2,
    );

    // Zero notifications remain for Nov 26; all 4 slots remain for Nov 27.
    expect(plan.every((item) => item.scheduledAt.day == 27), isTrue);
    expect(plan.length, 4);
  });

  test('unbundled mode creates individual task alerts and encodes payload cleanly', () {
    final now = DateTime(2026, 11, 26, 19, 0);
    final plan = NotificationPlanner.buildPlan(
      tasks: tasks,
      checkedTodayTaskIds: const {},
      bundleNotifications: false,
      now: now,
      horizonDays: 1,
    );

    // 8pm: task 1 + task 2; 11pm: task 1 only => 3 items.
    expect(plan.length, 3);
    final parsed = NotificationPlanner.parsePayload(plan.first.payload);
    expect(parsed, isNotNull);
    expect(parsed!.dateKey, '2026-11-26');
    expect(parsed.taskIds, [1]);
  });

  test('Night Owl Grace maps 12:30 AM to previous day only when enabled', () {
    final afterMidnight = DateTime(2026, 11, 27, 0, 30);

    final strictDay = AppDateUtils.effectiveHabitDate(
      afterMidnight,
      nightOwlGrace: false,
    );
    expect(AppDateUtils.toDateKey(strictDay), '2026-11-27');

    final graceDay = AppDateUtils.effectiveHabitDate(
      afterMidnight,
      nightOwlGrace: true,
    );
    expect(AppDateUtils.toDateKey(graceDay), '2026-11-26');
  });
}
