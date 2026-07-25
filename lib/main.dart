import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ics_parser.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MoodleReminderApp());
}

class MoodleReminderApp extends StatelessWidget {
  const MoodleReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moodle Reminder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF98012), // Moodle orange
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  List<Deadline> _deadlines = [];
  bool _loading = false;
  String? _error;
  int _hoursBefore = 24;

  static const _kUrl = 'calendar_url';
  static const _kCache = 'deadline_cache';
  static const _kHours = 'hours_before';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kUrl);
    final hours = prefs.getInt(_kHours) ?? 24;
    final cache = prefs.getString(_kCache);
    setState(() => _hoursBefore = hours);
    if (url != null) {
      _urlController.text = url;
      if (cache != null) {
        try {
          final list = (jsonDecode(cache) as List)
              .map((e) => Deadline.fromJson(e))
              .toList();
          setState(() => _deadlines = list);
        } catch (_) {}
      }
      // Refresh in background
      _fetch(silent: true);
    }
  }

  Future<void> _fetch({bool silent = false}) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please paste your Moodle calendar URL.');
      return;
    }
    if (!silent) {
      setState(() {
      _loading = true;
      _error = null;
    });
    }

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        throw 'Server returned ${resp.statusCode}';
      }
      final body = resp.body;
      if (!body.contains('BEGIN:VCALENDAR')) {
        throw 'That URL is not a valid calendar feed.';
      }
      final parsed = IcsParser.parse(body);
      final upcoming = parsed.where((d) => !d.isPast).toList();

      // Persist
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUrl, url);
      await prefs.setString(
          _kCache, jsonEncode(upcoming.map((e) => e.toJson()).toList()));

      // Schedule notifications
      await NotificationService.scheduleAll(upcoming,
          hoursBefore: _hoursBefore);

      setState(() {
        _deadlines = upcoming;
        _loading = false;
        _error = null;
      });
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Loaded ${upcoming.length} deadlines. Reminders set $_hoursBefore h before each.')),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        if (!silent) _error = e.toString();
      });
    }
  }

  Future<void> _saveHours(int h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHours, h);
    setState(() => _hoursBefore = h);
    if (_deadlines.isNotEmpty) {
      await NotificationService.scheduleAll(_deadlines, hoursBefore: h);
    }
  }

  Color _urgencyColor(Deadline d) {
    final h = d.hoursRemaining;
    if (h < 24) return Colors.red;
    if (h < 72) return Colors.orange;
    if (h < 168) return Colors.amber;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moodle Reminder'),
        actions: const [
          IconButton(
            icon: Icon(Icons.notifications_active_outlined),
            tooltip: 'Test notification',
            onPressed: NotificationService.showTest,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetch(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // URL input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Moodle calendar URL (.ics)',
                hintText: 'https://moodle.../calendar/export_execute.php?...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _fetch(),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(_loading ? 'Loading...' : 'Load deadlines'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Reminder timing selector
            Row(
              children: [
                const Text('Remind me'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _hoursBefore,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 hour before')),
                    DropdownMenuItem(value: 6, child: Text('6 hours before')),
                    DropdownMenuItem(
                        value: 24, child: Text('1 day before')),
                    DropdownMenuItem(
                        value: 48, child: Text('2 days before')),
                    DropdownMenuItem(
                        value: 72, child: Text('3 days before')),
                  ],
                  onChanged: (v) => v == null ? null : _saveHours(v),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            // Deadline list
            if (_deadlines.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No upcoming deadlines.\nPaste your calendar URL and tap Load.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ..._deadlines.map(_deadlineTile),
          ],
        ),
      ),
    );
  }

  Widget _deadlineTile(Deadline d) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _urgencyColor(d),
          radius: 8,
        ),
        title: Text(d.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d.course.isNotEmpty)
              Text(d.course,
                  style: TextStyle(color: Colors.grey.shade600)),
            Text(formatDue(d.due)),
          ],
        ),
        trailing: Text(
          d.remainingText,
          style: TextStyle(
            color: _urgencyColor(d),
            fontWeight: FontWeight.bold,
          ),
        ),
        isThreeLine: d.course.isNotEmpty,
      ),
    );
  }
}
