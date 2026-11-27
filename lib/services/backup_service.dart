import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/date_utils.dart';
import '../domain/backup_codec.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_list_provider.dart';
import '../providers/task_streak_provider.dart';

/// Handles local `.json` backup export (share sheet) and import (file picker).
class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  /// Creates a `.json` backup file and opens the native share sheet.
  Future<BackupBundle> exportAndShare() async {
    final repo = _ref.read(taskRepositoryProvider);
    final settings = _ref.read(settingsProvider);
    final now = DateTime.now();
    final bundle = await repo.exportBackup(settings: settings, now: now);
    final jsonString = BackupCodec.encode(bundle);

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'hotfire_habits_backup_${AppDateUtils.toDateKey(now)}.json';
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsString(jsonString, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'HotFire Habits Backup (${AppDateUtils.toDateKey(now)})',
        text: 'Offline backup for HotFire Habits.',
      ),
    );
    return bundle;
  }

  /// Opens a file picker for a `.json` backup and restores it into SQLite.
  /// Returns `null` if the user cancelled file selection.
  Future<BackupBundle?> pickAndImport() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select HotFire Habits Backup (.json)',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final rawJson = utf8.decode(bytes);

    final bundle = BackupCodec.decode(rawJson);
    await restoreBundle(bundle);
    return bundle;
  }

  /// Restores [bundle] into SQLite and preferences, refreshing app state.
  Future<void> restoreBundle(BackupBundle bundle) async {
    final repo = _ref.read(taskRepositoryProvider);
    final prefs = _ref.read(sharedPreferencesProvider);

    await repo.restoreFromBackup(bundle);
    await prefs.setBool('has_seeded_initial_task_v1', true);

    final settingsNotifier = _ref.read(settingsProvider.notifier);
    await settingsNotifier
        .setBundleNotifications(bundle.settings.bundleNotifications);
    await settingsNotifier.setNightOwlGrace(bundle.settings.nightOwlGrace);
    await settingsNotifier.setDarkMode(bundle.settings.darkMode);

    _ref.invalidate(taskListProvider);
    _ref.invalidate(taskLogsMapProvider);
    _ref.invalidate(taskBadgesMapProvider);
    _ref.invalidate(todayCheckedTaskIdsProvider);
    await _ref.read(notificationSyncHelperProvider).resync();
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});
