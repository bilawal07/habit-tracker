import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/data/local/database_helper.dart';
import 'package:habit_tracker/features/settings/settings_screen.dart';
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

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_settings_test_');
    dbHelper = DatabaseHelper(
      databaseFactory: databaseFactoryFfi,
      databasePathOverride: p.join(tempDir.path, 'settings_habits.db'),
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

  testWidgets('Settings toggles persist preferences and switch Dark Mode live', (
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

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Bundle Daily Reminders'), findsOneWidget);

    await tester.tap(find.text('Bundle Daily Reminders'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('bundle_notifications'), isFalse);

    await tester.tap(find.text('Night Owl Grace (until 1:00 AM)'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('night_owl_grace'), isTrue);

    await tester.scrollUntilVisible(
      find.text('Dark Mode'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('dark_mode'), isTrue);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.scrollUntilVisible(
      find.text('Import Backup (.json)'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Import Backup (.json)'));
    await tester.pumpAndSettle();
    expect(find.text('Import Backup?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Privacy Policy'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
