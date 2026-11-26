import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/providers/database_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('App launches without login and displays seeded SQLite task', (
    tester,
  ) async {
    late Directory tempDir;
    late DatabaseHelper dbHelper;
    late SharedPreferences prefs;

    // Run real file/SQLite FFI initialization outside fakeAsync.
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('habit_widget_test_');
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        databasePathOverride: p.join(tempDir.path, 'widget_habits.db'),
      );
      await dbHelper.database;
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
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

    // Poll boundedly until the async SQLite seed + query finishes.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Speak English').evaluate().isNotEmpty) {
        break;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    }

    expect(find.text('HotFire Habits'), findsOneWidget);
    expect(find.text('Speak English'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await dbHelper.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
