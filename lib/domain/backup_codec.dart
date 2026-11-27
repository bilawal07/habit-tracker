import 'dart:convert';

import '../core/constants/badge_definitions.dart';
import '../data/models/app_settings.dart';
import '../data/models/daily_log.dart';
import '../data/models/habit_task.dart';
import '../data/models/task_badge.dart';

/// Full offline snapshot of tasks, logs, badges, and user settings.
class BackupBundle {
  const BackupBundle({
    required this.schemaVersion,
    required this.exportedAt,
    required this.settings,
    required this.entries,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final AppSettings settings;
  final List<BackupTaskEntry> entries;

  int get totalLogs =>
      entries.fold(0, (sum, entry) => sum + entry.logs.length);

  int get totalBadges =>
      entries.fold(0, (sum, entry) => sum + entry.badges.length);
}

/// Single task with its associated completion logs and unlocked badges.
class BackupTaskEntry {
  const BackupTaskEntry({
    required this.task,
    required this.logs,
    required this.badges,
  });

  final HabitTask task;
  final List<DailyLog> logs;
  final List<TaskBadge> badges;
}

/// Encodes and validates JSON backups for local export/import.
abstract final class BackupCodec {
  static const int currentSchemaVersion = 1;

  static String encode(BackupBundle bundle) {
    final payload = <String, Object?>{
      'schemaVersion': bundle.schemaVersion,
      'exportedAt': bundle.exportedAt.toIso8601String(),
      'settings': {
        'bundleNotifications': bundle.settings.bundleNotifications,
        'nightOwlGrace': bundle.settings.nightOwlGrace,
        'darkMode': bundle.settings.darkMode,
      },
      'tasks': [
        for (final entry in bundle.entries)
          {
            'title': entry.task.title,
            'reminderMode': entry.task.reminderMode.storageValue,
            'createdAt': entry.task.createdAt.toIso8601String(),
            'isArchived': entry.task.isArchived,
            'logs': [
              for (final log in entry.logs)
                {
                  'logDate': log.logDate,
                  'completedAt': log.completedAt.toIso8601String(),
                },
            ],
            'badges': [
              for (final badge in entry.badges)
                {
                  'badgeKey': badge.badgeKey.storageKey,
                  'unlockedAt': badge.unlockedAt.toIso8601String(),
                },
            ],
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static BackupBundle decode(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON backup file: ${error.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be a JSON object.');
    }

    final version = decoded['schemaVersion'];
    if (version is! int || version != currentSchemaVersion) {
      throw FormatException('Unsupported backup schema version: $version');
    }

    final exportedAtRaw = decoded['exportedAt'];
    if (exportedAtRaw is! String) {
      throw const FormatException('Backup is missing exportedAt timestamp.');
    }
    final exportedAt = DateTime.parse(exportedAtRaw);

    final settingsMap = decoded['settings'];
    final settings = settingsMap is Map<String, dynamic>
        ? AppSettings(
            bundleNotifications:
                settingsMap['bundleNotifications'] as bool? ?? true,
            nightOwlGrace: settingsMap['nightOwlGrace'] as bool? ?? false,
            darkMode: settingsMap['darkMode'] as bool? ?? false,
          )
        : const AppSettings();

    final tasksRaw = decoded['tasks'];
    if (tasksRaw is! List) {
      throw const FormatException('Backup is missing tasks list.');
    }

    final entries = <BackupTaskEntry>[];
    for (final rawTask in tasksRaw) {
      if (rawTask is! Map<String, dynamic>) {
        throw const FormatException('Invalid task entry in backup.');
      }
      final title = (rawTask['title'] as String? ?? '').trim();
      if (title.isEmpty) {
        throw const FormatException('Backup contains a task with empty title.');
      }

      final task = HabitTask(
        title: title,
        reminderMode: ReminderMode.fromStorage(
          rawTask['reminderMode'] as String? ?? 'strict',
        ),
        createdAt: DateTime.parse(rawTask['createdAt'] as String),
        isArchived: rawTask['isArchived'] as bool? ?? false,
      );

      final rawLogs = rawTask['logs'] as List? ?? const [];
      final logs = <DailyLog>[
        for (final rawLog in rawLogs)
          if (rawLog is Map<String, dynamic>)
            DailyLog(
              taskId: 0,
              logDate: rawLog['logDate'] as String,
              completedAt: DateTime.parse(rawLog['completedAt'] as String),
            )
          else
            throw const FormatException('Invalid daily log entry in backup.'),
      ];

      final rawBadges = rawTask['badges'] as List? ?? const [];
      final badges = <TaskBadge>[
        for (final rawBadge in rawBadges)
          if (rawBadge is Map<String, dynamic>)
            TaskBadge(
              taskId: 0,
              badgeKey:
                  BadgeKey.fromStorageKey(rawBadge['badgeKey'] as String),
              unlockedAt: DateTime.parse(rawBadge['unlockedAt'] as String),
            )
          else
            throw const FormatException('Invalid badge entry in backup.'),
      ];

      entries.add(BackupTaskEntry(task: task, logs: logs, badges: badges));
    }

    return BackupBundle(
      schemaVersion: version,
      exportedAt: exportedAt,
      settings: settings,
      entries: entries,
    );
  }
}
