# Moodle Reminder

Moodle Reminder is a privacy-friendly Flutter companion for Moodle deadlines. It reads Moodle's official private iCalendar (`.ics`) feed, keeps an offline deadline cache, refreshes it in the background, and schedules local reminders without asking for or storing a Moodle password.

## Highlights

- Secure Moodle calendar URL storage using the platform secure store.
- Automatic background sync every six hours when a network connection is available.
- Multiple reminder rules (3 days, 2 days, 1 day, 6 hours, 1 hour) plus a due-now notification.
- Stable reminder IDs based on Moodle event UIDs.
- Home dashboard with urgency, countdowns and last-sync status.
- Calendar agenda and course grouping.
- Mark deadlines completed locally to silence their reminders.
- English and Arabic UI with RTL support.
- System, light and dark themes.
- Offline cache and pull-to-refresh/manual sync.
- ICS support for `UID`, `DTSTART`, `DTEND`, `TZID`, `URL`, `LOCATION`, `STATUS`, `SEQUENCE`, `LAST-MODIFIED`, folded lines and escaped text.
- Unit tests for the ICS parser.

## Privacy and security

The app never asks for a Moodle username or password. Moodle's exported calendar URL contains a private access token, so it is treated like a secret and stored with `flutter_secure_storage` instead of plain preferences.

Deadline metadata is cached locally so the app remains useful offline. Disconnecting Moodle removes the secure URL, cached deadlines, sync timestamp and local completion state from the app.

## Getting the Moodle calendar URL

1. Open Moodle.
2. Open **Calendar**.
3. Choose **Export calendar**.
4. Generate and copy the calendar URL.
5. Paste it into Moodle Reminder and choose **Connect securely**.

## Architecture

```text
lib/
├── main.dart
├── app_controller.dart
├── models/
│   └── deadline.dart
├── screens/
│   └── home_shell.dart
└── services/
    ├── background_sync_service.dart
    ├── calendar_repository.dart
    ├── ics_parser.dart
    └── notification_service.dart
```

The repository owns network/cache/secure-storage access, the controller owns app state, services isolate parsing/background/notification concerns, and the UI only consumes controller state.

Compatibility export files remain at `lib/ics_parser.dart` and `lib/notification_service.dart` for code importing the original paths.

## Development

Current dependencies target modern Flutter. Use Flutter 3.38.1 or newer and Dart 3.10 or newer.

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

To build Android:

```bash
flutter build apk --release
```

## Android permissions

Moodle Reminder uses:

- `INTERNET` to download the calendar feed.
- `POST_NOTIFICATIONS` for Android notification permission.
- `SCHEDULE_EXACT_ALARM` for precise deadline alarms; the app requests user approval where Android requires it and falls back to inexact alarms if approval is denied.
- `RECEIVE_BOOT_COMPLETED` so scheduled reminders can be restored after reboot.

The app intentionally does not request `USE_EXACT_ALARM`; this avoids declaring the more restricted app-store permission when `SCHEDULE_EXACT_ALARM` plus user approval is sufficient.

## Background behavior

Android WorkManager refreshes the feed approximately every six hours subject to operating-system scheduling, network availability and battery constraints. It is not an exact six-hour timer. After a successful refresh, the cached deadlines and notification schedule are updated.

## Testing

`test/ics_parser_test.dart` covers UTC parsing, folded iCalendar lines, date-only events, metadata and malformed-event handling. Run `flutter analyze` and `flutter test` before release builds.

## Author

**Mohammed Emad Elrefy**  
Al-Aqsa University — Department of Computer Science  
Software Engineering Project — Supervisor: Eng. Firas Fouad Al-ijla
