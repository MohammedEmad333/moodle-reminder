import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'ics_parser.dart';

/// Handles scheduling local notifications for deadlines.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    // Request permission (Android 13+ and iOS)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'deadlines',
      'Deadline Reminders',
      channelDescription: 'Reminders for upcoming Moodle deadlines',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Cancels all and reschedules notifications for the given deadlines.
  /// Fires [hoursBefore] hours ahead of each deadline.
  static Future<void> scheduleAll(
    List<Deadline> deadlines, {
    int hoursBefore = 24,
  }) async {
    await _plugin.cancelAll();
    int id = 0;
    for (final d in deadlines) {
      if (d.isPast) continue;
      final fireAt = d.due.subtract(Duration(hours: hoursBefore));
      // Only schedule if the reminder time is still in the future
      if (fireAt.isAfter(DateTime.now())) {
        await _scheduleOne(
          id++,
          'Due soon: ${d.title}',
          '${d.course.isNotEmpty ? "${d.course} • " : ""}Due ${formatDue(d.due)}',
          fireAt,
        );
      }
      // Also fire a "due now" reminder at the deadline itself
      if (d.due.isAfter(DateTime.now())) {
        await _scheduleOne(
          id++,
          'Deadline now: ${d.title}',
          'This is due now (${formatDue(d.due)})',
          d.due,
        );
      }
    }
  }

  static Future<void> _scheduleOne(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Fires an immediate test notification (used by the "Test" button).
  static Future<void> showTest() async {
    await _plugin.show(
      99999,
      'Notifications working ✅',
      'You will be reminded before each deadline.',
      _details,
    );
  }
}
