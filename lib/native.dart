import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

/// Ежедневное напоминание.
///
/// Android сам будит приложение в выбранное время и показывает уведомление.
/// Чтобы в уведомлении была именно сегодняшняя цитата, сюда заранее
/// передаются цитаты на ближайшие 60 дней; при каждом открытии
/// приложения список обновляется.
class Reminder {
  static const daysAhead = 60;
  static Timer? _debounce;

  static bool get enabled => Store.instance.setting('reminder_on', '0') == '1';
  static int get hour =>
      int.tryParse(Store.instance.setting('reminder_hour', '8')) ?? 8;
  static int get minute =>
      int.tryParse(Store.instance.setting('reminder_minute', '0')) ?? 0;

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
    if (!enabled) {
      await Native._call<void>('cancelReminder');
      return;
    }
    final ordered = Daily.order(await Store.instance.dailyPool());
    final today = DateTime.now();
    final map = <String, Map<String, String>>{};
    for (var i = 0; i < daysAhead; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final q = Daily.forDay(ordered, d);
      if (q == null) break;
      map[_key(d)] = {'t': q.text, 'a': q.author};
    }
    await Native._call<void>('scheduleReminder', {
      'hour': hour,
      'minute': minute,
      'quotes': jsonEncode(map),
    });
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
