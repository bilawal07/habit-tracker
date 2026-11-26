import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/habit_task.dart';

/// Result returned from [showTaskFormSheet].
sealed class TaskFormResult {
  const TaskFormResult();
}

/// User submitted valid task fields to create or update a habit.
class TaskFormSave extends TaskFormResult {
  const TaskFormSave({
    required this.title,
    required this.reminderMode,
  });

  final String title;
  final ReminderMode reminderMode;
}

/// User chose to archive an existing habit.
class TaskFormArchive extends TaskFormResult {
  const TaskFormArchive();
}

/// User confirmed permanent deletion of an existing habit.
class TaskFormDelete extends TaskFormResult {
  const TaskFormDelete();
}

/// Opens the Add / Edit Task modal bottom sheet.
Future<TaskFormResult?> showTaskFormSheet(
  BuildContext context, {
  HabitTask? existingTask,
}) {
  return showModalBottomSheet<TaskFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _TaskFormSheet(existingTask: existingTask),
  );
}

/// Shows a confirmation dialog before permanently deleting [taskTitle].
Future<bool> confirmDeleteTaskDialog(
  BuildContext context, {
  required String taskTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Habit?'),
      content: Text(
        'Deleting "$taskTitle" will permanently remove its streak history and '
        'badges from this device. Use Archive if you only want to pause it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({this.existingTask});

  final HabitTask? existingTask;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late ReminderMode _selectedMode;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingTask?.title ?? '',
    );
    _selectedMode = widget.existingTask?.reminderMode ?? ReminderMode.strict;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      TaskFormSave(
        title: _titleController.text.trim(),
        reminderMode: _selectedMode,
      ),
    );
  }

  Future<void> _handleDelete() async {
    final task = widget.existingTask;
    if (task == null) return;
    final confirmed = await confirmDeleteTaskDialog(
      context,
      taskTitle: task.title,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(const TaskFormDelete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = theme.extension<HabitPalette>()!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Habit' : 'New Daily Habit',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _isEditing
                  ? 'Update the habit title or daily reminder intensity.'
                  : 'Pick one daily habit to keep Hot Fire every day.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Habit title',
                hintText: 'e.g., Speak English',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.local_fire_department_outlined,
                  color: palette.fire,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a habit title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Reminder Intensity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...ReminderMode.values.map(
              (mode) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReminderModeOption(
                  mode: mode,
                  selected: _selectedMode == mode,
                  palette: palette,
                  onTap: () => setState(() => _selectedMode = mode),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(_isEditing ? Icons.check : Icons.add),
              label: Text(_isEditing ? 'Save Changes' : 'Add Task'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(const TaskFormArchive()),
                      icon: const Icon(Icons.archive_outlined, size: 18),
                      label: const Text('Archive'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderModeOption extends StatelessWidget {
  const _ReminderModeOption({
    required this.mode,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final ReminderMode mode;
  final bool selected;
  final HabitPalette palette;
  final VoidCallback onTap;

  static const Map<ReminderMode, ({String title, String subtitle, IconData icon})>
      _metadata = {
    ReminderMode.strict: (
      title: 'Strict Fire Mode',
      subtitle: '4 slots until checked: 6:00 AM, 1:00 PM, 8:00 PM, 11:00 PM',
      icon: Icons.local_fire_department,
    ),
    ReminderMode.standard: (
      title: 'Standard Mode',
      subtitle: '2 slots until checked: 6:00 AM, 8:00 PM',
      icon: Icons.notifications_active_outlined,
    ),
    ReminderMode.off: (
      title: 'Reminders Off',
      subtitle: 'No scheduled notifications for this habit',
      icon: Icons.notifications_off_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = _metadata[mode]!;
    final accentColor = mode == ReminderMode.strict
        ? palette.fire
        : (mode == ReminderMode.standard ? palette.cold : colorScheme.outline);

    return Material(
      color: selected
          ? accentColor.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accentColor
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(info.icon, color: accentColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? accentColor : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
