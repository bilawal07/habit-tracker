import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_log.dart';
import '../data/models/habit_task.dart';
import '../domain/streak_engine.dart';
import 'database_provider.dart';
import 'task_list_provider.dart';

/// Holds SQLite completion logs grouped by task ID for live streak updates.
class TaskLogsNotifier extends AsyncNotifier<Map<int, List<DailyLog>>> {
  @override
  FutureOr<Map<int, List<DailyLog>>> build() async {
    ref.watch(taskListProvider);
    final repo = ref.read(taskRepositoryProvider);
    return repo.getAllLogsGroupedByTask();
  }

  /// Records today's check-in for [taskId] and refreshes streak state.
  Future<void> checkInToday(int taskId, {DateTime? now}) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.checkInDate(taskId, date: now ?? DateTime.now());
    state = AsyncData(await repo.getAllLogsGroupedByTask());
    ref.invalidate(todayCheckedTaskIdsProvider);
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
