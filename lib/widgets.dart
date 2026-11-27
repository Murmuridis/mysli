import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native.dart';
import 'screens/share_card.dart';
import 'store.dart';
import 'theme.dart';

/// Знак приложения: две кавычки «❝», нарисованные кругами с хвостиками.
class QuoteMark extends StatelessWidget {
  final double size;
  final Color? color;
  const QuoteMark({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.8),
      painter: _QuotePainter(color ?? Theme.of(context).colorScheme.secondary),
    );
  }
}

class _QuotePainter extends CustomPainter {
  final Color color;
  _QuotePainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    final r = s.width * 0.2;
    for (final cx in [s.width * 0.26, s.width * 0.74]) {
      final c = Offset(cx, s.height - r * 1.15);
      canvas.drawCircle(c, r, p);
      // хвостик кавычки — вверх и вправо
      final path = Path()
        ..moveTo(c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx - r * 1.05, c.dy - r * 2.6, c.dx + r * 0.9,
            c.dy - r * 3.1)
        ..lineTo(c.dx + r * 0.95, c.dy - r * 2.55)
        ..quadraticBezierTo(c.dx - r * 0.1, c.dy - r * 2.1, c.dx + r * 0.2,
            c.dy - r * 0.6)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_QuotePainter old) => old.color != color;
}

/// Тонкая золотая черта с ромбиком посередине.
class Ornament extends StatelessWidget {
  final double width;
  const Ornament({super.key, this.width = 180});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.secondary;
    Widget line() => Expanded(
          child: Container(height: 1, color: c.withValues(alpha: 0.7)),
        );
    Widget diamond(double d) => Transform.rotate(
          angle: 0.785398,
          child: Container(width: d, height: d, color: c),
        );
    return SizedBox(
      width: width,
      child: Row(children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            diamond(3.5),
            const SizedBox(width: 6),
            diamond(6.5),
            const SizedBox(width: 6),
            diamond(3.5),
          ]),
        ),
        line(),
      ]),
    );
  }
}

double textScale() =>
    double.tryParse(Store.instance.setting('text_scale', '1.0')) ?? 1.0;

/// Красиво набранная цитата: буквица-кавычка, текст, автор.
class QuoteText extends StatelessWidget {
  final Quote quote;
  final double fontSize;
  final bool showSource;
  const QuoteText({
    super.key,
    required this.quote,
    this.fontSize = 23,
    this.showSource = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = fontSize * textScale();
    // Если автор уже в начале названия источника («Ларошфуко. Избранные
    // афоризмы» под «Франсуа де Ларошфуко») — повторять его не нужно.
    var source = quote.sourceName;
    if (quote.author.isNotEmpty && source.startsWith(quote.author)) {
      source = source
          .substring(quote.author.length)
          .replaceFirst(RegExp(r'^[\s.,:—–-]+'), '');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          quote.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: quoteFont,
            fontSize: size,
            height: 1.45,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        if (quote.author.isNotEmpty)
          Text(
            quote.author,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: quoteFont,
              fontStyle: FontStyle.italic,
              fontSize: size * 0.72,
              color: scheme.primary,
            ),
          ),
        if (showSource && source.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            source,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Действия с цитатой: избранное, поделиться, скопировать.
class QuoteActions extends StatelessWidget {
  final Quote quote;
  final VoidCallback? onChanged;
  final List<Widget> extra;
  const QuoteActions({
    super.key,
    required this.quote,
    this.onChanged,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: quote.favorite ? 'Убрать из избранного' : 'В избранное',
          icon: Icon(quote.favorite ? Icons.favorite : Icons.favorite_border,
              color: scheme.primary),
          onPressed: () async {
            await Store.instance.setFavorite(quote.id, !quote.favorite);
            onChanged?.call();
          },
        ),
        IconButton(
          tooltip: 'Поделиться',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => shareQuote(context, quote),
        ),
        IconButton(
          tooltip: 'Скопировать',
          icon: const Icon(Icons.copy_outlined),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: quote.shareText));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Цитата скопирована')));
            }
          },
        ),
        ...extra,
      ],
    );
  }
}

/// «Поделиться»: текстом или красивой карточкой-картинкой.
Future<void> shareQuote(BuildContext context, Quote quote) async {
  final how = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.notes),
          title: const Text('Текстом'),
          subtitle: const Text('В мессенджер, письмо, заметки'),
          onTap: () => Navigator.pop(c, 'text'),
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('Картинкой'),
          subtitle: const Text('Открытка с цитатой — можно выбрать оформление'),
          onTap: () => Navigator.pop(c, 'image'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (!context.mounted) return;
  if (how == 'text') {
    await Native.share(quote.shareText);
  } else if (how == 'image') {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ShareCardScreen(quote: quote)));
  }
}

/// Пустой экран с подсказкой.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyHint({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: c),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
        ]),
      ),
    );
  }
}
