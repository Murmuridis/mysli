import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'native.dart';
import 'screens/browse.dart';
import 'screens/edit.dart';
import 'screens/feed.dart';
import 'screens/journal.dart';
import 'screens/onboarding.dart';
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
          home: const _Start(),
        );
      },
    );
  }
}

/// При первом запуске — знакомство, потом главный экран.
class _Start extends StatefulWidget {
  const _Start();

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  late bool _onboarded = Store.instance.setting('onboarded') == '1';

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) {
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    }
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  int _mine = 0; // 0 — избранное, 1 — дневник

  static const _titles = [
    'Мудрые мысли',
    'Лента',
    'Обзор',
    'Моё',
    'Источники',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.instance.markVisit();
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
      // обновить «мысль дня», серию дней и расписание напоминаний.
      setState(() {});
      Store.instance.markVisit();
      Reminder.sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = switch (_tab) {
      0 => const TodayScreen(),
      1 => const FeedScreen(),
      2 => const BrowseScreen(),
      3 => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.favorite_border),
                    label: Text('Избранное')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.edit_note),
                    label: Text('Дневник')),
              ],
              selected: {_mine},
              onSelectionChanged: (v) => setState(() => _mine = v.first),
            ),
          ),
          Expanded(
            child: _mine == 0
                ? const QuotesScreen(key: ValueKey('fav'), favoritesOnly: true)
                : const JournalScreen(),
          ),
        ]),
      _ => const SourcesScreen(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        leadingWidth: 48,
        leading: Center(child: QuoteMark(size: 24, color: scheme.secondary)),
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
        3 when _mine == 0 => FloatingActionButton(
            tooltip: 'Добавить свою мысль',
            onPressed: () => editQuote(context),
            child: const Icon(Icons.add),
          ),
        4 => FloatingActionButton.extended(
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
      bottomNavigationBar: MediaQuery(
        // Подписи меню не увеличиваем вместе с системным шрифтом,
        // иначе «Источники» переносятся по буквам.
        data: MediaQuery.of(context).copyWith(
          textScaler:
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.0),
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
                icon: Icon(Icons.swipe_up_outlined),
                selectedIcon: Icon(Icons.swipe_up),
                label: 'Лента'),
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Обзор'),
            NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Моё'),
            NavigationDestination(
                icon: Icon(Icons.local_library_outlined),
                selectedIcon: Icon(Icons.local_library),
                label: 'Источники'),
          ],
        ),
      ),
    );
  }
}
