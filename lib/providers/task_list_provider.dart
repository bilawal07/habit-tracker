import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/habit_task.dart';
import '../services/analytics_service.dart';
import 'database_provider.dart';
import 'task_streak_provider.dart';

/// Manages the active habit task list backed by local SQLite.
class TaskListNotifier extends AsyncNotifier<List<HabitTask>> {
  @override
  FutureOr<List<HabitTask>> build() async {
    final repo = ref.watch(taskRepositoryProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    await repo.seedInitialTaskIfNeeded(prefs);
    return repo.getTasks();
  }

  /// Adds a new habit task to SQLite, requests notification permission once,
  /// and refreshes state.
  Future<void> addTask(
    String title, {
    ReminderMode reminderMode = ReminderMode.strict,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    await repo.createTask(title: title, reminderMode: reminderMode);
    state = AsyncData(await repo.getTasks());
    await ref
        .read(notificationServiceProvider)
        .requestPermissionsIfNeededOnce(prefs);
    await ref.read(notificationSyncHelperProvider).resync();
    await ref
        .read(analyticsServiceProvider)
        .logTaskCreated(reminderMode.storageValue);
  }

  /// Updates an existing habit task in SQLite and refreshes state.
  Future<void> updateTask(HabitTask task) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.updateTask(task);
    state = AsyncData(await repo.getTasks());
    await ref.read(notificationSyncHelperProvider).resync();
  }

  /// Archives an existing habit task in SQLite and refreshes state.
  Future<void> archiveTask(int taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.archiveTask(taskId);
    state = AsyncData(await repo.getTasks());
    await ref.read(notificationSyncHelperProvider).resync();
  }

  /// Deletes a task from SQLite and refreshes state.
  Future<void> deleteTask(int taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.deleteTask(taskId);
    state = AsyncData(await repo.getTasks());
    await ref.read(notificationSyncHelperProvider).resync();
  }
}

final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, List<HabitTask>>(
  TaskListNotifier.new,
);

/// Task IDs completed today, refreshed whenever [taskListProvider] changes.
final todayCheckedTaskIdsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(taskListProvider);
  final repo = ref.read(taskRepositoryProvider);
  return repo.getCheckedTaskIdsForDate(DateTime.now());
});
