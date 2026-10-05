import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/deadline.dart';
import '../services/ics_parser.dart';
import '../services/notification_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  DateTime _selectedDate = DateTime.now();

  bool get _ar => widget.controller.locale.languageCode == 'ar';
  String t(String en, String ar) => _ar ? ar : en;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!controller.calendarConnected) return _Setup(controller: controller);

    final titles = [
      t('Home', 'الرئيسية'),
      t('Calendar', 'التقويم'),
      t('Courses', 'المساقات'),
      t('Settings', 'الإعدادات'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: t('Sync now', 'مزامنة الآن'),
            onPressed: controller.busy ? null : _sync,
            icon: controller.busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _home(),
          _calendar(),
          _courses(),
          _settings(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: t('Home', 'الرئيسية'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: t('Calendar', 'التقويم'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: t('Courses', 'المساقات'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: t('Settings', 'الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync() async {
    final ok = await widget.controller.sync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? t('Moodle calendar synced.', 'تمت مزامنة تقويم Moodle.')
              : widget.controller.error ?? t('Sync failed.', 'فشلت المزامنة.'),
        ),
      ),
    );
  }

  Widget _home() {
    final controller = widget.controller;
    final deadlines = controller.activeDeadlines;
    final next = deadlines.isEmpty ? null : deadlines.first;
    final weekEnd = DateTime.now().add(const Duration(days: 7));
    final weekCount = deadlines.where((d) => d.due.isBefore(weekEnd)).length;

    return RefreshIndicator(
      onRefresh: () => controller.sync(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _HeroCard(
            title: t('$weekCount deadlines this week', '$weekCount مواعيد هذا الأسبوع'),
            next: next,
            lastSync: controller.lastSync,
            isArabic: _ar,
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: Text(controller.error!),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _section(t('Upcoming deadlines', 'المواعيد القادمة'), '${deadlines.length}'),
          const SizedBox(height: 8),
          if (deadlines.isEmpty)
            _empty(
              Icons.task_alt_rounded,
              t('You are all caught up', 'لا توجد مواعيد قادمة'),
              t('Pull down to sync your Moodle calendar.', 'اسحب للأسفل لمزامنة تقويم Moodle.'),
            )
          else
            ...deadlines.take(15).map(_deadlineCard),
          if (controller.completedDeadlines.isNotEmpty) ...[
            const SizedBox(height: 18),
            _section(
              t('Completed', 'المكتملة'),
              '${controller.completedDeadlines.length}',
            ),
            const SizedBox(height: 8),
            ...controller.completedDeadlines.take(5).map(_deadlineCard),
          ],
        ],
      ),
    );
  }

  Widget _calendar() {
    final items = widget.controller.activeDeadlines.where((deadline) {
      final d = deadline.due;
      return d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 730)),
            onDateChanged: (value) => setState(() => _selectedDate = value),
          ),
        ),
        const SizedBox(height: 16),
        _section(
          DateFormat.yMMMMd(widget.controller.locale.languageCode).format(_selectedDate),
          '${items.length}',
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          _empty(
            Icons.event_available_outlined,
            t('Nothing due on this day', 'لا يوجد تسليم في هذا اليوم'),
            t('Choose another date to inspect your agenda.', 'اختر تاريخًا آخر لعرض المواعيد.'),
          )
        else
          ...items.map(_deadlineCard),
      ],
    );
  }

  Widget _courses() {
    final grouped = <String, List<Deadline>>{};
    for (final deadline in widget.controller.activeDeadlines) {
      final course = deadline.course.isEmpty ? t('Other', 'أخرى') : deadline.course;
      grouped.putIfAbsent(course, () => []).add(deadline);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _section(t('My courses', 'مساقاتي'), '${entries.length}'),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          _empty(
            Icons.school_outlined,
            t('No courses yet', 'لا توجد مساقات بعد'),
            t('Courses appear after the first successful sync.', 'ستظهر المساقات بعد أول مزامنة ناجحة.'),
          )
        else
          ...entries.map((entry) {
            final next = entry.value.first;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(entry.key.isEmpty ? '?' : entry.key.substring(0, 1).toUpperCase()),
                ),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  t(
                    '${entry.value.length} upcoming • next ${next.remainingText}',
                    '${entry.value.length} قادمة • التالي ${next.remainingText}',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showCourse(entry.key, entry.value),
              ),
            );
          }),
      ],
    );
  }

  Widget _settings() {
    final controller = widget.controller;
    const choices = [72, 48, 24, 6, 1];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _settingsCard(
          t('Reminder schedule', 'جدول التنبيهات'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: choices.map((hours) {
              final selected = controller.reminderOffsets.contains(hours);
              return FilterChip(
                selected: selected,
                label: Text(_offsetLabel(hours)),
                onSelected: (_) {
                  final values = [...controller.reminderOffsets];
                  selected ? values.remove(hours) : values.add(hours);
                  controller.setReminderOffsets(values);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _settingsCard(
          t('Appearance', 'المظهر'),
          DropdownButtonFormField<ThemeMode>(
            initialValue: controller.themeMode,
            decoration: InputDecoration(labelText: t('Theme', 'السمة')),
            items: ThemeMode.values
                .map((mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(switch (mode) {
                        ThemeMode.system => t('System', 'النظام'),
                        ThemeMode.light => t('Light', 'فاتح'),
                        ThemeMode.dark => t('Dark', 'داكن'),
                      }),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) controller.setThemeMode(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        _settingsCard(
          t('Language', 'اللغة'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {controller.locale.languageCode},
            onSelectionChanged: (value) => controller.setLocale(Locale(value.first)),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(t('Test notification', 'اختبار الإشعار')),
                onTap: NotificationService.showTest,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: Text(t('Sync now', 'مزامنة الآن')),
                subtitle: Text(_lastSyncText()),
                onTap: controller.busy ? null : _sync,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(t('Private calendar URL', 'رابط التقويم الخاص')),
                subtitle: Text(t('Stored in secure device storage', 'محفوظ في التخزين الآمن للجهاز')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _disconnect,
          icon: const Icon(Icons.link_off_rounded),
          label: Text(t('Disconnect Moodle', 'فصل Moodle')),
        ),
      ],
    );
  }

  Widget _deadlineCard(Deadline deadline) {
    final completed = widget.controller.completedIds.contains(deadline.stableKey);
    final color = _urgency(deadline);
    return Card(
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle_rounded : Icons.schedule_rounded,
          color: completed ? Colors.green : color,
        ),
        title: Text(
          deadline.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text([
          if (deadline.course.isNotEmpty) deadline.course,
          formatDue(deadline.due),
        ].join(' • ')),
        trailing: Text(
          deadline.remainingText,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        onTap: () => _showDeadline(deadline),
      ),
    );
  }

  Widget _section(String title, String count) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Badge(label: Text(count)),
        ],
      );

  Widget _empty(IconData icon, String title, String subtitle) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _settingsCard(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );

  String _offsetLabel(int hours) {
    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      return t('$days day${days == 1 ? '' : 's'}', '$days يوم');
    }
    return t('$hours hour${hours == 1 ? '' : 's'}', '$hours ساعة');
  }

  String _lastSyncText() {
    final value = widget.controller.lastSync;
    if (value == null) return t('Not synced yet', 'لم تتم المزامنة بعد');
    return t('Last sync: ${DateFormat.jm().format(value)}', 'آخر مزامنة: ${DateFormat.jm().format(value)}');
  }

  Color _urgency(Deadline deadline) {
    final hours = deadline.hoursRemaining;
    if (hours < 24) return Colors.red;
    if (hours < 72) return Colors.orange;
    if (hours < 168) return Colors.amber.shade800;
    return Theme.of(context).colorScheme.primary;
  }

  Future<void> _showDeadline(Deadline deadline) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deadline.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (deadline.course.isNotEmpty) Text(deadline.course),
              Text(formatDue(deadline.due)),
              if (deadline.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(deadline.description),
              ],
              if (deadline.url.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectableText(deadline.url),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await widget.controller.toggleCompleted(deadline);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: Icon(widget.controller.completedIds.contains(deadline.stableKey)
                      ? Icons.undo_rounded
                      : Icons.check_rounded),
                  label: Text(widget.controller.completedIds.contains(deadline.stableKey)
                      ? t('Mark active', 'إرجاعه نشطًا')
                      : t('Mark completed', 'تحديد كمكتمل')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCourse(String course, List<Deadline> deadlines) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...deadlines.take(8).map(_deadlineCard),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Disconnect Moodle?', 'فصل Moodle؟')),
        content: Text(t(
          'This removes the private calendar URL and cached deadline data from this app.',
          'سيؤدي هذا إلى حذف رابط التقويم الخاص والبيانات المخزنة من التطبيق.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Disconnect', 'فصل'))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.disconnect();
      if (mounted) setState(() => _index = 0);
    }
  }
}

class _Setup extends StatefulWidget {
  const _Setup({required this.controller});
  final AppController controller;

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  final _url = TextEditingController();
  bool get _ar => widget.controller.locale.languageCode == 'ar';
  String t(String en, String ar) => _ar ? ar : en;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moodle Reminder'),
        actions: [
          TextButton(
            onPressed: () => widget.controller.setLocale(Locale(_ar ? 'en' : 'ar')),
            child: Text(_ar ? 'EN' : 'العربية'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.notifications_active_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            t('Never miss another Moodle deadline', 'لا تفوّت موعد Moodle بعد الآن'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Connect Moodle once. Your private calendar URL stays in secure device storage.',
              'اربط Moodle مرة واحدة. يبقى رابط التقويم الخاص محفوظًا في التخزين الآمن للجهاز.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...[
            t('Open Moodle Calendar', 'افتح تقويم Moodle'),
            t('Choose Export calendar', 'اختر تصدير التقويم'),
            t('Copy the generated calendar URL', 'انسخ رابط التقويم الذي تم إنشاؤه'),
          ].asMap().entries.map((entry) => ListTile(
                leading: CircleAvatar(child: Text('${entry.key + 1}')),
                title: Text(entry.value),
              )),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t('Moodle calendar URL', 'رابط تقويم Moodle'),
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(
                tooltip: t('Paste', 'لصق'),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) _url.text = data!.text!.trim();
                },
                icon: const Icon(Icons.content_paste_rounded),
              ),
            ),
          ),
          if (widget.controller.error != null) ...[
            const SizedBox(height: 10),
            Text(widget.controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.controller.busy
                ? null
                : () async {
                    final ok = await widget.controller.connect(_url.text);
                    if (!ok && mounted) setState(() {});
                  },
            icon: widget.controller.busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open_rounded),
            label: Text(t('Connect securely', 'اتصال آمن')),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.next, required this.lastSync, required this.isArabic});
  final String title;
  final Deadline? next;
  final DateTime? lastSync;
  final bool isArabic;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.primaryContainer]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onPrimary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            if (next == null)
              Text(t('Nothing urgent right now.', 'لا يوجد شيء عاجل الآن.'))
            else ...[
              Text(t('NEXT DEADLINE', 'الموعد التالي'), style: TextStyle(color: scheme.onPrimary.withOpacity(.8), fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(next!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 4),
              Text('${next!.remainingText} • ${formatDue(next!.due)}'),
            ],
            if (lastSync != null) ...[
              const SizedBox(height: 12),
              Text(
                t('Last synced ${DateFormat.jm().format(lastSync!)}', 'آخر مزامنة ${DateFormat.jm().format(lastSync!)}'),
                style: TextStyle(color: scheme.onPrimary.withOpacity(.8)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
