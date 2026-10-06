# Contributing to Moodle Reminder

Thanks for helping improve Moodle Reminder.

## Before you start

- Search existing issues and pull requests before opening a duplicate.
- Keep changes focused and small enough to review safely.
- Do not commit private Moodle calendar URLs, tokens, credentials, signing keys, or generated secrets.
- For security-sensitive reports, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Development setup

Use a recent Flutter toolchain. CI currently pins Flutter 3.47.6 and Java 17.

```bash
flutter pub get
flutter run
```

## Required checks

Before opening a pull request, run:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

GitHub Actions repeats these checks for application changes.

## Pull requests

A good pull request should:

- explain the problem and the chosen solution;
- include tests for parser, state, or scheduling behavior when practical;
- avoid unrelated refactors;
- update documentation when behavior changes;
- update `CHANGELOG.md` when the change should appear in release notes;
- preserve Arabic/English behavior and RTL layout where applicable.

## Calendar and notification changes

Changes to ICS parsing or notification scheduling deserve extra care because malformed calendar data, timezone handling, duplicate event IDs, and exact-alarm availability can affect reminder correctness.

When changing these areas, add or update tests covering the relevant edge case.

## Commit style

Prefer short conventional-style subjects such as:

- `feat: add deadline filter`
- `fix: handle folded ICS property`
- `docs: clarify Moodle calendar export`
- `test: cover date-only event`
- `ci: update Flutter workflow`

## Release changes

The release workflow reads the version from `pubspec.yaml` and release notes from the matching `CHANGELOG.md` section. Version updates should therefore change both files together.
