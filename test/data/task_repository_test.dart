import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/badge_definitions.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/data/models/habit_task.dart';
import 'package:habit_tracker/data/repositories/task_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseHelper dbHelper;
  late TaskRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_tracker_test_');
    dbPath = p.join(tempDir.path, 'test_habits.db');
    dbHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: dbPath,
    );
    repository = TaskRepository(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CRUD operations on tasks work and reject blank titles', () async {
    final created = await repository.createTask(
      title: '  Speak English  ',
      reminderMode: ReminderMode.strict,
    );
    expect(created.id, isNotNull);
    expect(created.title, 'Speak English');

    final fetched = await repository.getTasks();
    expect(fetched.length, 1);
    expect(fetched.first.reminderMode, ReminderMode.strict);

    await repository.updateTask(
      created.copyWith(
        title: 'Speak English 15 mins',
        reminderMode: ReminderMode.standard,
      ),
    );
    final updated = await repository.getTaskById(created.id!);
    expect(updated?.title, 'Speak English 15 mins');
    expect(updated?.reminderMode, ReminderMode.standard);

    await repository.archiveTask(created.id!);
    expect(await repository.getTasks(), isEmpty);
    expect((await repository.getTasks(includeArchived: true)).length, 1);

    await repository.deleteTask(created.id!);
    expect(await repository.getTasks(includeArchived: true), isEmpty);

    await expectLater(
      () => repository.createTask(title: '   '),
      throwsArgumentError,
    );
  });

  test('daily_logs and task_badges are idempotent and cascade on delete', () async {
    final task = await repository.createTask(title: 'Speak English');
    final taskId = task.id!;
    final day = DateTime(2026, 11, 26, 9, 30);

    await repository.checkInDate(taskId, date: day);
    await repository.checkInDate(taskId, date: day.add(const Duration(hours: 2)));

    final logs = await repository.getLogsForTask(taskId);
    expect(logs.length, 1);
    expect(logs.first.logDate, '2026-11-26');
    expect(await repository.isCheckedOnDate(taskId, day), isTrue);

    await repository.unlockBadge(taskId, BadgeKey.firstSpark);
    await repository.unlockBadge(taskId, BadgeKey.firstSpark);

    final badges = await repository.getBadgesForTask(taskId);
    expect(badges.length, 1);
    expect(badges.first.badgeKey, BadgeKey.firstSpark);

    // Deleting the parent task should cascade-delete logs and badges.
    await repository.deleteTask(taskId);
    expect(await repository.getLogsForTask(taskId), isEmpty);
    expect(await repository.getBadgesForTask(taskId), isEmpty);
  });

  test('SQLite data persists across closing and reopening database', () async {
    final task = await repository.createTask(title: 'Read 10 Pages');
    await repository.checkInDate(task.id!, date: DateTime(2026, 11, 26));
    await repository.unlockBadge(task.id!, BadgeKey.firstSpark);

    // Simulate app restart by closing and reopening a new helper on same file.
    await dbHelper.close();
    final reopenedHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: dbPath,
    );
    final reopenedRepo = TaskRepository(reopenedHelper);

    final tasks = await reopenedRepo.getTasks();
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Read 10 Pages');

    final logs = await reopenedRepo.getLogsForTask(tasks.first.id!);
    expect(logs.length, 1);

    final badges = await reopenedRepo.getBadgesForTask(tasks.first.id!);
    expect(badges.length, 1);

    await reopenedHelper.close();
  });

  test('seedInitialTaskIfNeeded seeds Speak English only once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await repository.seedInitialTaskIfNeeded(prefs);
    var tasks = await repository.getTasks();
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Speak English');

    // User deletes sample task; restarting should not re-create it.
    await repository.deleteTask(tasks.first.id!);
    await repository.seedInitialTaskIfNeeded(prefs);
    tasks = await repository.getTasks();
    expect(tasks, isEmpty);
  });
}
