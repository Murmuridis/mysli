import 'dart:math';

import 'package:flutter/material.dart';

import '../daily.dart';
import '../native.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Главный экран: мысль на сегодня (и на соседние дни).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Quote> _ordered = [];
  int _offset = 0; // 0 — сегодня, -1 — вчера, +1 — завтра
  Quote? _random; // если выбрана «случайная» цитата
  bool _loading = true;
  bool _widgetTip = false;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    Store.instance.addListener(_reload);
    _reload();
    _checkWidgetTip();
  }

  Future<void> _checkWidgetTip() async {
    if (Store.instance.setting('widget_tip_done') == '1') return;
    final ok = await Native.widgetSupported();
    if (mounted && ok) setState(() => _widgetTip = true);
  }

  Future<void> _closeWidgetTip() async {
    setState(() => _widgetTip = false);
    await Store.instance.setSetting('widget_tip_done', '1');
  }

  @override
  void dispose() {
    Store.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final pool = await Store.instance.dailyPool();
    Quote? random = _random;
    if (random != null) {
      // обновить отметку «избранное» у случайной цитаты
      random = await Store.instance.quote(random.id);
    }
    if (!mounted) return;
    setState(() {
      _ordered = Daily.order(pool);
      _random = random;
      _loading = false;
    });
  }

  DateTime get _day {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + _offset);
  }

  void _shift(int d) => setState(() {
        _offset += d;
        _random = null;
      });

  void _pickRandom() {
    if (_ordered.isEmpty) return;
    setState(() => _random = _ordered[_rnd.nextInt(_ordered.length)]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final quote = _random ?? Daily.forDay(_ordered, _day);
    if (quote == null) {
      return const EmptyHint(
          icon: Icons.menu_book_outlined,
          text: 'Нет мыслей. Включите источники или добавьте свои '
              'на вкладке «Источники».');
    }
    final dayLabel = _random != null
        ? 'Случайная мысль'
        : _offset == 0
            ? 'Сегодня'
            : _offset == -1
                ? 'Вчера'
                : _offset == 1
                    ? 'Завтра'
                    : formatWeekday(_day);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 300) _shift(-1);
        if (v < -300) _shift(1);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(children: [
            IconButton(
              tooltip: 'Предыдущий день',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(children: [
                Text(dayLabel.toUpperCase(),
                    style: TextStyle(
                        letterSpacing: 2,
                        fontSize: 12.5,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${formatDate(_day)}, ${formatWeekday(_day)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15)),
                if (Store.instance.streak > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '🔥 ${pluralDays(Store.instance.streak)} подряд',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
              ]),
            ),
            IconButton(
              tooltip: 'Следующий день',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 14),
          Card(
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: scheme.secondary.withValues(alpha: 0.55), width: 1),
              ),
              child: Column(children: [
                const Ornament(),
                const SizedBox(height: 22),
                QuoteText(quote: quote),
                const SizedBox(height: 18),
                const Ornament(width: 120),
                const SizedBox(height: 6),
                QuoteActions(quote: quote, onChanged: _reload),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickRandom,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Ещё мысль'),
              ),
              if (_offset != 0 || _random != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _offset = 0;
                    _random = null;
                  }),
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('К сегодняшнему'),
                ),
            ],
          ),
          if (_widgetTip) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.widgets_outlined, color: scheme.secondary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Мысль дня на рабочем столе',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                          tooltip: 'Скрыть',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _closeWidgetTip),
                    ]),
                    Text(
                      'Виджет показывает сегодняшнюю мысль прямо на экране '
                      'телефона — даже не открывая приложение.',
                      style: TextStyle(
                          fontSize: 13.5, color: scheme.onSurfaceVariant),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Native.pinWidget();
                          await _closeWidgetTip();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить виджет'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'В подборке ${pluralThoughts(_ordered.length)}. Каждый день — новая, '
            'пока не будут прочитаны все.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                fontFamily: uiFont,
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
