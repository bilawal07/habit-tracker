import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/habit_task.dart';
import '../../domain/streak_engine.dart';
import '../../providers/task_list_provider.dart';
import '../../providers/task_streak_provider.dart';
import '../home/widgets/task_form_sheet.dart';

/// Monthly calendar and Hot Fire / Cold streak screen for a single habit task.
class TaskCalendarScreen extends ConsumerStatefulWidget {
  const TaskCalendarScreen({
    super.key,
    required this.taskId,
    this.nowOverride,
  });

  final int taskId;

  /// Optional clock override for deterministic tests.
  final DateTime? nowOverride;

  @override
  ConsumerState<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

class _TaskCalendarScreenState extends ConsumerState<TaskCalendarScreen> {
  late DateTime _focusedDay;
  bool _isCheckingIn = false;

  DateTime get _referenceNow => widget.nowOverride ?? DateTime.now();

  DateTime get _todayUtc => AppDateUtils.normalizeUtcDate(_referenceNow);

  @override
  void initState() {
    super.initState();
    _focusedDay = _todayUtc;
  }

  Future<void> _handleCheckInToday(StreakStats stats) async {
    if (stats.isCheckedToday || _isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    try {
      await ref
          .read(taskLogsMapProvider.notifier)
          .checkInToday(widget.taskId, now: _referenceNow);
      if (mounted) {
        _showMessage(
          stats.state == StreakState.cold
              ? 'Spark ignited! Your habit is warming back up.'
              : 'Checked off for today! Keep the fire burning.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  void _handleLockedDayTap(DateTime cellUtc) {
    if (cellUtc.isAfter(_todayUtc)) {
      _showMessage('Future dates are locked until they arrive.');
    } else {
      _showMessage('Past dates are locked to keep streaks honest.');
    }
  }

  Future<void> _openEditSheet(HabitTask task) async {
    final result = await showTaskFormSheet(context, existingTask: task);
    if (result == null || !mounted) return;

    final notifier = ref.read(taskListProvider.notifier);
    switch (result) {
      case TaskFormSave():
        await notifier.updateTask(
          task.copyWith(
            title: result.title,
            reminderMode: result.reminderMode,
          ),
        );
        if (mounted) {
          _showMessage('Updated "${result.title}".');
        }
      case TaskFormArchive():
        await notifier.archiveTask(task.id!);
        if (mounted) {
          Navigator.of(context).pop();
        }
      case TaskFormDelete():
        await notifier.deleteTask(task.id!);
        if (mounted) {
          Navigator.of(context).pop();
        }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(taskByIdProvider(widget.taskId));
    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habit Calendar')),
        body: const Center(child: Text('This habit is no longer active.')),
      );
    }

    final logs = ref.watch(taskLogsForTaskProvider(widget.taskId));
    final stats = StreakEngine.fromLogs(
      logs,
      createdAt: task.createdAt,
      now: _referenceNow,
    );
    final completedDays = <DateTime>{
      for (final log in logs)
        AppDateUtils.normalizeUtcDate(AppDateUtils.fromDateKey(log.logDate)),
    };
    final createdDayUtc = AppDateUtils.normalizeUtcDate(task.createdAt);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<HabitPalette>() ?? HabitPalette.light;
    final firstDay = createdDayUtc.isBefore(DateTime.utc(2020, 1, 1))
        ? createdDayUtc
        : DateTime.utc(2020, 1, 1);
    final lastDay = DateTime.utc(_todayUtc.year + 1, 12, 31);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              task.reminderMode.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Habit',
            onPressed: () => _openEditSheet(task),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _StreakStatusBanner(stats: stats, palette: palette),
          const SizedBox(height: 14),
          _StreakStatsStrip(stats: stats, palette: palette),
          const SizedBox(height: 14),
          _TodayCheckInCard(
            today: _referenceNow,
            isCheckedToday: stats.isCheckedToday,
            isSubmitting: _isCheckingIn,
            palette: palette,
            onCheckIn: () => _handleCheckInToday(stats),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              child: Column(
                children: [
                  TableCalendar<void>(
                    firstDay: firstDay,
                    lastDay: lastDay,
                    focusedDay: _focusedDay,
                    currentDay: _todayUtc,
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    availableGestures: AvailableGestures.horizontalSwipe,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendStyle: theme.textTheme.labelSmall!.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPageChanged: (focused) {
                      setState(() => _focusedDay = focused);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      final selectedUtc =
                          AppDateUtils.normalizeUtcDate(selectedDay);
                      if (selectedUtc == _todayUtc) {
                        _handleCheckInToday(stats);
                      } else {
                        _handleLockedDayTap(selectedUtc);
                      }
                    },
                    calendarBuilders: CalendarBuilders(
                      todayBuilder: (context, day, focusedDay) =>
                          _buildDayCell(
                        context,
                        day: day,
                        isOutside: false,
                        completedDays: completedDays,
                        createdDayUtc: createdDayUtc,
                        palette: palette,
                        stats: stats,
                      ),
                      defaultBuilder: (context, day, focusedDay) =>
                          _buildDayCell(
                        context,
                        day: day,
                        isOutside: false,
                        completedDays: completedDays,
                        createdDayUtc: createdDayUtc,
                        palette: palette,
                        stats: stats,
                      ),
                      outsideBuilder: (context, day, focusedDay) =>
                          _buildDayCell(
                        context,
                        day: day,
                        isOutside: true,
                        completedDays: completedDays,
                        createdDayUtc: createdDayUtc,
                        palette: palette,
                        stats: stats,
                      ),
                      disabledBuilder: (context, day, focusedDay) =>
                          _buildDayCell(
                        context,
                        day: day,
                        isOutside: true,
                        completedDays: completedDays,
                        createdDayUtc: createdDayUtc,
                        palette: palette,
                        stats: stats,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _CalendarLegend(palette: palette),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context, {
    required DateTime day,
    required bool isOutside,
    required Set<DateTime> completedDays,
    required DateTime createdDayUtc,
    required HabitPalette palette,
    required StreakStats stats,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cellUtc = AppDateUtils.normalizeUtcDate(day);
    final isToday = cellUtc == _todayUtc;
    final isFuture = cellUtc.isAfter(_todayUtc);
    final isCompleted = completedDays.contains(cellUtc);
    final isMissedPast =
        !isToday && !isFuture && !isCompleted && !cellUtc.isBefore(createdDayUtc);

    Color backgroundColor = Colors.transparent;
    Color textColor = isOutside
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
        : colorScheme.onSurface;
    Border? border;
    IconData? statusIcon;
    Color? iconColor;

    if (isToday) {
      backgroundColor = isCompleted
          ? palette.done.withValues(alpha: 0.16)
          : palette.fireContainer;
      border = Border.all(
        color: isCompleted ? palette.done : palette.fire,
        width: 2,
      );
      textColor = colorScheme.onSurface;
      statusIcon =
          isCompleted ? Icons.check_box : Icons.check_box_outline_blank;
      iconColor = isCompleted ? palette.done : palette.fire;
    } else if (isCompleted) {
      backgroundColor = palette.fireContainer.withValues(
        alpha: isOutside ? 0.5 : 0.9,
      );
      statusIcon = Icons.local_fire_department;
      iconColor = palette.fire;
    } else if (isMissedPast) {
      backgroundColor = palette.coldContainer.withValues(
        alpha: isOutside ? 0.5 : 0.9,
      );
      statusIcon = Icons.ac_unit;
      iconColor = palette.cold;
      textColor = palette.cold;
    } else if (isFuture) {
      backgroundColor =
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
      textColor = palette.locked;
      statusIcon = Icons.lock_outline;
      iconColor = palette.locked;
    } else {
      textColor = palette.locked.withValues(alpha: 0.75);
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: isOutside
              ? Key('calendar-outside-${AppDateUtils.toDateKey(cellUtc)}')
              : (isToday
                  ? const Key('calendar-today-cell')
                  : Key('calendar-day-${AppDateUtils.toDateKey(cellUtc)}')),
          borderRadius: BorderRadius.circular(10),
          onTap: isToday
              ? () => _handleCheckInToday(stats)
              : () => _handleLockedDayTap(cellUtc),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: border,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (statusIcon != null) ...[
                  const SizedBox(height: 1),
                  Icon(statusIcon, size: 13, color: iconColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakStatusBanner extends StatelessWidget {
  const _StreakStatusBanner({
    required this.stats,
    required this.palette,
  });

  final StreakStats stats;
  final HabitPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHot = stats.state.isWarmOrHot;
    final accentColor = isHot ? palette.fire : palette.cold;
    final bgColor = isHot ? palette.fireContainer : palette.coldContainer;
    final lottiePath =
        isHot ? 'assets/lottie/hot_fire.json' : 'assets/lottie/cold_ice.json';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(stats.state),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Lottie.asset(
                lottiePath,
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  isHot ? Icons.local_fire_department : Icons.ac_unit,
                  size: 48,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stats.state.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stats.currentStreak} Day Streak',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats.state.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
}

class _StreakStatsStrip extends StatelessWidget {
  const _StreakStatsStrip({
    required this.stats,
    required this.palette,
  });

  final StreakStats stats;
  final HabitPalette palette;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Current Streak',
        value: '${stats.currentStreak}d',
        color: stats.state.isWarmOrHot ? palette.fire : palette.cold,
      ),
      (
        label: 'Best Streak',
        value: '${stats.bestStreak}d',
        color: palette.fire,
      ),
      (
        label: 'Total Days',
        value: '${stats.totalCompletedDays}',
        color: palette.done,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Text(
                      items[i].value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: items[i].color,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TodayCheckInCard extends StatelessWidget {
  const _TodayCheckInCard({
    required this.today,
    required this.isCheckedToday,
    required this.isSubmitting,
    required this.palette,
    required this.onCheckIn,
  });

  final DateTime today;
  final bool isCheckedToday;
  final bool isSubmitting;
  final HabitPalette palette;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isCheckedToday ? palette.done : palette.fire;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isCheckedToday || isSubmitting ? null : onCheckIn,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Checkbox(
                value: isCheckedToday,
                activeColor: palette.done,
                onChanged:
                    isCheckedToday || isSubmitting ? null : (_) => onCheckIn(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckedToday
                          ? 'Completed for today!'
                          : 'Mark today complete',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${AppDateUtils.formatHeaderDate(today)} · Only today is editable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isCheckedToday
                    ? Icons.verified_rounded
                    : Icons.local_fire_department,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.palette});

  final HabitPalette palette;

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.check_box_outlined, color: palette.fire, label: 'Today'),
      (icon: Icons.local_fire_department, color: palette.fire, label: 'Done'),
      (icon: Icons.ac_unit, color: palette.cold, label: 'Cold'),
      (icon: Icons.lock_outline, color: palette.locked, label: 'Locked'),
    ];

    return Wrap(
      alignment: WrapAlignment.spaceAround,
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 4),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
      ],
    );
  }
}
