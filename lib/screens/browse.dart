import 'package:flutter/material.dart';

import '../daily.dart';
import '../store.dart';
import '../topics.dart';
import 'quotes.dart';

/// «Обзор»: поиск, темы и авторы.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();
  Map<String, int> _topicCounts = {};
  List<MapEntry<String, int>> _authors = [];
  int _total = 0;
  bool _allAuthors = false;
  bool _loading = true;
  String _lang = '';

  @override
  void initState() {
    super.initState();
    Store.instance.addListener(_maybeReload);
    _reload();
  }

  @override
  void dispose() {
    Store.instance.removeListener(_maybeReload);
    _search.dispose();
    super.dispose();
  }

  void _maybeReload() {
    // Пересчитывать только при смене языка — подсчёт не бесплатный.
    if (Store.instance.lang != _lang) _reload();
  }

  Future<void> _reload() async {
    _lang = Store.instance.lang;
    final all = await Store.instance.allForLang();
    final tc = <String, int>{for (final t in topics) t.id: 0};
    final ac = <String, int>{};
    for (final q in all) {
      for (final t in topics) {
        if (t.matches(q)) tc[t.id] = tc[t.id]! + 1;
      }
      if (q.author.isNotEmpty) ac[q.author] = (ac[q.author] ?? 0) + 1;
    }
    final authors = ac.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (!mounted) return;
    setState(() {
      _topicCounts = tc;
      _authors = authors;
      _total = all.length;
      _loading = false;
    });
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _doSearch(String text) {
    if (text.trim().isEmpty) return;
    _open(QuoteListPage(title: 'Поиск', search: text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    Widget header(String t, [Widget? trailing]) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(children: [
            Expanded(
              child: Text(t,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary)),
            ),
            if (trailing != null) trailing,
          ]),
        );
    final authors = _allAuthors ? _authors : _authors.take(12).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: _doSearch,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Поиск по тексту и автору',
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _doSearch(_search.text),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('Все мысли'),
            subtitle: Text(pluralThoughts(_total)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(const QuoteListPage(title: 'Все мысли')),
          ),
        ),
        header('Темы'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: [
            for (final t in topics)
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () =>
                      _open(QuoteListPage(title: t.name, topic: t.id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Icon(t.icon, color: scheme.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15)),
                            Text('${_topicCounts[t.id] ?? 0}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        header(
          'Авторы',
          _authors.length > 12
              ? TextButton(
                  onPressed: () => setState(() => _allAuthors = !_allAuthors),
                  child: Text(_allAuthors ? 'Свернуть' : 'Все (${_authors.length})'),
                )
              : null,
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < authors.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 56),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  foregroundColor: scheme.primary,
                  child: Text(_initials(authors[i].key)),
                ),
                title: Text(authors[i].key),
                trailing: Text('${authors[i].value}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                onTap: () => _open(QuoteListPage(
                    title: authors[i].key, author: authors[i].key)),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'[«»"()]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w[0].toUpperCase() == w[0])
        .toList();
    if (parts.isEmpty) return name.isEmpty ? '?' : name[0];
    final last = parts.last;
    return (parts.length > 1 ? parts.first[0] : '') + last[0];
  }
}
