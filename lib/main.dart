import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'native.dart';
import 'screens/edit.dart';
import 'screens/quotes.dart';
import 'screens/settings.dart';
import 'screens/sources.dart';
import 'screens/today.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.open();
  Store.instance.addListener(Reminder.syncSoon);
  Reminder.sync();
  runApp(const MysliApp());
}

class MysliApp extends StatelessWidget {
  const MysliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final mode = switch (Store.instance.setting('theme', 'system')) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          title: 'Мудрые мысли',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;

  static const _titles = [
    'Мудрые мысли',
    'Все мысли',
    'Избранное',
    'Источники',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Наступил новый день или приложение долго не открывали —
      // обновить «мысль дня» и расписание напоминаний.
      setState(() {});
      Reminder.sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => const TodayScreen(),
      1 => const QuotesScreen(key: ValueKey('all')),
      2 => const QuotesScreen(key: ValueKey('fav'), favoritesOnly: true),
      _ => const SourcesScreen(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        leadingWidth: 48,
        leading: const Center(child: QuoteMark(size: 24)),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: body,
      floatingActionButton: switch (_tab) {
        1 => FloatingActionButton(
            tooltip: 'Добавить цитату',
            onPressed: () => editQuote(context),
            child: const Icon(Icons.add),
          ),
        3 => FloatingActionButton.extended(
            onPressed: () async {
              final id = await editSource(context);
              if (id != null && context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SourceScreen(sourceId: id)));
              }
            },
            icon: const Icon(Icons.add_link),
            label: const Text('Источник'),
          ),
        _ => null,
      },
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Подписи меню не увеличиваем вместе с системным шрифтом,
          // иначе «Избранное» и «Источники» переносятся по буквам.
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.0),
            ),
            child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny),
                  label: 'Сегодня'),
              NavigationDestination(
                  icon: Icon(Icons.format_quote_outlined),
                  selectedIcon: Icon(Icons.format_quote),
                  label: 'Мысли'),
              NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Избранное'),
              NavigationDestination(
                  icon: Icon(Icons.local_library_outlined),
                  selectedIcon: Icon(Icons.local_library),
                  label: 'Источники'),
            ],
          ),
          ),
        ],
      ),
    );
  }
}
