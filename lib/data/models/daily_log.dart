/// Single completed day check-in stored in `daily_logs`.
class DailyLog {
  const DailyLog({
    this.id,
    required this.taskId,
    required this.logDate,
    required this.completedAt,
  });

  final int? id;
  final int taskId;

  /// Calendar date string in `YYYY-MM-DD` format.
  final String logDate;
  final DateTime completedAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'log_date': logDate,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  factory DailyLog.fromMap(Map<String, Object?> map) {
    return DailyLog(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      logDate: map['log_date'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }
}
