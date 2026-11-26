import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/habit_task.dart';

/// Menu actions available on a [HabitTaskCard].
enum TaskCardAction { edit, archive, delete }

/// Card displaying a daily habit, its Fire/Ready state, streak count, and today status.
class HabitTaskCard extends StatelessWidget {
  const HabitTaskCard({
    super.key,
    required this.task,
    required this.isDoneToday,
    this.streakDays = 0,
    required this.onTap,
    required this.onActionSelected,
  });

  final HabitTask task;
  final bool isDoneToday;
  final int streakDays;
  final VoidCallback onTap;
  final ValueChanged<TaskCardAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<HabitPalette>()!;

    final statusColor = isDoneToday ? palette.done : palette.fire;
    final statusBg = isDoneToday
        ? palette.done.withValues(alpha: 0.12)
        : palette.fireContainer;
    final statusLabel = isDoneToday
        ? 'Done'
        : (streakDays > 0 ? 'Pending' : 'Ready');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // In Milestone 3, card tap will open the Monthly Calendar screen.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: statusBg,
                    child: Icon(
                      isDoneToday
                          ? Icons.check_rounded
                          : Icons.local_fire_department,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.reminderMode.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<TaskCardAction>(
                    tooltip: 'Task options',
                    onSelected: onActionSelected,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: TaskCardAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: TaskCardAction.archive,
                        child: ListTile(
                          leading: Icon(Icons.archive_outlined),
                          title: Text('Archive'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskCardAction.delete,
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatusChip(
                    icon: isDoneToday
                        ? Icons.local_fire_department
                        : Icons.bolt_outlined,
                    label: '$streakDays ${streakDays == 1 ? 'day' : 'days'} streak',
                    foregroundColor:
                        streakDays >= 3 ? palette.fire : colorScheme.onSurfaceVariant,
                    backgroundColor: streakDays >= 3
                        ? palette.fireContainer
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ),
                  _StatusChip(
                    icon: isDoneToday
                        ? Icons.check_circle_outline
                        : Icons.schedule_outlined,
                    label: isDoneToday ? 'Today: Done' : 'Today: $statusLabel',
                    foregroundColor: statusColor,
                    backgroundColor: statusBg,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
