# Moodle Reminder

A lightweight **Android app (Flutter)** that reads your **Moodle calendar** and reminds you of upcoming deadlines with local notifications — so you never miss an assignment, quiz, or exam.

Instead of scraping or storing your password, the app uses Moodle's official **iCalendar (.ics) export link**, which carries a private token and works without login.

---

## ✨ Features

- 📥 **Load deadlines** from your Moodle calendar `.ics` URL
- 📋 **Deadline list** sorted by date, colour-coded by urgency:
  - 🔴 red (< 24 h) · 🟠 orange (< 3 days) · 🟡 amber (< 1 week) · 🔵 blue (later)
- ⏳ **Live countdown** of the time remaining for each deadline
- 🔔 **Local notifications** a chosen time before each deadline (1 hour → 3 days)
- 📴 **Offline cache** — last loaded deadlines are shown instantly, even without internet
- 🔄 **Pull to refresh** to re-fetch and reschedule reminders

---

## 🏗️ How it works

1. Get your calendar URL from Moodle: **Calendar → Export calendar → Get calendar URL**.
2. Paste the URL into the app and tap **Load deadlines**.
3. The app fetches the `.ics` feed over HTTPS, parses the events, filters out past ones, and sorts the rest.
4. It schedules a local notification before each deadline and caches the list for offline use.

No password is ever stored or sent — only the calendar URL is kept locally on the device.

---

## 📁 Project Structure

```
moodle_reminder/
├── lib/
│   ├── main.dart                  # App entry + HomePage UI (list, URL input, settings)
│   ├── ics_parser.dart            # Deadline model + IcsParser (.ics → Deadline objects)
│   └── notification_service.dart  # Schedules & delivers local notifications
├── android/
│   └── app/src/main/AndroidManifest.xml   # Permissions: internet, notifications, alarms
├── pubspec.yaml                   # Dependencies
└── README.md
```

---

## 🧩 Design Patterns Used

- **Singleton** — `NotificationService` uses one shared notification manager.
- **Repository** — data-access logic (fetch / parse / cache) is separated from the UI.
- **Factory** — `Deadline.fromJson()` and `IcsParser.parse()` build objects from raw data.
- **Observer (State)** — Flutter's `setState()` rebuilds the UI when deadlines change.

---

## 🚀 Getting Started

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on a connected device / emulator
flutter run

# 3. Build a release APK
flutter build apk --release
```

**Requirements:** Flutter SDK 3.x, Android 6.0 (API 23) or higher.

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `http` | Fetch the `.ics` calendar feed |
| `flutter_local_notifications` | Schedule & show local notifications |
| `timezone` | Correct scheduling across time zones |
| `shared_preferences` | Persist the URL and cached deadlines |
| `intl` | Date formatting |

---

## 👤 Author

**Mohammed Emad Elrefy** — Al-Aqsa University, Department of Computer Science
Software Engineering Project — Supervisor: Eng. Firas Fouad Al-ijla


