import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/database_provider.dart';
import 'providers/task_list_provider.dart';
import 'providers/task_streak_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final notificationService = NotificationService();

  late final ProviderContainer container;
  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );

  await notificationService.initialize(
    onDatabaseUpdated: () {
      container.invalidate(taskListProvider);
      container.invalidate(taskLogsMapProvider);
      container.invalidate(taskBadgesMapProvider);
    },
  );

  // Refresh the rolling 7-day notification schedule on every app launch.
  await container.read(notificationSyncHelperProvider).resync();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HabitTrackerApp(),
    ),
  );
}
