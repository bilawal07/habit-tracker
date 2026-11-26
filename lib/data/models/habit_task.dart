/// Per-task reminder intensity mode stored in SQLite.
enum ReminderMode {
  strict('strict', 'Strict Fire (6am, 1pm, 8pm, 11pm)'),
  standard('standard', 'Standard (6am, 8pm)'),
  off('off', 'Off');

  const ReminderMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ReminderMode fromStorage(String value) {
    return ReminderMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => ReminderMode.strict,
    );
  }
}

/// Persistent habit task stored in the `tasks` SQLite table.
class HabitTask {
  const HabitTask({
    this.id,
    required this.title,
    this.reminderMode = ReminderMode.strict,
    required this.createdAt,
    this.isArchived = false,
  });

  final int? id;
  final String title;
  final ReminderMode reminderMode;
  final DateTime createdAt;
  final bool isArchived;

  HabitTask copyWith({
    int? id,
    String? title,
    ReminderMode? reminderMode,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return HabitTask(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderMode: reminderMode ?? this.reminderMode,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'reminder_mode': reminderMode.storageValue,
      'created_at': createdAt.toIso8601String(),
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory HabitTask.fromMap(Map<String, Object?> map) {
    return HabitTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      reminderMode: ReminderMode.fromStorage(map['reminder_mode'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      isArchived: (map['is_archived'] as int) == 1,
    );
  }
}
