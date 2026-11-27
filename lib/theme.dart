import 'package:flutter/material.dart';

/// Цвета: тёплая бумага, тёмные чернила, глубокий сине-зелёный
/// и золото — как в старой библиотеке.
class Palette {
  static const parchment = Color(0xFFF5F1E8);
  static const parchmentDeep = Color(0xFFEAE3D3);
  static const card = Color(0xFFFCFAF4);
  static const ink = Color(0xFF232A33);
  static const inkSoft = Color(0xFF5E6672);
  static const cinnabar = Color(0xFF1F4E5F); // основной акцент
  static const gold = Color(0xFFB8893B);

  static const nightBg = Color(0xFF12171D);
  static const nightCard = Color(0xFF1A2129);
  static const nightInk = Color(0xFFE9E4D8);
  static const nightInkSoft = Color(0xFFA7ADB5);
  static const nightAccent = Color(0xFFD4A85A);
}

const quoteFont = 'OldStandard';
const uiFont = 'PTSerif';

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Palette.nightAccent,
          onPrimary: Palette.nightBg,
          secondary: Palette.gold,
          onSecondary: Palette.nightBg,
          surface: Palette.nightCard,
          onSurface: Palette.nightInk,
          surfaceContainerHighest: Color(0xFF242C36),
          onSurfaceVariant: Palette.nightInkSoft,
          outline: Color(0xFF3C4652),
          error: Color(0xFFE57368),
        )
      : const ColorScheme.light(
          primary: Palette.cinnabar,
          onPrimary: Colors.white,
          secondary: Palette.gold,
          onSecondary: Colors.white,
          surface: Palette.card,
          onSurface: Palette.ink,
          surfaceContainerHighest: Palette.parchmentDeep,
          onSurfaceVariant: Palette.inkSoft,
          outline: Color(0xFFD5CCB8),
          error: Color(0xFFB3261E),
        );
  final bg = dark ? Palette.nightBg : Palette.parchment;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: uiFont,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: quoteFont,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: 0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Компактное меню: 60 вместо стандартных 80.
      height: 60,
      backgroundColor: dark ? const Color(0xFF171D24) : Palette.parchmentDeep,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: uiFont, fontSize: 11, color: scheme.onSurface),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.5)),
  );
}
