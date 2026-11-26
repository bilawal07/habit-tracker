import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/habit_task.dart';
import 'database_provider.dart';

/// Manages the active habit task list backed by local SQLite.
class TaskListNotifier extends AsyncNotifier<List<HabitTask>> {
  @override
  FutureOr<List<HabitTask>> build() async {
    final repo = ref.watch(taskRepositoryProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    await repo.seedInitialTaskIfNeeded(prefs);
    return repo.getTasks();
  }

  /// Adds a new habit task to SQLite and refreshes state.
  Future<void> addTask(
    String title, {
    ReminderMode reminderMode = ReminderMode.strict,
  }) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.createTask(title: title, reminderMode: reminderMode);
    state = AsyncData(await repo.getTasks());
  }

  /// Deletes a task from SQLite and refreshes state.
  Future<void> deleteTask(int taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.deleteTask(taskId);
    state = AsyncData(await repo.getTasks());
  }
}

final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, List<HabitTask>>(
  TaskListNotifier.new,
);
