import 'package:flutter/material.dart';

import 'store.dart';

/// Язык цитаты: если есть кириллица — русская, иначе английская.
bool isRussian(String text) => RegExp(r'[А-Яа-яЁё]').hasMatch(text);

/// Тема — набор основ слов на русском и английском.
/// Темы определяются по тексту цитаты, поэтому работают и для
/// добавленных вручную.
class Topic {
  final String id;
  final String name;
  final IconData icon;
  final RegExp? ru;
  final RegExp? en;
  final Set<String> authors; // все цитаты этих авторов попадают в тему
  Topic(this.id, this.name, this.icon,
      {String? ru, String? en, this.authors = const {}})
      : ru = ru == null
            ? null
            : RegExp('(?<![а-яё])($ru)', caseSensitive: false, unicode: true),
        en = en == null
            ? null
            : RegExp(r'\b(' + en + r')', caseSensitive: false);

  bool matches(Quote q) {
    if (authors.contains(q.author)) return true;
    final re = isRussian(q.text) ? ru : en;
    return re != null && re.hasMatch(q.text);
  }
}

final topics = <Topic>[
  Topic('happiness', 'Счастье и радость', Icons.wb_sunny_outlined,
      ru: 'счаст|радост|радуе|блажен|весел',
      en: 'happ|joy|delight|cheerful|merry'),
  Topic('love', 'Любовь', Icons.favorite_border,
      ru: 'любов|любв|любит|любим|любящ|возлюб|нежн',
      en: 'love|lover|beloved|loving'),
  Topic('friends', 'Дружба', Icons.people_outline,
      ru: 'друг|дружб|друж', en: 'friend'),
  Topic('wisdom', 'Мудрость и ум', Icons.psychology_outlined,
      ru: 'мудр|умн|ум[ае]?(?![а-яё])|умом|разум|рассуд|глуп|невежеств',
      en: 'wis(e|dom)|mind|reason|fool|folly|ignoran|understand'),
  Topic('truth', 'Истина и ложь', Icons.lightbulb_outline,
      ru: 'истин|правд|ложь|лжи|лжив|лгать|лжец|обман|искрен',
      en: 'truth|true|lie(s|d)?\\b|liar|false|deceit|honest|sincer'),
  Topic('virtue', 'Добро и зло', Icons.balance_outlined,
      ru: 'добр|зло(?![бв])|злы|зла(?![кт])|порок|добродетел|грех|совест',
      en: 'good(ness)?\\b|evil|virtu|vice|wicked|sin\\b|sins|conscience'),
  Topic('time', 'Время и жизнь', Icons.hourglass_empty,
      ru: 'врем|жизн|жить|живё|молод|старост|старик|будущ|прошл',
      en: 'time|life|live(s|d)?\\b|living|youth|old age|future|past|hour'),
  Topic('death', 'Смерть и вечность', Icons.spa_outlined,
      ru: 'смерт|умира|умрёт|умер|вечн|бессмерт',
      en: 'death|die(s|d)?\\b|dying|mortal|eternal|grave'),
  Topic('work', 'Труд и дело', Icons.construction_outlined,
      ru: 'труд|работ|усерд|лен[ьи]|ленив|прилеж|дело(?![вм])|дела(?![кт])',
      en: 'work|labou?r|diligen|industr|idle|lazy|sloth|deed|busy'),
  Topic('money', 'Богатство и бедность', Icons.savings_outlined,
      ru: 'богат|деньг|денег|бедн|скуп|нищ|золот|расточ',
      en: 'rich|wealth|money|poor|povert|gold|miser|spend|thrift|debt'),
  Topic('pride', 'Гордость и тщеславие', Icons.workspace_premium_outlined,
      ru: 'горд|тщеслав|самолюб|хвал|лест|льст|высокомер|смирен|скромн',
      en: 'pride|proud|vanit|vain|flatter|prais|humil|modest|conceit'),
  Topic('calm', 'Гнев и спокойствие', Icons.self_improvement,
      ru: 'гнев|терпен|терпел|спокой|страст|раздраж|ярост|кротк',
      en: 'anger|angry|patien|calm|passion|wrath|temper|tranquil'),
  Topic('knowledge', 'Знание и книги', Icons.menu_book_outlined,
      ru: 'знани|книг|учен|наук|чтени|читат|учит|образован',
      en: 'knowledge|learn|book|read|study|scien|educat|teach'),
  Topic('soul', 'Душа и вера', Icons.auto_awesome_outlined,
      ru: 'бог[аеуо]?(?![а-яё])|богом|душ[аеуи]|душой|вер[аеуы](?![а-яё])|верой|молит',
      en: 'god\\b|gods\\b|soul|faith|heaven|spirit|pray'),
  Topic('family', 'Семья и люди', Icons.home_outlined,
      ru: 'жен[аыуе]|жён|муж[аеу]?(?![а-яё])|брак|дет[иь]|детей|мать|матер|отец|отц|сосед',
      en: 'wife|husband|marri|child|mother|father|neighbou?r|family'),
  Topic('humor', 'С улыбкой', Icons.sentiment_satisfied_alt_outlined,
      authors: {'Козьма Прутков', 'Mark Twain', 'Oscar Wilde'}),
];

Topic? topicById(String id) {
  for (final t in topics) {
    if (t.id == id) return t;
  }
  return null;
}
