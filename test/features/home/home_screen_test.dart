import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/core/utils/date_utils.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/data/repositories/task_repository.dart';
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

Future<void> _pumpAsyncDbWork(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_home_test_');
    dbHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: p.join(tempDir.path, 'home_habits.db'),
    );
    await dbHelper.database;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await dbHelper.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> launchApp(WidgetTester tester) async {
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
  }

  testWidgets('Home displays today date header, action icons, and summary', (
    tester,
  ) async {
    await tester.runAsync(() => dbHelper.database);
    await launchApp(tester);

    expect(find.text('HotFire Habits'), findsOneWidget);
    expect(
      find.text(AppDateUtils.formatHeaderDate(DateTime.now())),
      findsOneWidget,
    );
    expect(find.byTooltip('Badges'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('1 of 1 habit still pending today'), findsOneWidget);
    expect(find.text('Today: Ready'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Add Task sheet validates empty title and creates new habit', (
    tester,
  ) async {
    await launchApp(tester);

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    expect(find.text('New Daily Habit'), findsOneWidget);

    // Submitting blank title triggers validation error and keeps sheet open.
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Task'));
    await tester.pump();
    expect(find.text('Please enter a habit title'), findsOneWidget);

    // Enter valid title and select Standard Mode.
    await tester.enterText(find.byType(TextFormField), 'Read 10 Pages');
    await tester.tap(find.text('Standard Mode'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Task'));
    await _pumpAsyncDbWork(tester);
    await _pumpUntilFound(tester, find.text('Read 10 Pages'));

    expect(find.text('Read 10 Pages'), findsOneWidget);
    expect(find.text('Standard (6am, 8pm)'), findsOneWidget);
    expect(find.text('2 of 2 habits still pending today'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Edit, archive, and delete update SQLite and empty state', (
    tester,
  ) async {
    await launchApp(tester);

    // Tap card to edit "Speak English".
    await tester.tap(find.text('Speak English'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Habit'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Speak English 15m');
    await tester.tap(find.text('Reminders Off'));
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await _pumpAsyncDbWork(tester);
    await _pumpUntilFound(tester, find.text('Speak English 15m'));

    expect(find.text('Speak English 15m'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);

    // Delete via edit sheet + confirmation dialog -> shows empty state.
    await tester.tap(find.text('Speak English 15m'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Habit?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _pumpAsyncDbWork(tester);
    await _pumpUntilFound(tester, find.text('No habits yet'));

    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('Add Your First Habit'), findsOneWidget);

    // Add one more and archive it -> hidden from Home, retained in SQLite.
    await tester.tap(find.text('Add Your First Habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Evening Walk');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Task'));
    await _pumpAsyncDbWork(tester);
    await _pumpUntilFound(tester, find.text('Evening Walk'));

    await tester.tap(find.text('Evening Walk'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Archive'));
    await tester.tap(find.text('Archive'));
    await _pumpAsyncDbWork(tester);
    await _pumpUntilFound(tester, find.text('No habits yet'));

    final repo = TaskRepository(dbHelper);
    late int archivedCount;
    await tester.runAsync(() async {
      archivedCount = (await repo.getTasks(includeArchived: true)).length;
    });
    expect(archivedCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
