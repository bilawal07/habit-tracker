import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/services/analytics_service.dart';

void main() {
  test('AnalyticsService records anonymous habit lifecycle events', () async {
    final sink = LocalAnalyticsSink();
    final analytics = AnalyticsService(sink);

    await analytics.logAppOpen();
    await analytics.logTaskCreated('strict');
    await analytics.logHabitCheckedIn(
      streakState: 'hotFire',
      currentStreak: 3,
    );
    await analytics.logBadgeUnlocked('flame_3');
    await analytics.logBackupExported(2);
    await analytics.logBackupImported(2);

    expect(sink.recordedEvents.map((e) => e.name).toList(), [
      'app_open',
      'task_created',
      'habit_checked_in',
      'badge_unlocked',
      'backup_exported',
      'backup_imported',
    ]);
    expect(sink.recordedEvents[2].parameters['current_streak'], 3);
  });
}
