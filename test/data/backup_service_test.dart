import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/badge_definitions.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/data/models/app_settings.dart';
import 'package:habit_tracker/data/models/habit_task.dart';
import 'package:habit_tracker/data/repositories/task_repository.dart';
import 'package:habit_tracker/domain/backup_codec.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late TaskRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_backup_test_');
    dbHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: p.join(tempDir.path, 'backup_habits.db'),
    );
    await dbHelper.database;
    repository = TaskRepository(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('BackupCodec and TaskRepository round-trip tasks, logs, badges, and settings', () async {
    final active = await repository.createTask(
      title: 'Speak English',
      reminderMode: ReminderMode.strict,
      createdAt: DateTime(2026, 11, 20),
    );
    final archived = await repository.createTask(
      title: 'Archived Habit',
      reminderMode: ReminderMode.standard,
      createdAt: DateTime(2026, 11, 18),
    );
    await repository.archiveTask(archived.id!);
    await repository.checkInDate(active.id!, date: DateTime(2026, 11, 25));
    await repository.checkInDate(active.id!, date: DateTime(2026, 11, 26));
    await repository.unlockBadge(
      active.id!,
      BadgeKey.firstSpark,
      unlockedAt: DateTime(2026, 11, 25),
    );

    const exportedSettings = AppSettings(
      bundleNotifications: false,
      nightOwlGrace: true,
      darkMode: true,
    );

    final bundle = await repository.exportBackup(
      settings: exportedSettings,
      now: DateTime(2026, 11, 26, 20),
    );
    final rawJson = BackupCodec.encode(bundle);

    // Wipe local database and replace with unrelated task before restoring.
    await repository.deleteTask(active.id!);
    await repository.deleteTask(archived.id!);
    await repository.createTask(title: 'Temporary Task');

    final decoded = BackupCodec.decode(rawJson);
    await repository.restoreFromBackup(decoded);

    final restoredActive = await repository.getTasks();
    final restoredAll = await repository.getTasks(includeArchived: true);
    expect(restoredActive.length, 1);
    expect(restoredActive.first.title, 'Speak English');
    expect(restoredAll.length, 2);
    expect(restoredAll.last.isArchived, isTrue);

    final restoredLogs = await repository.getLogsForTask(restoredActive.first.id!);
    expect(restoredLogs.length, 2);

    final restoredBadges =
        await repository.getBadgesForTask(restoredActive.first.id!);
    expect(restoredBadges.length, 1);
    expect(restoredBadges.first.badgeKey, BadgeKey.firstSpark);

    expect(decoded.settings.bundleNotifications, isFalse);
    expect(decoded.settings.nightOwlGrace, isTrue);
    expect(decoded.settings.darkMode, isTrue);
  });

  test('BackupCodec rejects malformed or unsupported backups cleanly', () {
    expect(() => BackupCodec.decode('not-json'), throwsFormatException);
    expect(
      () => BackupCodec.decode('{"schemaVersion": 99, "exportedAt": "2026-11-26", "tasks": []}'),
      throwsFormatException,
    );
    expect(
      () => BackupCodec.decode(
        '{"schemaVersion": 1, "exportedAt": "2026-11-26T00:00:00", "tasks": [{"title": "  ", "createdAt": "2026-11-26T00:00:00"}]}',
      ),
      throwsFormatException,
    );
  });
}
