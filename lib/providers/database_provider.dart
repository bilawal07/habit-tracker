import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/database_helper.dart';
import '../data/repositories/task_repository.dart';

/// Provides the singleton SQLite database helper.
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  final helper = DatabaseHelper();
  ref.onDispose(helper.close);
  return helper;
});

/// Provides pre-initialized [SharedPreferences] overridden at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

/// Provides the offline SQLite repository for tasks, logs, and badges.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(databaseHelperProvider));
});
