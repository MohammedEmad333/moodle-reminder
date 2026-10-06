# Security Policy

## Supported versions

Security fixes are targeted at the latest published release and the current `main` branch.

| Version | Supported |
| --- | --- |
| 2.0.x | Yes |
| Older versions | No guaranteed fixes |

## Reporting a vulnerability

Please do **not** publish sensitive vulnerability details, private Moodle calendar URLs, tokens, credentials, or signing material in a public issue.

Use GitHub's private vulnerability reporting feature for this repository when available. If private reporting is unavailable, contact the repository owner privately and provide only the minimum information needed to reproduce the issue.

A useful report includes:

- affected version or commit;
- affected Android version/device when relevant;
- clear reproduction steps;
- expected and actual behavior;
- security impact;
- whether a private Moodle calendar token or other secret may have been exposed.

## Sensitive data model

Moodle Reminder does not request Moodle credentials. The main application secret is the private Moodle iCalendar export URL because it contains a token capable of reading the exported calendar.

The application stores that URL through `flutter_secure_storage`. Reports involving token disclosure, insecure persistence, logs containing the calendar URL, or unintended sharing of cached Moodle data should be treated as security-sensitive.

## Scope examples

Examples of issues that should be reported privately include:

- exposure of a private Moodle calendar URL or token;
- insecure storage or logging of secrets;
- unintended access to another user's cached deadline data;
- notification payloads exposing unexpected sensitive information;
- vulnerabilities in update or release artifacts that could lead to tampering.

General bugs, feature requests, UI problems, and non-sensitive parser issues can use the public issue templates.
