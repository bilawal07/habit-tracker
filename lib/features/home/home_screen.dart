import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/task_list_provider.dart';

/// Starter Home screen verifying SQLite + Riverpod + Fire/Cold Material 3 theme.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final palette = Theme.of(context).extension<HabitPalette>()!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: palette.fire),
            const SizedBox(width: 8),
            const Text('HotFire Habits'),
          ],
        ),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load habits: $error'),
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ac_unit, size: 48, color: palette.cold),
                    const SizedBox(height: 12),
                    Text('No habits yet', style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + Add Task to start your first streak.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: palette.fireContainer,
                    child: Icon(
                      Icons.local_fire_department,
                      color: palette.fire,
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(task.reminderMode.label),
                  trailing: const Icon(Icons.calendar_month_outlined),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Future<void> _showQuickAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Habit Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Speak English',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (title != null && title.trim().isNotEmpty) {
      await ref.read(taskListProvider.notifier).addTask(title);
    }
  }
}
