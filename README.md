# Moodle Reminder

A small Flutter app that reads your Moodle calendar (iCalendar `.ics` feed),
lists upcoming deadlines, and sends local notifications before each one.

## How it works

1. Moodle has a built-in **Export calendar** feature that gives a private
   `.ics` URL containing all your events and deadlines.
2. The app fetches that URL over HTTP (no login needed — the URL itself
   carries a private token).
3. It parses the iCalendar `VEVENT` blocks into a sorted deadline list.
4. It schedules a local notification a chosen number of hours before each
   deadline (and one at the deadline itself).

No passwords are stored — only the calendar URL and a cached copy of the
events (in `SharedPreferences`).

## Getting your Moodle calendar URL

In the Moodle web site:

1. Go to **Calendar**.
2. Click **Export calendar** (bottom of the page).
3. Choose **All events** and **Recent and upcoming events** (or a custom range).
4. Click **Get calendar URL**.
5. Copy the URL — it looks like:
   `https://moodle.<your-university>.edu.ps/calendar/export_execute.php?userid=123&authtoken=abc...&preset_what=all&preset_time=recentupcoming`

Paste that into the app and tap **Load deadlines**.

## Project structure

```
lib/
  main.dart                 UI: URL input, deadline list, reminder settings
  ics_parser.dart           Parses iCalendar (.ics) text into Deadline objects
  notification_service.dart Schedules local notifications via AlarmManager
android/app/src/main/AndroidManifest.xml  Notification + alarm permissions
pubspec.yaml                Dependencies
```

## Running

```bash
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

## Core features (what to demo)

- **Fetch & parse** a real `.ics` calendar feed.
- **Deadline list** sorted by date, color-coded by urgency
  (red < 24 h, orange < 3 days, amber < 1 week, blue later) with a
  live "time remaining" counter.
- **Local notifications** scheduled before each deadline, with a
  configurable lead time (1 hour to 3 days).
- **Offline cache** — the last loaded deadlines show instantly on reopen.
- **Pull to refresh** re-fetches the feed and re-schedules reminders.

## Dependencies

- `http` — fetch the .ics feed
- `flutter_local_notifications` + `timezone` — schedule reminders
- `shared_preferences` — persist the URL and cached events
- `intl` — date formatting
