import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../native.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Оформление открытки.
class CardStyle {
  final String name;
  final List<Color> bg; // градиент сверху вниз
  final Color text;
  final Color accent;
  const CardStyle(this.name, this.bg, this.text, this.accent);
}

const cardStyles = [
  CardStyle('Ночь', [Color(0xFF1C2541), Color(0xFF0B132B)], Color(0xFFF1E9D8),
      Color(0xFFD4A85A)),
  CardStyle('Бумага', [Color(0xFFF7F1E3), Color(0xFFEADFC8)], Color(0xFF2A2420),
      Color(0xFF1F4E5F)),
  CardStyle('Олива', [Color(0xFF3D4A2E), Color(0xFF232B1A)], Color(0xFFF2EEDC),
      Color(0xFFD9C27A)),
  CardStyle('Закат', [Color(0xFF7A3B2E), Color(0xFF3B1F2B)], Color(0xFFFBEFE3),
      Color(0xFFF2C38B)),
];

/// Открытка с цитатой: выбор оформления и «Поделиться картинкой».
class ShareCardScreen extends StatefulWidget {
  final Quote quote;
  const ShareCardScreen({super.key, required this.quote});

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  int _style = int.tryParse(Store.instance.setting('card_style', '0')) ?? 0;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 1080 пикселей по ширине — как у обычной картинки для мессенджеров.
      final ratio = 1080 / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('png');
      final ok = await Native.shareImage(
          data.buffer.asUint8List(), widget.quote.shareText);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не получилось поделиться картинкой')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не получилось сделать картинку')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = cardStyles[_style.clamp(0, cardStyles.length - 1)];
    return Scaffold(
      appBar: AppBar(title: const Text('Открытка')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // Карточка всегда квадратная и не зависит от размера шрифта
          // в настройках телефона — чтобы картинка выглядела одинаково.
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: RepaintBoundary(
              key: _key,
              child: AspectRatio(
                aspectRatio: 1,
                child: QuoteCard(quote: widget.quote, style: st),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < cardStyles.length; i++)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: cardStyles[i].bg.first),
                  label: Text(cardStyles[i].name),
                  selected: i == _style,
                  onSelected: (_) {
                    setState(() => _style = i);
                    Store.instance.setSetting('card_style', '$i');
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: const Text('Поделиться картинкой'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Native.share(widget.quote.shareText),
            icon: const Icon(Icons.notes),
            label: const Text('Поделиться текстом'),
          ),
        ],
      ),
    );
  }
}

/// Сама открытка. Размер шрифта подбирается под длину цитаты.
class QuoteCard extends StatelessWidget {
  final Quote quote;
  final CardStyle style;
  const QuoteCard({super.key, required this.quote, required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final len = quote.text.length;
      final k = len < 80
          ? 0.075
          : len < 160
              ? 0.062
              : len < 260
                  ? 0.052
                  : len < 380
                      ? 0.045
                      : 0.039;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.03),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.bg,
          ),
        ),
        padding: EdgeInsets.all(w * 0.07),
        child: Column(children: [
          Align(
            alignment: Alignment.topLeft,
            child: QuoteMark(
                size: w * 0.11, color: style.accent.withValues(alpha: 0.9)),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: w * 0.86,
                  child: Text(
                    quote.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: quoteFont,
                      fontSize: w * k,
                      height: 1.38,
                      color: style.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (quote.author.isNotEmpty) ...[
            Container(
                width: w * 0.12,
                height: 1.2,
                color: style.accent.withValues(alpha: 0.8)),
            SizedBox(height: w * 0.025),
            Text(
              quote.author,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: quoteFont,
                fontStyle: FontStyle.italic,
                fontSize: w * 0.042,
                color: style.accent,
              ),
            ),
          ],
          SizedBox(height: w * 0.035),
          Text(
            'МУДРЫЕ МЫСЛИ',
            style: TextStyle(
              fontFamily: uiFont,
              fontSize: w * 0.024,
              letterSpacing: w * 0.006,
              color: style.text.withValues(alpha: 0.45),
            ),
          ),
        ]),
      );
    });
  }
}
