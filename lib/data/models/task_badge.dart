import '../../core/constants/badge_definitions.dart';

/// Unlocked badge record stored in `task_badges`.
class TaskBadge {
  const TaskBadge({
    this.id,
    required this.taskId,
    required this.badgeKey,
    required this.unlockedAt,
  });

  final int? id;
  final int taskId;
  final BadgeKey badgeKey;
  final DateTime unlockedAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'badge_key': badgeKey.storageKey,
      'unlocked_at': unlockedAt.toIso8601String(),
    };
  }

  factory TaskBadge.fromMap(Map<String, Object?> map) {
    return TaskBadge(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      badgeKey: BadgeKey.fromStorageKey(map['badge_key'] as String),
      unlockedAt: DateTime.parse(map['unlocked_at'] as String),
    );
  }
}
