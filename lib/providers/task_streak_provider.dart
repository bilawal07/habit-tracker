import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/badge_definitions.dart';
import '../core/utils/date_utils.dart';
import '../data/models/daily_log.dart';
import '../data/models/habit_task.dart';
import '../data/models/task_badge.dart';
import '../domain/badge_engine.dart';
import '../domain/streak_engine.dart';
import '../services/notification_service.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'task_list_provider.dart';

/// Default disabled in tests; overridden with active instance in `main.dart`.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(enabled: false);
});

/// Coordinates SQLite task/log state with [NotificationService].
class NotificationSyncHelper {
  NotificationSyncHelper(this._ref);

  final Ref _ref;

  Future<void> resync({DateTime? now}) async {
    final service = _ref.read(notificationServiceProvider);
    if (!service.enabled) return;

    final repo = _ref.read(taskRepositoryProvider);
    final settings = _ref.read(settingsProvider);
    final tasks = await repo.getTasks();
    final effectiveNow = AppDateUtils.effectiveHabitDate(
      now ?? DateTime.now(),
      nightOwlGrace: settings.nightOwlGrace,
    );
    final checkedToday = await repo.getCheckedTaskIdsForDate(effectiveNow);

    await service.syncSchedule(
      tasks: tasks,
      checkedTodayTaskIds: checkedToday,
      bundleNotifications: settings.bundleNotifications,
      now: now,
    );
  }
}

final notificationSyncHelperProvider = Provider<NotificationSyncHelper>((ref) {
  return NotificationSyncHelper(ref);
});

/// Result returned when checking in a habit for today.
class CheckInOutcome {
  const CheckInOutcome({
    required this.stats,
    required this.newlyUnlockedBadges,
  });

  final StreakStats stats;
  final List<BadgeKey> newlyUnlockedBadges;
}

/// Holds SQLite unlocked badges grouped by task ID.
class TaskBadgesNotifier extends AsyncNotifier<Map<int, List<TaskBadge>>> {
  @override
  FutureOr<Map<int, List<TaskBadge>>> build() async {
    ref.watch(taskListProvider);
    final repo = ref.read(taskRepositoryProvider);
    return repo.getAllBadgesGroupedByTask();
  }

  Future<void> reload() async {
    final repo = ref.read(taskRepositoryProvider);
    state = AsyncData(await repo.getAllBadgesGroupedByTask());
  }
}

final taskBadgesMapProvider =
    AsyncNotifierProvider<TaskBadgesNotifier, Map<int, List<TaskBadge>>>(
  TaskBadgesNotifier.new,
);

/// Returns unlocked badges for a specific [taskId].
final taskBadgesForTaskProvider =
    Provider.family<List<TaskBadge>, int>((ref, taskId) {
  final badgesMap = ref.watch(taskBadgesMapProvider).asData?.value;
  return badgesMap?[taskId] ?? const [];
});

/// Holds SQLite completion logs grouped by task ID for live streak updates.
class TaskLogsNotifier extends AsyncNotifier<Map<int, List<DailyLog>>> {
  @override
  FutureOr<Map<int, List<DailyLog>>> build() async {
    ref.watch(taskListProvider);
    final repo = ref.read(taskRepositoryProvider);
    return repo.getAllLogsGroupedByTask();
  }

  /// Records today's check-in for [taskId], evaluates badges, and refreshes state.
  Future<CheckInOutcome> checkInToday(int taskId, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final repo = ref.read(taskRepositoryProvider);
    await repo.checkInDate(taskId, date: timestamp);

    final task = await repo.getTaskById(taskId);
    final taskLogs = await repo.getLogsForTask(taskId);
    final createdAt = task?.createdAt ?? timestamp;
    final stats = StreakEngine.fromLogs(
      taskLogs,
      createdAt: createdAt,
      now: timestamp,
    );

    final earnedKeys = BadgeEngine.evaluateEarnedKeys(
      logs: taskLogs,
      createdAt: createdAt,
      now: timestamp,
    );
    final newlyUnlocked = await repo.unlockMissingBadges(
      taskId,
      earnedKeys,
      unlockedAt: timestamp,
    );

    state = AsyncData(await repo.getAllLogsGroupedByTask());
    await ref.read(taskBadgesMapProvider.notifier).reload();
    ref.invalidate(todayCheckedTaskIdsProvider);
    await ref.read(notificationSyncHelperProvider).resync();

    return CheckInOutcome(
      stats: stats,
      newlyUnlockedBadges: newlyUnlocked,
    );
  }
}

final taskLogsMapProvider =
    AsyncNotifierProvider<TaskLogsNotifier, Map<int, List<DailyLog>>>(
  TaskLogsNotifier.new,
);

/// Returns completion logs for a specific [taskId].
final taskLogsForTaskProvider =
    Provider.family<List<DailyLog>, int>((ref, taskId) {
  final logsMap = ref.watch(taskLogsMapProvider).asData?.value;
  return logsMap?[taskId] ?? const [];
});

/// Returns the active [HabitTask] for [taskId], or null if deleted/archived.
final taskByIdProvider = Provider.family<HabitTask?, int>((ref, taskId) {
  final tasks = ref.watch(taskListProvider).asData?.value ?? const [];
  for (final task in tasks) {
    if (task.id == taskId) return task;
  }
  return null;
});

/// Computes live [StreakStats] for [taskId] from SQLite logs.
final taskStreakProvider = Provider.family<StreakStats?, int>((ref, taskId) {
  final task = ref.watch(taskByIdProvider(taskId));
  if (task == null) return null;
  final logs = ref.watch(taskLogsForTaskProvider(taskId));
  return StreakEngine.fromLogs(logs, createdAt: task.createdAt);
});
