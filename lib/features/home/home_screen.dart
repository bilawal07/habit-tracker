import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/habit_task.dart';
import '../../../providers/task_list_provider.dart';
import 'widgets/habit_task_card.dart';
import 'widgets/task_form_sheet.dart';

/// Main Home / Tasks screen launched immediately with zero login.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final checkedIdsAsync = ref.watch(todayCheckedTaskIdsProvider);
    final checkedToday = checkedIdsAsync.asData?.value ?? const <int>{};
    final palette = Theme.of(context).extension<HabitPalette>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final todayLabel = AppDateUtils.formatHeaderDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.fireContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: palette.fire,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HotFire Habits',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  todayLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Badges',
            onPressed: () => _showMessage(
              context,
              'Badges screen will unlock in Milestone 4.',
            ),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _showMessage(
              context,
              'Settings screen will unlock in Milestone 5.',
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 42, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load habits: $error',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return _EmptyHabitsState(
              palette: palette,
              onAddTap: () => _openCreateSheet(context, ref),
            );
          }

          final doneCount = tasks
              .where((t) => t.id != null && checkedToday.contains(t.id))
              .length;
          final pendingCount = tasks.length - doneCount;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: tasks.length + 1,
            separatorBuilder: (_, index) =>
                SizedBox(height: index == 0 ? 14 : 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _TodaySummaryBanner(
                  totalCount: tasks.length,
                  pendingCount: pendingCount,
                  palette: palette,
                );
              }

              final task = tasks[index - 1];
              final isDoneToday =
                  task.id != null && checkedToday.contains(task.id);

              return HabitTaskCard(
                task: task,
                isDoneToday: isDoneToday,
                onTap: () => _openEditSheet(context, ref, task),
                onActionSelected: (action) =>
                    _handleCardAction(context, ref, task, action),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final result = await showTaskFormSheet(context);
    if (result is TaskFormSave) {
      await ref.read(taskListProvider.notifier).addTask(
            result.title,
            reminderMode: result.reminderMode,
          );
      if (context.mounted) {
        _showMessage(context, 'Added "${result.title}".');
      }
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    HabitTask task,
  ) async {
    final result = await showTaskFormSheet(context, existingTask: task);
    if (result == null) return;

    final notifier = ref.read(taskListProvider.notifier);
    switch (result) {
      case TaskFormSave():
        await notifier.updateTask(
          task.copyWith(
            title: result.title,
            reminderMode: result.reminderMode,
          ),
        );
        if (context.mounted) {
          _showMessage(context, 'Updated "${result.title}".');
        }
      case TaskFormArchive():
        if (task.id != null) {
          await notifier.archiveTask(task.id!);
          if (context.mounted) {
            _showMessage(context, 'Archived "${task.title}".');
          }
        }
      case TaskFormDelete():
        if (task.id != null) {
          await notifier.deleteTask(task.id!);
          if (context.mounted) {
            _showMessage(context, 'Deleted "${task.title}".');
          }
        }
    }
  }

  Future<void> _handleCardAction(
    BuildContext context,
    WidgetRef ref,
    HabitTask task,
    TaskCardAction action,
  ) async {
    final notifier = ref.read(taskListProvider.notifier);
    switch (action) {
      case TaskCardAction.edit:
        await _openEditSheet(context, ref, task);
      case TaskCardAction.archive:
        if (task.id != null) {
          await notifier.archiveTask(task.id!);
          if (context.mounted) {
            _showMessage(context, 'Archived "${task.title}".');
          }
        }
      case TaskCardAction.delete:
        if (task.id == null) return;
        final confirmed = await confirmDeleteTaskDialog(
          context,
          taskTitle: task.title,
        );
        if (confirmed) {
          await notifier.deleteTask(task.id!);
          if (context.mounted) {
            _showMessage(context, 'Deleted "${task.title}".');
          }
        }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TodaySummaryBanner extends StatelessWidget {
  const _TodaySummaryBanner({
    required this.totalCount,
    required this.pendingCount,
    required this.palette,
  });

  final int totalCount;
  final int pendingCount;
  final HabitPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone = pendingCount == 0;
    final accent = allDone ? palette.done : palette.fire;
    final container = allDone
        ? palette.done.withValues(alpha: 0.12)
        : palette.fireContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            allDone ? Icons.verified_outlined : Icons.local_fire_department,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              allDone
                  ? 'All $totalCount ${totalCount == 1 ? 'habit' : 'habits'} checked off today!'
                  : '$pendingCount of $totalCount ${totalCount == 1 ? 'habit' : 'habits'} still pending today',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHabitsState extends StatelessWidget {
  const _EmptyHabitsState({
    required this.palette,
    required this.onAddTap,
  });

  final HabitPalette palette;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.coldContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.ac_unit, size: 48, color: palette.cold),
            ),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add one daily habit you want to keep Hot Fire — even 10 minutes a day builds momentum.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Habit'),
            ),
          ],
        ),
      ),
    );
  }
}
