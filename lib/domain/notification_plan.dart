import '../core/constants/reminder_slots.dart';
import '../core/utils/date_utils.dart';
import '../data/models/habit_task.dart';

/// Parsed action payload carried by a scheduled habit notification.
class NotificationActionPayload {
  const NotificationActionPayload({
    required this.dateKey,
    required this.taskIds,
  });

  final String dateKey;
  final List<int> taskIds;
}

/// Pure-Dart specification for a single scheduled notification instance.
class ScheduledReminderItem {
  const ScheduledReminderItem({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
    required this.slotIndex,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
  final int slotIndex;
}

/// Pure-Dart planner for bundled/unbundled 7-day rolling reminder schedules.
abstract final class NotificationPlanner {
  static const int rollingHorizonDays = 7;

  /// Deterministic 32-bit safe notification ID for bundled daily slots:
  /// `YYYYMMDD * 10 + slotIndex` (e.g. `202611260`..`202611263`).
  static int bundledNotificationId(DateTime date, int slotIndex) {
    final yyyymmdd = date.year * 10000 + date.month * 100 + date.day;
    return yyyymmdd * 10 + slotIndex;
  }

  /// Deterministic 32-bit safe notification ID for unbundled per-task slots.
  static int unbundledNotificationId(DateTime date, int taskId, int slotIndex) {
    final mmdd = date.month * 100 + date.day;
    return mmdd * 100000 + (taskId % 10000) * 10 + slotIndex;
  }

  /// Returns all 4 bundled notification IDs for [date] (used for today cancellation).
  static List<int> bundledIdsForDate(DateTime date) {
    return [
      for (final slot in kStrictReminderSlots)
        bundledNotificationId(date, slot.index),
    ];
  }

  /// Encodes `mark_done:<YYYY-MM-DD>:<comma-separated task IDs>`.
  static String encodePayload(String dateKey, List<int> taskIds) {
    return 'mark_done:$dateKey:${taskIds.join(',')}';
  }

  /// Parses payloads created by [encodePayload].
  static NotificationActionPayload? parsePayload(String? raw) {
    if (raw == null || !raw.startsWith('mark_done:')) return null;
    final parts = raw.split(':');
    if (parts.length != 3) return null;
    final dateKey = parts[1];
    final ids = parts[2]
        .split(',')
        .map((segment) => int.tryParse(segment.trim()))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return null;
    return NotificationActionPayload(dateKey: dateKey, taskIds: ids);
  }

  /// Builds the rolling 7-day notification schedule from [now].
  static List<ScheduledReminderItem> buildPlan({
    required List<HabitTask> tasks,
    required Set<int> checkedTodayTaskIds,
    required bool bundleNotifications,
    DateTime? now,
    int horizonDays = rollingHorizonDays,
  }) {
    final reference = now ?? DateTime.now();
    final activeTasks = tasks
        .where(
          (task) =>
              !task.isArchived &&
              task.id != null &&
              task.reminderMode != ReminderMode.off,
        )
        .toList();

    if (activeTasks.isEmpty) return const [];

    final items = <ScheduledReminderItem>[];
    for (var dayOffset = 0; dayOffset < horizonDays; dayOffset++) {
      final date = DateTime(
        reference.year,
        reference.month,
        reference.day + dayOffset,
      );
      final dateKey = AppDateUtils.toDateKey(date);

      for (final slot in kStrictReminderSlots) {
        final scheduledAt = DateTime(
          date.year,
          date.month,
          date.day,
          slot.hour,
          slot.minute,
        );
        if (!scheduledAt.isAfter(reference)) {
          continue;
        }

        final eligibleTasks = activeTasks.where((task) {
          if (dayOffset == 0 && checkedTodayTaskIds.contains(task.id)) {
            return false;
          }
          return _slotsForMode(task.reminderMode).any((s) => s.index == slot.index);
        }).toList();

        if (eligibleTasks.isEmpty) {
          continue;
        }

        if (bundleNotifications) {
          items.add(
            ScheduledReminderItem(
              id: bundledNotificationId(date, slot.index),
              scheduledAt: scheduledAt,
              title: _bundledTitle(slot, eligibleTasks.length),
              body: _bundledBody(eligibleTasks, isToday: dayOffset == 0),
              payload: encodePayload(
                dateKey,
                eligibleTasks.map((t) => t.id!).toList(),
              ),
              slotIndex: slot.index,
            ),
          );
        } else {
          for (final task in eligibleTasks) {
            items.add(
              ScheduledReminderItem(
                id: unbundledNotificationId(date, task.id!, slot.index),
                scheduledAt: scheduledAt,
                title: 'HotFire Habits · ${slot.label}',
                body: dayOffset == 0
                    ? '"${task.title}" is still Cold today — check it off!'
                    : 'Time for "${task.title}"! Keep your streak burning.',
                payload: encodePayload(dateKey, [task.id!]),
                slotIndex: slot.index,
              ),
            );
          }
        }
      }
    }

    return items;
  }

  static List<ReminderSlot> _slotsForMode(ReminderMode mode) {
    return switch (mode) {
      ReminderMode.strict => kStrictReminderSlots,
      ReminderMode.standard => kStandardReminderSlots,
      ReminderMode.off => const [],
    };
  }

  static String _bundledTitle(ReminderSlot slot, int count) {
    if (slot.index == 3) {
      return 'Final Night Check (${slot.label})';
    }
    return count == 1
        ? 'Habit Reminder · ${slot.label}'
        : '$count Habits Still Pending · ${slot.label}';
  }

  static String _bundledBody(List<HabitTask> tasks, {required bool isToday}) {
    final preview = tasks.take(3).map((t) => t.title).join(', ');
    final overflow = tasks.length > 3 ? ' +${tasks.length - 3} more' : '';
    if (!isToday) {
      return tasks.length == 1
          ? 'Keep "${tasks.first.title}" Hot Fire today.'
          : '${tasks.length} habits scheduled: $preview$overflow';
    }
    return tasks.length == 1
        ? '1 habit still Cold today: ${tasks.first.title}'
        : '${tasks.length} habits still Cold today: $preview$overflow';
  }
}
