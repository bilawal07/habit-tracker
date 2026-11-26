import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/data/repositories/task_repository.dart';
import 'package:habit_tracker/features/calendar/task_calendar_screen.dart';
import 'package:habit_tracker/providers/database_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late SharedPreferences prefs;
  late TaskRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_calendar_test_');
    dbHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: p.join(tempDir.path, 'calendar_habits.db'),
    );
    await dbHelper.database;
    repository = TaskRepository(dbHelper);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await dbHelper.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Tapping task card on Home opens Monthly Calendar screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseHelperProvider.overrideWithValue(dbHelper),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const HabitTrackerApp(),
      ),
    );
    await _pumpUntilFound(tester, find.text('Speak English'));

    await tester.tap(find.text('Speak English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(TaskCalendarScreen), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('Best Streak'), findsOneWidget);
    expect(find.text('Total Days'), findsOneWidget);
    expect(find.byKey(const Key('calendar-today-cell')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Past/future days stay locked; checking today updates streak to Hot Fire', (
    tester,
  ) async {
    // Mid-month fixed date so Nov 14 (past) and Nov 17 (future) are visible in month view.
    final fixedNow = DateTime(2026, 11, 16, 19, 0);
    late int taskId;

    await tester.runAsync(() async {
      await prefs.setBool('has_seeded_initial_task_v1', true);
      final task = await repository.createTask(
        title: 'Speak English',
        createdAt: DateTime(2026, 11, 10),
      );
      taskId = task.id!;
      // Completed Nov 14 and Nov 15 -> 2-day Spark before today's check-in.
      await repository.checkInDate(taskId, date: DateTime(2026, 11, 14, 9));
      await repository.checkInDate(taskId, date: DateTime(2026, 11, 15, 9));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseHelperProvider.overrideWithValue(dbHelper),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TaskCalendarScreen(
            taskId: taskId,
            nowOverride: fixedNow,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('2 Day Streak'));

    expect(find.text('SPARK'), findsOneWidget);
    expect(find.text('2 Day Streak'), findsOneWidget);

    // Scroll the outer ListView vertically so the calendar grid is visible
    // without disturbing TableCalendar's horizontal PageView.
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tapping a past day (Nov 13) shows lock message and writes nothing.
    final pastCell = find.byKey(const Key('calendar-day-2026-11-13'));
    await tester.tap(pastCell);
    await tester.pump();
    expect(
      find.text('Past dates are locked to keep streaks honest.'),
      findsOneWidget,
    );

    // Tapping a future day (Nov 17) shows lock message and writes nothing.
    final futureCell = find.byKey(const Key('calendar-day-2026-11-17'));
    await tester.tap(futureCell);
    await tester.pump();
    expect(
      find.text('Future dates are locked until they arrive.'),
      findsOneWidget,
    );

    late int logsBeforeToday;
    await tester.runAsync(() async {
      logsBeforeToday = (await repository.getLogsForTask(taskId)).length;
    });
    expect(logsBeforeToday, 2);

    // Tapping Today's cell checks today in SQLite and promotes Spark -> Hot Fire (3d).
    final todayCell = find.byKey(const Key('calendar-today-cell'));
    await tester.tap(todayCell);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 280));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('HOT FIRE'));

    late int logsAfterToday;
    await tester.runAsync(() async {
      logsAfterToday = (await repository.getLogsForTask(taskId)).length;
    });
    expect(logsAfterToday, 3);

    expect(find.text('HOT FIRE'), findsOneWidget);
    expect(find.text('3 Day Streak'), findsOneWidget);
    expect(find.text('Completed for today!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
