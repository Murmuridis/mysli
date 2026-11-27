import 'package:flutter/material.dart';

import '../native.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Первое знакомство: язык мыслей и время напоминания.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _lang = 'all';
  bool _remind = true;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 30);

  Future<void> _finish() async {
    final store = Store.instance;
    await store.setSetting('lang', _lang);
    if (_remind) {
      await Native.requestNotificationPermission();
      await store.setSetting(
          'reminder_times', '${_time.hour * 60 + _time.minute}');
    }
    await store.setSetting('reminder_on', _remind ? '1' : '0');
    await store.setSetting('onboarded', '1');
    await Reminder.sync();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(String value, String title, String sub) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<String>(
            value: value,
            groupValue: _lang,
            onChanged: (v) => setState(() => _lang = v!),
            title: Text(title),
            subtitle: Text(sub),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(child: QuoteMark(size: 56, color: scheme.secondary)),
            const SizedBox(height: 18),
            Text('Мудрые мысли',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: quoteFont,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Каждый день — одна мысль великих людей: Марк Аврелий, '
              'Ларошфуко, Толстой, Франклин, Конфуций и другие. '
              'Минута в день — чтобы остановиться и подумать.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Text('На каком языке читать?',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: scheme.primary)),
            const SizedBox(height: 8),
            option('all', 'Русский и английский', 'Все мысли подряд'),
            option('ru', 'Только русский', 'Переводы классиков и русские авторы'),
            option('en', 'Только английский', 'In English — оригиналы и классические переводы'),
            const SizedBox(height: 18),
            Text('Напоминание',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: scheme.primary)),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                SwitchListTile(
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                  title: const Text('Присылать мысль дня'),
                  subtitle: const Text('Уведомление с цитатой'),
                ),
                ListTile(
                  enabled: _remind,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Во сколько'),
                  trailing: Text(_time.format(context),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  onTap: !_remind
                      ? null
                      : () async {
                          final t = await showTimePicker(
                              context: context, initialTime: _time);
                          if (t != null) setState(() => _time = t);
                        },
                ),
              ]),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _finish,
              child: const Text('Начать', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 10),
            Text(
              'Всё это можно изменить потом в настройках.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
