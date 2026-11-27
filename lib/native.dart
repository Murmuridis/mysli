import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'daily.dart';
import 'store.dart';

/// Мостик к Android-части (MainActivity.kt и соседние файлы):
/// «Поделиться» (текстом и картинкой), открытие ссылок, ежедневное
/// напоминание и резервная копия.
/// Всё это сделано без сторонних плагинов, чтобы сборка не зависела
/// от их версий.
class Native {
  static const _ch = MethodChannel('mysli/native');

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> share(String text) => _call<void>('share', text);

  /// Поделиться картинкой PNG (карточка с цитатой). Текст идёт подписью.
  static Future<bool> shareImage(Uint8List png, String text) async =>
      (await _call<bool>('shareImage', {'png': png, 'text': text})) ?? false;

  static Future<bool> openUrl(String url) async =>
      (await _call<bool>('openUrl', url)) ?? false;

  /// Просит разрешение на уведомления (Android 13+). true — можно показывать.
  static Future<bool> requestNotificationPermission() async =>
      (await _call<bool>('requestNotificationPermission')) ?? false;

  static Future<bool> notificationsEnabled() async =>
      (await _call<bool>('notificationsEnabled')) ?? false;

  // ---------- Озвучка ----------

  static Future<void> speak(String text, {required bool russian}) =>
      _call<void>('speak', {'text': text, 'ru': russian});
  static Future<void> speakStop() => _call<void>('speakStop');

  /// stopped | speaking | no_voice
  static Future<String> speakState() async =>
      (await _call<String>('speakState')) ?? 'stopped';

  // ---------- Виджет ----------

  /// Можно ли добавить виджет на рабочий стол прямо из приложения.
  static Future<bool> widgetSupported() async =>
      (await _call<bool>('widgetSupported')) ?? false;

  static Future<bool> pinWidget() async =>
      (await _call<bool>('pinWidget')) ?? false;

  // ---------- Файлы ----------

  /// Спросить, куда сохранить файл. Возвращает адрес (content://…) или null.
  static Future<String?> createDocument(String name, String mime) =>
      _call<String>('createDocument', {'name': name, 'mime': mime});

  /// Выбрать файл. Возвращает адрес (content://…) или null.
  static Future<String?> openDocument() => _call<String>('openDocument');

  /// Записать резервную копию. Возвращает текст ошибки или null.
  static Future<String?> writeBackup(String uri, String dbPath) async {
    final r = await _call<String>('writeBackup', {'uri': uri, 'db': dbPath});
    if (r == null) return 'Не удалось сохранить копию';
    return r.isEmpty ? null : r;
  }

  /// Проверить файл копии: {ok, error, media, created}.
  static Future<Map<Object?, Object?>> checkBackup(String uri) async =>
      (await _call<Map<Object?, Object?>>('checkBackup', uri)) ??
      {'ok': false, 'error': 'Не удалось прочитать файл'};

  /// Восстановить копию (база должна быть закрыта). Текст ошибки или null.
  static Future<String?> restoreBackup(String uri, String dbPath) async {
    final r =
        await _call<String>('restoreBackup', {'uri': uri, 'db': dbPath});
    if (r == null) return 'Не удалось восстановить копию';
    return r.isEmpty ? null : r;
  }

}

/// Напоминания и виджет.
///
/// Android сам будит приложение в выбранное время и показывает уведомление.
/// Чтобы в уведомлении и в виджете была именно сегодняшняя цитата, туда
/// заранее передаются цитаты на ближайшие 60 дней (на каждый день — мысль
/// дня и ещё две для второго и третьего напоминания); при каждом открытии
/// приложения список обновляется.
class Reminder {
  static const daysAhead = 60;
  static const maxTimes = 3;
  static Timer? _debounce;

  static bool get enabled => Store.instance.setting('reminder_on', '0') == '1';

  /// Время напоминаний в минутах от полуночи, по возрастанию.
  static List<int> get times {
    final raw = Store.instance.setting('reminder_times', '480');
    final list = raw
        .split(',')
        .map((x) => int.tryParse(x.trim()))
        .whereType<int>()
        .where((m) => m >= 0 && m < 24 * 60)
        .toSet()
        .toList()
      ..sort();
    return list.isEmpty ? [480] : list.take(maxTimes).toList();
  }

  static Future<void> setTimes(List<int> t) async {
    final list = t.toSet().toList()..sort();
    await Store.instance
        .setSetting('reminder_times', list.take(maxTimes).join(','));
    await sync();
  }

  static String fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  /// Пересчитать расписание через пару секунд (после серии изменений).
  static void syncSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), sync);
  }

  static Future<void> sync() async {
    try {
      await _sync();
    } catch (_) {
      // База может быть временно закрыта (резервная копия) — пересчитаем позже.
    }
  }

  static Future<void> _sync() async {
    final ordered = Daily.order(await Store.instance.dailyPool());
    final today = DateTime.now();
    final map = <String, List<Map<String, String>>>{};
    final n = ordered.length;
    for (var i = 0; i < daysAhead && n > 0; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final day = Daily.dayNumber(d);
      map[_key(d)] = [
        for (var slot = 0; slot < maxTimes; slot++)
          () {
            // Дополнительные цитаты берутся из другой части перемешанного
            // списка, чтобы не совпадать с мыслью ближайших дней.
            final q = ordered[(day + slot * (n ~/ maxTimes + 7)) % n];
            return {'t': q.text, 'a': q.author};
          }(),
      ];
    }
    await Native._call<void>('saveQuotes', jsonEncode(map));
    if (!enabled) {
      await Native._call<void>('cancelReminder');
      return;
    }
    await Native._call<void>('scheduleReminder', times);
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
