import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Anonymous key-event tracker ready to forward to Firebase Analytics once
/// `google-services.json` is configured for Play Store release.
abstract interface class AnalyticsSink {
  Future<void> logEvent(String name, {Map<String, Object?> parameters = const {}});
}

/// Default in-memory / debug-only sink that collects zero PII.
class LocalAnalyticsSink implements AnalyticsSink {
  final List<({String name, Map<String, Object?> parameters})> recordedEvents =
      [];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    recordedEvents.add((name: name, parameters: Map.unmodifiable(parameters)));
    if (kDebugMode) {
      debugPrint('[Analytics] $name $parameters');
    }
  }
}

/// Centralized anonymous retention & habit-loop event logger.
class AnalyticsService {
  AnalyticsService(this._sink);

  final AnalyticsSink _sink;

  Future<void> logAppOpen() => _sink.logEvent('app_open');

  Future<void> logTaskCreated(String reminderMode) => _sink.logEvent(
        'task_created',
        parameters: {'reminder_mode': reminderMode},
      );

  Future<void> logHabitCheckedIn({
    required String streakState,
    required int currentStreak,
  }) =>
      _sink.logEvent(
        'habit_checked_in',
        parameters: {
          'streak_state': streakState,
          'current_streak': currentStreak,
        },
      );

  Future<void> logBadgeUnlocked(String badgeKey) => _sink.logEvent(
        'badge_unlocked',
        parameters: {'badge_key': badgeKey},
      );

  Future<void> logBackupExported(int taskCount) => _sink.logEvent(
        'backup_exported',
        parameters: {'task_count': taskCount},
      );

  Future<void> logBackupImported(int taskCount) => _sink.logEvent(
        'backup_imported',
        parameters: {'task_count': taskCount},
      );
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(LocalAnalyticsSink());
});
