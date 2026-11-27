import 'package:flutter/material.dart';

import '../daily.dart';
import '../native.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = Store.instance;
  int _count = 0;
  int _sources = 0;
  int _notes = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_rebuild);
    _counts();
  }

  Future<void> _counts() async {
    try {
      final c = await store.quoteCount();
      final src = (await store.sources()).length;
      final notes = await store.noteCount();
      if (mounted) {
        setState(() {
          _count = c;
          _notes = notes;
          _sources = src;
        });
      }
    } catch (_) {}
  }

  void _toast(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  /// Затемнить экран на время долгой операции.
  Future<T> _withProgress<T>(String text, Future<T> Function() work) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ]),
        ),
      ),
    );
    try {
      return await work();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _backup() async {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'mysli-backup-${d.year}-${two(d.month)}-${two(d.day)}.zip';
    final uri = await Native.createDocument(name, 'application/zip');
    if (uri == null || !mounted) return;
    final err = await _withProgress('Сохраняю копию…', () async {
      await store.close();
      try {
        return await Native.writeBackup(uri, store.dbPath);
      } finally {
        await store.open();
      }
    });
    _toast(err ?? 'Резервная копия сохранена: $name');
  }

  Future<void> _restore() async {
    final uri = await Native.openDocument();
    if (uri == null || !mounted) return;
    final info = await Native.checkBackup(uri);
    if (!mounted) return;
    if (info['ok'] != true) {
      _toast('${info['error'] ?? 'Это не резервная копия'}');
      return;
    }
    final created = info['created'] as int? ?? 0;
    final when = created > 0
        ? ' от ${formatDate(DateTime.fromMillisecondsSinceEpoch(created))}'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Восстановить копию$when?'),
        content: Text(
            'Все текущие цитаты, избранное, дневник, источники и настройки '
            'будут заменены данными из копии.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Восстановить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await _withProgress('Восстанавливаю…', () async {
      await store.close();
      try {
        return await Native.restoreBackup(uri, store.dbPath);
      } finally {
        await store.open();
      }
    });
    await Reminder.sync();
    _counts();
    _toast(err ?? 'Данные восстановлены');
  }

  @override
  void dispose() {
    store.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _setReminder(bool on) async {
    if (on) {
      final allowed = await Native.requestNotificationPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Разрешите уведомления для «Мудрых мыслей» '
                'в настройках телефона, иначе напоминание не появится.')));
      }
    }
    await store.setSetting('reminder_on', on ? '1' : '0');
    await Reminder.sync();
  }

  /// Изменить время [index] (или добавить новое, если index == null).
  Future<void> _pickTime(int? index) async {
    final list = List.of(Reminder.times);
    final cur = index == null ? (list.isEmpty ? 480 : (list.last + 240) % 1440) : list[index];
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      helpText: 'Время напоминания',
    );
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    if (index == null) {
      list.add(m);
    } else {
      list[index] = m;
    }
    await Reminder.setTimes(list);
  }

  Future<void> _removeTime(int index) async {
    final list = List.of(Reminder.times)..removeAt(index);
    await Reminder.setTimes(list);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = textScale();
    final mode = store.setting('theme', 'system');
    final times = Reminder.times;
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(t,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  letterSpacing: 0.5)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        header('Напоминание'),
        SwitchListTile(
          title: const Text('Присылать мысль дня'),
          subtitle: const Text('Первое напоминание — мысль дня, второе и '
              'третье — ещё по одной мудрой мысли'),
          value: Reminder.enabled,
          onChanged: _setReminder,
        ),
        for (var i = 0; i < times.length; i++)
          ListTile(
            enabled: Reminder.enabled,
            leading: const Icon(Icons.schedule),
            title: Text(i == 0 ? 'Мысль дня' : 'Ещё одна мысль'),
            onTap: Reminder.enabled ? () => _pickTime(i) : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(Reminder.fmt(times[i]),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              if (times.length > 1)
                IconButton(
                  tooltip: 'Убрать',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed:
                      Reminder.enabled ? () => _removeTime(i) : null,
                ),
            ]),
          ),
        if (times.length < Reminder.maxTimes)
          ListTile(
            enabled: Reminder.enabled,
            leading: const Icon(Icons.add_alarm),
            title: const Text('Добавить напоминание'),
            subtitle: const Text('До трёх в день'),
            onTap: Reminder.enabled ? () => _pickTime(null) : null,
          ),
        header('Язык мыслей'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Все')),
              ButtonSegment(value: 'ru', label: Text('Русские')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {store.lang},
            onSelectionChanged: (v) => store.setSetting('lang', v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            'Влияет на мысль дня, ленту, темы и виджет.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ),
        header('Виджет'),
        ListTile(
          leading: const Icon(Icons.widgets_outlined),
          title: const Text('Мысль дня на рабочем столе'),
          subtitle: const Text('Нажмите, чтобы добавить. Или: долгое нажатие '
              'на пустое место рабочего стола → Виджеты → «Мудрые мысли».'),
          isThreeLine: true,
          onTap: () async {
            final ok = await Native.pinWidget();
            if (!ok) {
              _toast('Добавьте виджет вручную: долгое нажатие на рабочий '
                  'стол → Виджеты → «Мудрые мысли».');
            }
          },
        ),
        header('Текст'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Истина — солнце разума.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: quoteFont, fontSize: 21 * scale),
          ),
        ),
        Slider(
          value: scale.clamp(0.8, 1.6).toDouble(),
          min: 0.8,
          max: 1.6,
          divisions: 8,
          label: '${(scale * 100).round()}%',
          onChanged: (v) => store.setSetting('text_scale', v.toStringAsFixed(2)),
        ),
        header('Оформление'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('Как в системе')),
              ButtonSegment(value: 'light', label: Text('Светлое')),
              ButtonSegment(value: 'dark', label: Text('Тёмное')),
            ],
            selected: {mode},
            onSelectionChanged: (v) => store.setSetting('theme', v.first),
          ),
        ),
        header('Резервная копия'),
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: const Text('Сохранить копию'),
          subtitle: const Text('Цитаты, избранное, дневник, источники и настройки — '
              'в один файл .zip. Сохраните его на Google Диск или в «Загрузки».'),
          isThreeLine: true,
          onTap: _backup,
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text('Восстановить из копии'),
          subtitle: const Text('Например, на новом телефоне'),
          onTap: _restore,
        ),
        header('О приложении'),
        ListTile(
          leading: const QuoteMark(size: 24),
          title: const Text('Мудрые мысли'),
          subtitle: Text('В базе ${pluralThoughts(_count)}, источников и '
              'ссылок: $_sources, записей в дневнике: $_notes. '
              'Дней подряд: ${store.streak} (рекорд — ${store.bestStreak}). '
              'Встроенная подборка — книги в общественном достоянии '
              'с русской и английской Викитеки.'),
        ),
      ]),
    );
  }
}
