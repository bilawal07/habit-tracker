import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/habit_task.dart';
import '../../../domain/streak_engine.dart';

/// Menu actions available on a [HabitTaskCard].
enum TaskCardAction { edit, archive, delete }

/// Card displaying a daily habit, its Hot Fire / Cold state, streak count, and today status.
class HabitTaskCard extends StatelessWidget {
  const HabitTaskCard({
    super.key,
    required this.task,
    required this.stats,
    required this.onTap,
    required this.onActionSelected,
  });

  final HabitTask task;
  final StreakStats stats;
  final VoidCallback onTap;
  final ValueChanged<TaskCardAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<HabitPalette>()!;

    final isDoneToday = stats.isCheckedToday;
    final isCold = stats.state == StreakState.cold;
    final stateColor = isCold ? palette.cold : palette.fire;
    final stateBg = isCold ? palette.coldContainer : palette.fireContainer;

    final avatarColor = isDoneToday ? palette.done : stateColor;
    final avatarBg =
        isDoneToday ? palette.done.withValues(alpha: 0.14) : stateBg;
    final avatarIcon = isDoneToday
        ? Icons.check_rounded
        : (isCold ? Icons.ac_unit : Icons.local_fire_department);

    final todayColor = isDoneToday ? palette.done : stateColor;
    final todayBg =
        isDoneToday ? palette.done.withValues(alpha: 0.12) : stateBg;
    final todayLabel = isDoneToday ? 'Today: Done' : 'Today: Pending';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                    backgroundColor: avatarBg,
                    child: Icon(avatarIcon, color: avatarColor),
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
                    icon: isCold
                        ? Icons.ac_unit
                        : Icons.local_fire_department,
                    label: stats.state.label,
                    foregroundColor: stateColor,
                    backgroundColor: stateBg,
                  ),
                  _StatusChip(
                    icon: Icons.bolt_outlined,
                    label:
                        '${stats.currentStreak} ${stats.currentStreak == 1 ? 'day' : 'days'} streak',
                    foregroundColor: stats.currentStreak >= 3
                        ? palette.fire
                        : colorScheme.onSurfaceVariant,
                    backgroundColor: stats.currentStreak >= 3
                        ? palette.fireContainer
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                  ),
                  _StatusChip(
                    icon: isDoneToday
                        ? Icons.check_circle_outline
                        : Icons.schedule_outlined,
                    label: todayLabel,
                    foregroundColor: todayColor,
                    backgroundColor: todayBg,
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
