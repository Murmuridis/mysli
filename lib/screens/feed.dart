import 'dart:math';

import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../topics.dart';
import '../widgets.dart';
import 'journal.dart';
import 'share_card.dart';

/// Лента: мысли одна за другой во весь экран, листаются вверх.
/// Двойное касание — в избранное. Сверху — выбор темы.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Quote> _all = [];
  List<Quote> _items = [];
  String? _topic;
  bool _loading = true;
  int _seed = Random().nextInt(1 << 30);
  final _page = PageController();
  int _index = 0;
  int? _heartFor; // показать большое сердечко над этой цитатой

  @override
  void initState() {
    super.initState();
    _topic = Store.instance.setting('feed_topic').isEmpty
        ? null
        : Store.instance.setting('feed_topic');
    Store.instance.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    Store.instance.removeListener(_refresh);
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await Store.instance.allForLang();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
      _apply(resetPosition: true);
    });
  }

  /// После изменения в базе (избранное) — обновить цитаты, не теряя места.
  Future<void> _refresh() async {
    final all = await Store.instance.allForLang();
    if (!mounted) return;
    final byId = {for (final q in all) q.id: q};
    setState(() {
      final langChanged = all.length != _all.length;
      _all = all;
      if (langChanged) {
        _apply(resetPosition: true);
      } else {
        _items = [for (final q in _items) byId[q.id] ?? q];
      }
    });
  }

  void _apply({bool resetPosition = false}) {
    final t = _topic == null ? null : topicById(_topic!);
    final list = t == null ? List.of(_all) : _all.where(t.matches).toList();
    list.shuffle(Random(_seed));
    _items = list;
    if (resetPosition) {
      _index = 0;
      if (_page.hasClients) _page.jumpToPage(0);
    }
  }

  void _setTopic(String? id) {
    setState(() {
      _topic = id;
      _seed = Random().nextInt(1 << 30);
      _apply(resetPosition: true);
    });
    Store.instance.setSetting('feed_topic', id ?? '');
  }

  Future<void> _like(Quote q) async {
    setState(() => _heartFor = q.id);
    if (!q.favorite) await Store.instance.setFavorite(q.id, true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _heartFor = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final style = cardStyles[_index % cardStyles.length];
    return Stack(children: [
      PageView.builder(
        controller: _page,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _FeedPage(
          quote: _items[i],
          style: cardStyles[i % cardStyles.length],
          heart: _heartFor == _items[i].id,
          onDoubleTap: () => _like(_items[i]),
          first: i == 0,
        ),
      ),
      if (_items.isEmpty)
        const EmptyHint(
            icon: Icons.search_off,
            text: 'В этой теме пока нет мыслей на выбранном языке.'),
      // Темы — сверху, поверх ленты.
      Positioned(
        left: 0,
        right: 0,
        top: 8,
        child: SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _TopicChip(
                  label: 'Все',
                  selected: _topic == null,
                  style: style,
                  onTap: () => _setTopic(null)),
              for (final t in topics)
                _TopicChip(
                    label: t.name,
                    icon: t.icon,
                    selected: _topic == t.id,
                    style: style,
                    onTap: () => _setTopic(t.id)),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final CardStyle style;
  final VoidCallback onTap;
  const _TopicChip(
      {required this.label,
      this.icon,
      required this.selected,
      required this.style,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? style.bg.last : style.text;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected
            ? style.accent
            : style.text.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13, color: fg, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  final Quote quote;
  final CardStyle style;
  final bool heart;
  final bool first;
  final VoidCallback onDoubleTap;
  const _FeedPage(
      {required this.quote,
      required this.style,
      required this.heart,
      required this.first,
      required this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    final len = quote.text.length;
    final size = (len < 90
            ? 30.0
            : len < 180
                ? 25.0
                : len < 300
                    ? 21.0
                    : 18.5) *
        textScale();
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: style.bg),
        ),
        child: SafeArea(
          top: false,
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 64, 28, 96),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    QuoteMark(size: 34, color: style.accent),
                    const SizedBox(height: 22),
                    Text(
                      quote.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: style.sans ? uiFont : quoteFont,
                        fontSize: size,
                        height: 1.4,
                        color: style.text,
                      ),
                    ),
                    if (quote.author.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Container(width: 36, height: 1.2, color: style.accent),
                      const SizedBox(height: 10),
                      Text(
                        quote.author,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: quoteFont,
                            fontStyle: FontStyle.italic,
                            fontSize: 17,
                            color: style.accent),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
            // Действия внизу
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                    tooltip:
                        quote.favorite ? 'Убрать из избранного' : 'В избранное',
                    icon: Icon(
                        quote.favorite ? Icons.favorite : Icons.favorite_border,
                        color: style.accent),
                    onPressed: () =>
                        Store.instance.setFavorite(quote.id, !quote.favorite),
                  ),
                  IconButton(
                    tooltip: 'Поделиться',
                    icon: Icon(Icons.share_outlined, color: style.text),
                    onPressed: () => shareQuote(context, quote),
                  ),
                  SpeakButton(quote: quote, color: style.text),
                  IconButton(
                    tooltip: 'Размышление',
                    icon: Icon(Icons.edit_note, color: style.text),
                    onPressed: () => reflect(context, quote),
                  ),
                ]),
                if (first)
                  Text('листайте вверх ↑',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          color: style.text.withValues(alpha: 0.55))),
              ]),
            ),
            if (heart)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.scale(scale: v, child: child),
                  ),
                  child: Icon(Icons.favorite,
                      size: 110, color: style.accent.withValues(alpha: 0.9)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
