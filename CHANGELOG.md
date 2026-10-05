# Changelog

## 2.0.0

- Added secure storage for the private Moodle calendar URL and migration from the old SharedPreferences key.
- Added periodic background calendar synchronization using Android WorkManager.
- Added multiple reminder offsets and stable notification IDs derived from Moodle event UIDs.
- Added exact-alarm permission handling for modern Android versions.
- Expanded ICS parsing to support UID, URL, location, status, sequence, last-modified and TZID values.
- Added local completed/deadline state that suppresses reminders for completed work.
- Added Home, Calendar, Courses and Settings destinations.
- Added Arabic/English UI switching and system/light/dark themes.
- Added onboarding for connecting a Moodle iCalendar feed.
- Added parser unit tests.
- Added GitHub Actions verification for formatting, analysis, tests, and release APK builds.
