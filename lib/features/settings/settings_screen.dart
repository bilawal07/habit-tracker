import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_streak_provider.dart';
import '../../services/backup_service.dart';

/// App Settings screen for notifications, battery saver, Night Owl Grace, theme, and backup.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final notificationService = ref.read(notificationServiceProvider);
    final palette = Theme.of(context).extension<HabitPalette>() ?? HabitPalette.light;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _SectionTitle(title: 'Notifications & Alarms', theme: theme),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active, color: palette.fire),
                  title: const Text('Bundle Daily Reminders'),
                  subtitle: const Text(
                    'Combine unchecked habits into 1 alert at 6 AM, 1 PM, 8 PM & 11 PM',
                  ),
                  value: settings.bundleNotifications,
                  onChanged: (value) async {
                    await settingsNotifier.setBundleNotifications(value);
                    await ref.read(notificationSyncHelperProvider).resync();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.alarm_on_outlined, color: palette.fire),
                  title: const Text('Notification & Exact Alarm Access'),
                  subtitle: const Text(
                    'Grant Android permissions so reminders fire on time',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final granted = await notificationService
                        .requestNotificationAndExactAlarmPermissions();
                    await ref.read(notificationSyncHelperProvider).resync();
                    if (context.mounted) {
                      _showMessage(
                        context,
                        granted
                            ? 'Reminder permissions checked and schedule synced.'
                            : 'Enable notifications in Android Settings if alerts are blocked.',
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.battery_saver_outlined,
                    color: palette.cold,
                  ),
                  title: const Text('Disable Battery Optimization'),
                  subtitle: const Text(
                    'Prevents Xiaomi, Oppo, Vivo & Samsung from killing alarms',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    final exempted = await notificationService
                        .requestBatteryOptimizationExemption();
                    if (context.mounted && exempted) {
                      _showMessage(
                        context,
                        'Battery optimization exempted for HotFire Habits.',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Streak Timing', theme: theme),
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.nightlight_round, color: palette.cold),
              title: const Text('Night Owl Grace (until 1:00 AM)'),
              subtitle: const Text(
                'Check-ins between 12:00 AM and 12:59 AM count toward yesterday',
              ),
              value: settings.nightOwlGrace,
              onChanged: settingsNotifier.setNightOwlGrace,
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Appearance', theme: theme),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between light and dark Fire/Cold theme'),
              value: settings.darkMode,
              onChanged: settingsNotifier.setDarkMode,
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Local Backup (.json)', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Export Backup (.json)'),
                  subtitle: const Text('Save tasks, logs, and badges locally'),
                  onTap: () => _handleExport(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Import Backup (.json)'),
                  subtitle: const Text('Restore habits from a backup file'),
                  onTap: () => _handleImport(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'About', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('100% offline SQLite · Zero login · No ads'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacyDialog(context),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('App Version'),
                  subtitle: Text('1.0.0+1'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final bundle = await ref.read(backupServiceProvider).exportAndShare();
      if (context.mounted) {
        _showMessage(
          context,
          'Exported ${bundle.entries.length} habits and ${bundle.totalLogs} check-ins.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Export failed: $error');
      }
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Backup?'),
        content: const Text(
          'Restoring a backup replaces your current tasks, streak logs, and '
          'badges on this device with the contents of the selected .json file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Choose File'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final bundle = await ref.read(backupServiceProvider).pickAndImport();
      if (bundle == null || !context.mounted) return;
      _showMessage(
        context,
        'Restored ${bundle.entries.length} habits and ${bundle.totalLogs} check-ins.',
      );
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Import failed: $error');
      }
    }
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'HotFire Habits stores your tasks, daily check-ins, and badges '
          '100% locally in an on-device SQLite database. There is no account, '
          'no login, and no cloud server. You can export or delete your data '
          'at any time.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.theme,
  });

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
