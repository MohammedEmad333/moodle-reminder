import 'package:intl/intl.dart';

/// A single deadline/event parsed from the Moodle .ics calendar.
class Deadline {
  final String title;
  final DateTime due;
  final String description;
  final String course;

  Deadline({
    required this.title,
    required this.due,
    this.description = '',
    this.course = '',
  });

  /// Hours remaining until the deadline (negative if past).
  double get hoursRemaining => due.difference(DateTime.now()).inMinutes / 60.0;

  bool get isPast => due.isBefore(DateTime.now());

  /// Human-readable remaining time, e.g. "2 days 3 hours".
  String get remainingText {
    if (isPast) return 'Past';
    final mins = due.difference(DateTime.now()).inMinutes;
    final days = mins ~/ 1440;
    final hours = (mins % 1440) ~/ 60;
    final m = mins % 60;
    if (days > 0) return '$days d ${hours > 0 ? "$hours h" : ""}'.trim();
    if (hours > 0) return '$hours h ${m > 0 ? "$m m" : ""}'.trim();
    return '$m m';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'due': due.toIso8601String(),
        'description': description,
        'course': course,
      };

  factory Deadline.fromJson(Map<String, dynamic> j) => Deadline(
        title: j['title'] ?? '',
        due: DateTime.parse(j['due']),
        description: j['description'] ?? '',
        course: j['course'] ?? '',
      );
}

/// Parses raw iCalendar text into a list of [Deadline]s.
///
/// Moodle exports VEVENT blocks like:
///   BEGIN:VEVENT
///   SUMMARY:Assignment 1 is due
///   DTSTART:20260615T235900Z
///   DESCRIPTION:Course: Data Security
///   CATEGORIES:Data Security
///   END:VEVENT
class IcsParser {
  static List<Deadline> parse(String raw) {
    // iCalendar lines can be "folded" (wrapped) — a continuation line
    // starts with a space or tab. Unfold them first.
    final unfolded = _unfold(raw);
    final lines = unfolded.split(RegExp(r'\r?\n'));

    final deadlines = <Deadline>[];
    bool inEvent = false;
    String summary = '';
    String description = '';
    String category = '';
    DateTime? start;

    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        summary = '';
        description = '';
        category = '';
        start = null;
        continue;
      }
      if (line == 'END:VEVENT') {
        if (start != null && summary.isNotEmpty) {
          deadlines.add(Deadline(
            title: _clean(summary),
            due: start,
            description: _clean(description),
            course: _clean(category),
          ));
        }
        inEvent = false;
        continue;
      }
      if (!inEvent) continue;

      final idx = line.indexOf(':');
      if (idx == -1) continue;
      final keyPart = line.substring(0, idx); // may contain params, e.g. DTSTART;VALUE=DATE
      final value = line.substring(idx + 1);
      final key = keyPart.split(';').first.toUpperCase();

      switch (key) {
        case 'SUMMARY':
          summary = value;
          break;
        case 'DESCRIPTION':
          description = value;
          break;
        case 'CATEGORIES':
          category = value;
          break;
        case 'DTSTART':
          start = _parseDate(value, keyPart);
          break;
      }
    }

    deadlines.sort((a, b) => a.due.compareTo(b.due));
    return deadlines;
  }

  /// Joins folded continuation lines (RFC 5545 line folding).
  static String _unfold(String raw) {
    return raw.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  }

  /// Unescapes iCalendar text (\, \; \n etc.).
  static String _clean(String s) {
    return s
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\')
        .trim();
  }

  /// Parses DTSTART values in the common Moodle formats:
  ///   20260615T235900Z   (UTC)
  ///   20260615T235900    (local/floating)
  ///   20260615           (date only, VALUE=DATE)
  static DateTime? _parseDate(String value, String keyPart) {
    try {
      final v = value.trim();
      // Date-only form
      if (keyPart.toUpperCase().contains('VALUE=DATE') ||
          (v.length == 8 && !v.contains('T'))) {
        final y = int.parse(v.substring(0, 4));
        final mo = int.parse(v.substring(4, 6));
        final d = int.parse(v.substring(6, 8));
        return DateTime(y, mo, d, 23, 59);
      }
      // Date-time form: YYYYMMDDTHHMMSS[Z]
      final isUtc = v.endsWith('Z');
      final core = isUtc ? v.substring(0, v.length - 1) : v;
      final y = int.parse(core.substring(0, 4));
      final mo = int.parse(core.substring(4, 6));
      final d = int.parse(core.substring(6, 8));
      final h = int.parse(core.substring(9, 11));
      final mi = int.parse(core.substring(11, 13));
      final s = core.length >= 15 ? int.parse(core.substring(13, 15)) : 0;
      if (isUtc) {
        return DateTime.utc(y, mo, d, h, mi, s).toLocal();
      }
      return DateTime(y, mo, d, h, mi, s);
    } catch (_) {
      return null;
    }
  }
}

String formatDue(DateTime dt) => DateFormat('EEE, MMM d • h:mm a').format(dt);
