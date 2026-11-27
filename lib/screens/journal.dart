import 'package:flutter/material.dart';

import '../daily.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'quotes.dart';

/// Вопросы для размышления — меняются день ото дня.
const _prompts = [
  'Что эта мысль значит для вас сегодня?',
  'Где в вашей жизни это уже было правдой?',
  'Согласны ли вы? Почему?',
  'Что можно сделать сегодня, помня об этой мысли?',
  'Кому из близких стоило бы это услышать?',
  'Что бы вы возразили автору?',
  'Какой случай из жизни приходит на ум?',
];

String promptFor(Quote q) => _prompts[q.id % _prompts.length];

/// Окно «Размышление»: записать свои мысли о цитате в дневник.
Future<void> reflect(BuildContext context, Quote quote) async {
  final old = await Store.instance.noteFor(quote.id);
  if (!context.mounted) return;
  final ctrl = TextEditingController(text: old?.text ?? '');
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) {
      final scheme = Theme.of(c).colorScheme;
      return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              quote.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: quoteFont,
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(promptFor(quote),
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: scheme.primary)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'Несколько строк — для себя'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (old != null)
                TextButton.icon(
                  onPressed: () {
                    ctrl.clear();
                    Navigator.pop(c, true);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить'),
                ),
              const Spacer(),
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Отмена')),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Сохранить')),
            ]),
          ],
        ),
      );
    },
  );
  if (saved == true) {
    await Store.instance.saveNote(quote.id, ctrl.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ctrl.text.trim().isEmpty
              ? 'Запись удалена'
              : 'Записано в дневник')));
    }
  }
}

/// Дневник: все размышления, новые сверху.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Note> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Store.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    Store.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final n = await Store.instance.notes();
    if (mounted) {
      setState(() {
        _items = n;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const EmptyHint(
        icon: Icons.edit_note,
        text: 'Здесь будут ваши размышления. Нажмите ✎ под любой мыслью '
            'и запишите, что она значит для вас.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final n = _items[i];
        final q = n.quote;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: q == null ? null : () => reflect(context, q),
            onLongPress: q == null ? null : () => showQuoteSheet(context, q.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatDate(n.created),
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: scheme.primary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (q != null)
                    Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(
                                  color: scheme.secondary, width: 2))),
                      child: Text(
                        q.author.isEmpty ? q.text : '${q.text} — ${q.author}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: quoteFont,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(n.text, style: const TextStyle(fontSize: 15.5, height: 1.35)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
