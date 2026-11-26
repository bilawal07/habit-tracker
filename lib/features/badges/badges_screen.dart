import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/badge_definitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/daily_log.dart';
import '../../data/models/habit_task.dart';
import '../../data/models/task_badge.dart';
import '../../domain/badge_engine.dart';
import '../../domain/streak_engine.dart';
import '../../providers/task_list_provider.dart';
import '../../providers/task_streak_provider.dart';
import 'badge_visuals.dart';

/// Displays all 5 badges with locked/unlocked states, unlock dates, and task filters.
class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({
    super.key,
    this.initialTaskId,
  });

  final int? initialTaskId;

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  int? _selectedTaskId;

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.initialTaskId;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskListProvider).asData?.value ?? const <HabitTask>[];
    final logsMap =
        ref.watch(taskLogsMapProvider).asData?.value ?? const <int, List<DailyLog>>{};
    final badgesMap =
        ref.watch(taskBadgesMapProvider).asData?.value ?? const <int, List<TaskBadge>>{};

    final selectedStillExists =
        _selectedTaskId != null && tasks.any((t) => t.id == _selectedTaskId);
    final activeFilterTaskId = selectedStillExists ? _selectedTaskId : null;

    final entries = _buildDisplayEntries(
      tasks: tasks,
      logsMap: logsMap,
      badgesMap: badgesMap,
      selectedTaskId: activeFilterTaskId,
    );
    final unlockedCount = entries.where((e) => e.progress.isUnlocked).length;

    final theme = Theme.of(context);
    final palette = theme.extension<HabitPalette>() ?? HabitPalette.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges'),
      ),
      body: Column(
        children: [
          _SummaryHeader(
            unlockedCount: unlockedCount,
            totalCount: kBadgeDefinitions.length,
            isOverall: activeFilterTaskId == null,
            palette: palette,
          ),
          if (tasks.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All Tasks'),
                      selected: activeFilterTaskId == null,
                      onSelected: (_) => setState(() => _selectedTaskId = null),
                    ),
                  ),
                  for (final task in tasks)
                    if (task.id != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(task.title),
                          selected: activeFilterTaskId == task.id,
                          onSelected: (_) =>
                              setState(() => _selectedTaskId = task.id),
                        ),
                      ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _BadgeCard(
                entry: entries[index],
                palette: palette,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_BadgeDisplayEntry> _buildDisplayEntries({
    required List<HabitTask> tasks,
    required Map<int, List<DailyLog>> logsMap,
    required Map<int, List<TaskBadge>> badgesMap,
    required int? selectedTaskId,
  }) {
    if (selectedTaskId != null) {
      final task = tasks.firstWhere((t) => t.id == selectedTaskId);
      final stats = StreakEngine.fromLogs(
        logsMap[selectedTaskId] ?? const [],
        createdAt: task.createdAt,
      );
      final unlockedDates = <BadgeKey, DateTime>{
        for (final badge in badgesMap[selectedTaskId] ?? const <TaskBadge>[])
          badge.badgeKey: badge.unlockedAt,
      };
      final items = BadgeEngine.buildProgressForTask(
        stats: stats,
        unlockedDates: unlockedDates,
      );
      return [
        for (final item in items)
          _BadgeDisplayEntry(progress: item, earnedTaskNames: const []),
      ];
    }

    // Overall summary across all active tasks.
    final perTaskProgress = <int, List<BadgeProgressInfo>>{};
    final taskNamesById = <int, String>{};
    for (final task in tasks) {
      final id = task.id;
      if (id == null) continue;
      taskNamesById[id] = task.title;
      final stats = StreakEngine.fromLogs(
        logsMap[id] ?? const [],
        createdAt: task.createdAt,
      );
      final unlockedDates = <BadgeKey, DateTime>{
        for (final badge in badgesMap[id] ?? const <TaskBadge>[])
          badge.badgeKey: badge.unlockedAt,
      };
      perTaskProgress[id] = BadgeEngine.buildProgressForTask(
        stats: stats,
        unlockedDates: unlockedDates,
      );
    }

    return [
      for (var i = 0; i < kBadgeDefinitions.length; i++)
        _aggregateBadge(
          index: i,
          perTaskProgress: perTaskProgress,
          taskNamesById: taskNamesById,
        ),
    ];
  }

  _BadgeDisplayEntry _aggregateBadge({
    required int index,
    required Map<int, List<BadgeProgressInfo>> perTaskProgress,
    required Map<int, String> taskNamesById,
  }) {
    final def = kBadgeDefinitions[index];
    DateTime? earliestUnlock;
    final earnedNames = <String>[];
    BadgeProgressInfo? bestLocked;

    for (final entry in perTaskProgress.entries) {
      final info = entry.value[index];
      if (info.isUnlocked) {
        earnedNames.add(taskNamesById[entry.key]!);
        final unlockedAt = info.unlockedAt!;
        if (earliestUnlock == null || unlockedAt.isBefore(earliestUnlock)) {
          earliestUnlock = unlockedAt;
        }
      } else if (bestLocked == null || info.fraction > bestLocked.fraction) {
        bestLocked = info;
      }
    }

    if (earliestUnlock != null) {
      return _BadgeDisplayEntry(
        progress: BadgeProgressInfo(
          definition: def,
          isUnlocked: true,
          unlockedAt: earliestUnlock,
          currentValue: def.targetDays,
          targetValue: def.targetDays,
          progressText: 'Unlocked',
        ),
        earnedTaskNames: earnedNames,
      );
    }

    if (bestLocked != null) {
      return _BadgeDisplayEntry(
        progress: bestLocked,
        earnedTaskNames: const [],
      );
    }

    return _BadgeDisplayEntry(
      progress: BadgeProgressInfo(
        definition: def,
        isUnlocked: false,
        unlockedAt: null,
        currentValue: 0,
        targetValue: def.targetDays,
        progressText: 'Add a habit to start unlocking',
      ),
      earnedTaskNames: const [],
    );
  }
}

class _BadgeDisplayEntry {
  const _BadgeDisplayEntry({
    required this.progress,
    required this.earnedTaskNames,
  });

  final BadgeProgressInfo progress;
  final List<String> earnedTaskNames;
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.unlockedCount,
    required this.totalCount,
    required this.isOverall,
    required this.palette,
  });

  final int unlockedCount;
  final int totalCount;
  final bool isOverall;
  final HabitPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.fireContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: palette.fire.withValues(alpha: 0.16),
            child: Icon(Icons.emoji_events, color: palette.fire, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlockedCount of $totalCount Badges Unlocked',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOverall
                      ? 'Overall progress across your active habits'
                      : 'Progress for the selected habit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.entry,
    required this.palette,
  });

  final _BadgeDisplayEntry entry;
  final HabitPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = entry.progress;
    final def = info.definition;
    final visual = kBadgeVisuals[def.key]!;
    final isUnlocked = info.isUnlocked;

    final accentColor = isUnlocked ? visual.color : palette.locked;
    final iconBg = isUnlocked
        ? visual.color.withValues(alpha: 0.14)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: iconBg,
              child: Icon(
                isUnlocked ? visual.icon : Icons.lock_outline,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          def.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isUnlocked
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? palette.done.withValues(alpha: 0.14)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isUnlocked ? 'Unlocked' : 'Locked',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isUnlocked
                                ? palette.done
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    def.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: info.fraction,
                      minHeight: 7,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isUnlocked ? palette.done : palette.fire,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isUnlocked && info.unlockedAt != null
                        ? _buildUnlockedSubtitle(
                            info.unlockedAt!,
                            entry.earnedTaskNames,
                          )
                        : info.progressText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isUnlocked
                          ? palette.done
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildUnlockedSubtitle(DateTime unlockedAt, List<String> taskNames) {
    final dateText = AppDateUtils.formatShortDateWithYear(unlockedAt);
    if (taskNames.isEmpty) {
      return 'Unlocked on $dateText';
    }
    return 'Unlocked on $dateText · ${taskNames.join(', ')}';
  }
}
