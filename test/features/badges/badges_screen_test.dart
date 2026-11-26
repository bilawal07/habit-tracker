import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/core/constants/badge_definitions.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/data/repositories/task_repository.dart';
import 'package:habit_tracker/features/badges/badges_screen.dart';
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
    tempDir = await Directory.systemTemp.createTemp('habit_badges_test_');
    dbHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: p.join(tempDir.path, 'badges_habits.db'),
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

  testWidgets('Home Badges button opens BadgesScreen with per-task filtering', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await prefs.setBool('has_seeded_initial_task_v1', true);
      final t1 = await repository.createTask(title: 'Speak English');
      await repository.createTask(title: 'Read 10 Pages');
      await repository.unlockBadge(
        t1.id!,
        BadgeKey.firstSpark,
        unlockedAt: DateTime(2026, 11, 26),
      );
    });

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

    await tester.tap(find.byTooltip('Badges'));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('1 of 5 Badges Unlocked'));

    expect(find.byType(BadgesScreen), findsOneWidget);
    expect(find.text('1 of 5 Badges Unlocked'), findsOneWidget);
    expect(find.text('First Spark'), findsOneWidget);
    expect(find.text('3-Day Flame'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('30-Day Unstoppable'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('30-Day Unstoppable'), findsOneWidget);

    // Filter to Read 10 Pages (0 badges unlocked).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Read 10 Pages'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 5 Badges Unlocked'), findsOneWidget);

    // Filter to Speak English (1 badge unlocked with date).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Speak English'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 Badges Unlocked'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('First Spark'),
      -120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Unlocked on Nov 26, 2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Check-in shows Badge Unlocked popup celebration on first spark', (
    tester,
  ) async {
    final fixedNow = DateTime(2026, 11, 26, 19, 0);
    late int taskId;

    await tester.runAsync(() async {
      await prefs.setBool('has_seeded_initial_task_v1', true);
      final task = await repository.createTask(
        title: 'Speak English',
        createdAt: fixedNow,
      );
      taskId = task.id!;
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
    await _pumpUntilFound(tester, find.text('Mark today complete'));

    await tester.tap(find.text('Mark today complete'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Badge Unlocked!'));

    expect(find.text('Badge Unlocked!'), findsOneWidget);
    expect(find.text('First Spark'), findsOneWidget);

    await tester.tap(find.text('Keep Going'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    late int unlockedCount;
    await tester.runAsync(() async {
      unlockedCount = (await repository.getBadgesForTask(taskId)).length;
    });
    expect(unlockedCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
