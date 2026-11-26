import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/date_utils.dart';
import '../data/local/database_helper.dart';
import '../data/models/habit_task.dart';
import '../data/repositories/task_repository.dart';
import '../domain/badge_engine.dart';
import '../domain/notification_plan.dart';

/// Top-level background entry point for Android notification "Mark Done" actions.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.handleNotificationResponse(response);
}

/// Manages local escalating habit notifications, permissions, and "Mark Done" actions.
class NotificationService {
  NotificationService({this.enabled = true});

  static const String channelId = 'hotfire_daily_reminders';
  static const String channelName = 'Daily Habit Reminders';
  static const String channelDescription =
      'Escalating reminders at 6 AM, 1 PM, 8 PM, and 11 PM until checked today.';
  static const String markDoneActionId = 'mark_done';
  static const String _promptedPrefKey = 'has_requested_notification_perm_v1';

  final bool enabled;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  VoidCallback? _onDatabaseUpdated;

  /// Initializes timezone database and local notification plugin.
  Future<void> initialize({VoidCallback? onDatabaseUpdated}) async {
    _onDatabaseUpdated = onDatabaseUpdated;
    if (!enabled || _initialized) return;

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) async {
        await handleNotificationResponse(
          response,
          onDatabaseUpdated: _onDatabaseUpdated,
        );
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  /// Requests Android notification permission once when the user creates their first task.
  Future<void> requestPermissionsIfNeededOnce(SharedPreferences prefs) async {
    if (!enabled) return;
    if (prefs.getBool(_promptedPrefKey) ?? false) return;
    await prefs.setBool(_promptedPrefKey, true);
    await requestNotificationAndExactAlarmPermissions();
  }

  /// Requests notification & exact-alarm permissions on Android 12+/13+.
  Future<bool> requestNotificationAndExactAlarmPermissions() async {
    if (!enabled) return false;
    await initialize(onDatabaseUpdated: _onDatabaseUpdated);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    final notifGranted =
        await androidImpl.requestNotificationsPermission() ?? true;
    await androidImpl.requestExactAlarmsPermission();
    return notifGranted;
  }

  /// Prompts for battery optimization exemption (or opens app settings as fallback).
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!enabled) return false;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) return true;
      await openAppSettings();
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Rebuilds the 7-day rolling notification schedule, cancelling today's
  /// remaining slots whenever tasks are already checked off today.
  Future<void> syncSchedule({
    required List<HabitTask> tasks,
    required Set<int> checkedTodayTaskIds,
    required bool bundleNotifications,
    DateTime? now,
  }) async {
    if (!enabled) return;
    await initialize(onDatabaseUpdated: _onDatabaseUpdated);

    await _plugin.cancelAll();

    final plan = NotificationPlanner.buildPlan(
      tasks: tasks,
      checkedTodayTaskIds: checkedTodayTaskIds,
      bundleNotifications: bundleNotifications,
      now: now,
    );
    if (plan.isEmpty) return;

    final scheduleMode = await _resolveAndroidScheduleMode();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: const [
          AndroidNotificationAction(
            markDoneActionId,
            'Mark Done',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );

    for (final item in plan) {
      final tzDate = tz.TZDateTime.from(item.scheduledAt, tz.local);
      await _plugin.zonedSchedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: item.payload,
      );
    }
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final canScheduleExact =
          await androidImpl.canScheduleExactNotifications() ?? false;
      return canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Processes "Mark Done" notification actions in foreground or background isolate.
  static Future<void> handleNotificationResponse(
    NotificationResponse response, {
    VoidCallback? onDatabaseUpdated,
    DatabaseHelper? databaseHelper,
  }) async {
    if (response.actionId != markDoneActionId) return;
    final parsed = NotificationPlanner.parsePayload(response.payload);
    if (parsed == null) return;

    final helper = databaseHelper ?? DatabaseHelper();
    final shouldClose = databaseHelper == null;
    try {
      final repo = TaskRepository(helper);
      final targetDate = AppDateUtils.fromDateKey(parsed.dateKey);
      for (final taskId in parsed.taskIds) {
        await repo.checkInDate(taskId, date: targetDate);
        final task = await repo.getTaskById(taskId);
        if (task != null) {
          final logs = await repo.getLogsForTask(taskId);
          final earned = BadgeEngine.evaluateEarnedKeys(
            logs: logs,
            createdAt: task.createdAt,
            now: targetDate,
          );
          await repo.unlockMissingBadges(
            taskId,
            earned,
            unlockedAt: targetDate,
          );
        }
      }

      // Reschedule so today's remaining slots stay cancelled while tomorrow stays intact.
      final prefs = await SharedPreferences.getInstance();
      final bundle = prefs.getBool('bundle_notifications') ?? true;
      final activeTasks = await repo.getTasks();
      final checkedToday = await repo.getCheckedTaskIdsForDate(targetDate);
      final service = NotificationService();
      await service.syncSchedule(
        tasks: activeTasks,
        checkedTodayTaskIds: checkedToday,
        bundleNotifications: bundle,
      );
      onDatabaseUpdated?.call();
    } finally {
      if (shouldClose) {
        await helper.close();
      }
    }
  }
}
