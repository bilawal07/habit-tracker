import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/badge_definitions.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/backup_codec.dart';
import '../local/database_helper.dart';
import '../models/app_settings.dart';
import '../models/daily_log.dart';
import '../models/habit_task.dart';
import '../models/task_badge.dart';

/// Repository for offline SQLite CRUD operations across tasks, logs, and badges.
class TaskRepository {
  TaskRepository(this._databaseHelper);

  static const String _seededPrefKey = 'has_seeded_initial_task_v1';

  final DatabaseHelper _databaseHelper;

  Future<Database> get _db => _databaseHelper.database;

  /// Seeds a sample "Speak English" task once on fresh install.
  Future<void> seedInitialTaskIfNeeded(SharedPreferences prefs) async {
    if (prefs.getBool(_seededPrefKey) ?? false) {
      return;
    }
    final existingTasks = await getTasks(includeArchived: true);
    if (existingTasks.isEmpty) {
      await createTask(
        title: 'Speak English',
        reminderMode: ReminderMode.strict,
      );
    }
    await prefs.setBool(_seededPrefKey, true);
  }

  Future<List<HabitTask>> getTasks({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: includeArchived ? null : 'is_archived = ?',
      whereArgs: includeArchived ? null : [0],
      orderBy: 'id ASC',
    );
    return rows.map(HabitTask.fromMap).toList();
  }

  Future<HabitTask?> getTaskById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HabitTask.fromMap(rows.first);
  }

  Future<HabitTask> createTask({
    required String title,
    ReminderMode reminderMode = ReminderMode.strict,
    DateTime? createdAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Task title cannot be empty');
    }

    final db = await _db;
    final task = HabitTask(
      title: trimmed,
      reminderMode: reminderMode,
      createdAt: createdAt ?? DateTime.now(),
    );
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<int> updateTask(HabitTask task) async {
    if (task.id == null) {
      throw ArgumentError('Cannot update a task without an id');
    }
    final trimmed = task.title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(task.title, 'title', 'Task title cannot be empty');
    }

    final db = await _db;
    return db.update(
      'tasks',
      task.copyWith(title: trimmed).toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> archiveTask(int taskId) async {
    final db = await _db;
    return db.update(
      'tasks',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<int> deleteTask(int taskId) async {
    final db = await _db;
    return db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Idempotently marks [date] (defaults to today) as completed for [taskId].
  Future<void> checkInDate(int taskId, {DateTime? date}) async {
    final timestamp = date ?? DateTime.now();
    final log = DailyLog(
      taskId: taskId,
      logDate: AppDateUtils.toDateKey(timestamp),
      completedAt: timestamp,
    );
    final db = await _db;
    await db.insert(
      'daily_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<DailyLog>> getLogsForTask(int taskId) async {
    final db = await _db;
    final rows = await db.query(
      'daily_logs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'log_date ASC',
    );
    return rows.map(DailyLog.fromMap).toList();
  }

  /// Returns all completion logs grouped by `task_id`, sorted ascending by date.
  Future<Map<int, List<DailyLog>>> getAllLogsGroupedByTask() async {
    final db = await _db;
    final rows = await db.query(
      'daily_logs',
      orderBy: 'task_id ASC, log_date ASC',
    );
    final grouped = <int, List<DailyLog>>{};
    for (final row in rows) {
      final log = DailyLog.fromMap(row);
      grouped.putIfAbsent(log.taskId, () => []).add(log);
    }
    return grouped;
  }

  Future<bool> isCheckedOnDate(int taskId, DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'daily_logs',
      columns: ['id'],
      where: 'task_id = ? AND log_date = ?',
      whereArgs: [taskId, AppDateUtils.toDateKey(date)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Returns all task IDs that have a completion log for [date].
  Future<Set<int>> getCheckedTaskIdsForDate(DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'daily_logs',
      columns: ['task_id'],
      where: 'log_date = ?',
      whereArgs: [AppDateUtils.toDateKey(date)],
    );
    return rows.map((row) => row['task_id'] as int).toSet();
  }

  /// Idempotently unlocks [badgeKey] for [taskId].
  Future<void> unlockBadge(
    int taskId,
    BadgeKey badgeKey, {
    DateTime? unlockedAt,
  }) async {
    final badge = TaskBadge(
      taskId: taskId,
      badgeKey: badgeKey,
      unlockedAt: unlockedAt ?? DateTime.now(),
    );
    final db = await _db;
    await db.insert(
      'task_badges',
      badge.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<TaskBadge>> getBadgesForTask(int taskId) async {
    final db = await _db;
    final rows = await db.query(
      'task_badges',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'unlocked_at ASC',
    );
    return rows.map(TaskBadge.fromMap).toList();
  }

  /// Returns all unlocked badges grouped by `task_id`.
  Future<Map<int, List<TaskBadge>>> getAllBadgesGroupedByTask() async {
    final db = await _db;
    final rows = await db.query(
      'task_badges',
      orderBy: 'task_id ASC, unlocked_at ASC',
    );
    final grouped = <int, List<TaskBadge>>{};
    for (final row in rows) {
      final badge = TaskBadge.fromMap(row);
      grouped.putIfAbsent(badge.taskId, () => []).add(badge);
    }
    return grouped;
  }

  /// Unlocks any [keys] not yet earned for [taskId] and returns newly unlocked keys.
  Future<List<BadgeKey>> unlockMissingBadges(
    int taskId,
    Iterable<BadgeKey> keys, {
    DateTime? unlockedAt,
  }) async {
    final existing = await getBadgesForTask(taskId);
    final existingKeys = existing.map((b) => b.badgeKey).toSet();
    final newlyUnlocked = <BadgeKey>[];
    final timestamp = unlockedAt ?? DateTime.now();

    for (final key in keys) {
      if (existingKeys.add(key)) {
        await unlockBadge(taskId, key, unlockedAt: timestamp);
        newlyUnlocked.add(key);
      }
    }
    return newlyUnlocked;
  }

  /// Exports all tasks (including archived), logs, badges, and settings into a [BackupBundle].
  Future<BackupBundle> exportBackup({
    required AppSettings settings,
    DateTime? now,
  }) async {
    final tasks = await getTasks(includeArchived: true);
    final logsMap = await getAllLogsGroupedByTask();
    final badgesMap = await getAllBadgesGroupedByTask();

    final entries = <BackupTaskEntry>[
      for (final task in tasks)
        if (task.id != null)
          BackupTaskEntry(
            task: task,
            logs: logsMap[task.id!] ?? const [],
            badges: badgesMap[task.id!] ?? const [],
          ),
    ];

    return BackupBundle(
      schemaVersion: BackupCodec.currentSchemaVersion,
      exportedAt: now ?? DateTime.now(),
      settings: settings,
      entries: entries,
    );
  }

  /// Atomically replaces local SQLite tasks/logs/badges with [bundle].
  Future<void> restoreFromBackup(BackupBundle bundle) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('task_badges');
      await txn.delete('daily_logs');
      await txn.delete('tasks');

      for (final entry in bundle.entries) {
        final map = entry.task.toMap()..remove('id');
        final newTaskId = await txn.insert('tasks', map);

        for (final log in entry.logs) {
          await txn.insert(
            'daily_logs',
            {
              'task_id': newTaskId,
              'log_date': log.logDate,
              'completed_at': log.completedAt.toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        for (final badge in entry.badges) {
          await txn.insert(
            'task_badges',
            {
              'task_id': newTaskId,
              'badge_key': badge.badgeKey.storageKey,
              'unlocked_at': badge.unlockedAt.toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }
}
