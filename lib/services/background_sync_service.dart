import 'package:workmanager/workmanager.dart';

import 'calendar_repository.dart';
import 'notification_service.dart';

const _backgroundTaskName = 'moodle-calendar-sync';
const _backgroundUniqueName = 'moodle-calendar-periodic-sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _backgroundTaskName) return true;

    try {
      final repository = CalendarRepository();
      await repository.migrateLegacyStorage();
      if (await repository.loadCalendarUrl() == null) return true;

      final deadlines = await repository.sync();
      final offsets = await repository.loadReminderOffsets();
      final completed = await repository.loadCompletedIds();
      await NotificationService.init(requestPermissions: false);
      await NotificationService.scheduleAll(
        deadlines,
        reminderOffsetsHours: offsets,
        completedIds: completed,
      );
      return true;
    } catch (_) {
      // WorkManager will try again on the next periodic run. Returning true
      // avoids an aggressive retry loop for invalid/expired Moodle tokens.
      return true;
    }
  });
}

class BackgroundSyncService {
  BackgroundSyncService._();

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _backgroundUniqueName,
      _backgroundTaskName,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
