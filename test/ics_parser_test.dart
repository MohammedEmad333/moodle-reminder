import 'package:flutter_test/flutter_test.dart';
import 'package:moodle_reminder/services/ics_parser.dart';

void main() {
  group('IcsParser', () {
    test('parses Moodle metadata and UTC dates', () {
      const raw = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:assignment-42@example.edu\r
SUMMARY:Assignment 2 is due\r
DTSTART:20300115T215900Z\r
DESCRIPTION:Submit\\nPart A\\, Part B\r
CATEGORIES:Software Engineering\r
URL:https://moodle.example.edu/mod/assign/view.php?id=42\r
LOCATION:Online\r
SEQUENCE:3\r
LAST-MODIFIED:20300110T120000Z\r
STATUS:CONFIRMED\r
END:VEVENT\r
END:VCALENDAR''';

      final result = IcsParser.parse(raw);

      expect(result, hasLength(1));
      final deadline = result.single;
      expect(deadline.uid, 'assignment-42@example.edu');
      expect(deadline.title, 'Assignment 2 is due');
      expect(deadline.course, 'Software Engineering');
      expect(deadline.description, 'Submit\nPart A, Part B');
      expect(deadline.url, contains('id=42'));
      expect(deadline.location, 'Online');
      expect(deadline.sequence, 3);
      expect(deadline.status, 'CONFIRMED');
      expect(deadline.due.toUtc(), DateTime.utc(2030, 1, 15, 21, 59));
      expect(deadline.lastModified?.toUtc(), DateTime.utc(2030, 1, 10, 12));
    });

    test('unfolds continuation lines', () {
      const raw = '''BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:x\nSUMMARY:A very long assignment\n title\nDTSTART:20310101T120000Z\nEND:VEVENT\nEND:VCALENDAR''';

      final result = IcsParser.parse(raw);
      expect(result.single.title, 'A very long assignmenttitle');
    });

    test('treats date-only events as end of day', () {
      const raw = '''BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:y\nSUMMARY:Exam day\nDTSTART;VALUE=DATE:20320520\nEND:VEVENT\nEND:VCALENDAR''';

      final result = IcsParser.parse(raw);
      expect(result.single.due.hour, 23);
      expect(result.single.due.minute, 59);
    });

    test('skips malformed events instead of crashing the feed', () {
      const raw = '''BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Broken\nDTSTART:not-a-date\nEND:VEVENT\nBEGIN:VEVENT\nUID:valid\nSUMMARY:Valid\nDTSTART:20350101T120000Z\nEND:VEVENT\nEND:VCALENDAR''';

      final result = IcsParser.parse(raw);
      expect(result, hasLength(1));
      expect(result.single.uid, 'valid');
    });
  });
}
