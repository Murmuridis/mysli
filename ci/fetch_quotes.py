#!/usr/bin/env python3
"""Собирает встроенную подборку цитат для «Мудрых мыслей».

Тексты берутся из Викитеки (ru.wikisource.org) — это книги в общественном
достоянии: сборники «Избранных мыслей» издательства «Посредник» (1908,
под редакцией Л. Н. Толстого), «Круг чтения» Толстого, Марк Аврелий,
Эпиктет, Козьма Прутков. Кроме того, в подборку попадают источники-ссылки
(книги и сайты), из которых цитаты не выгружаются, — их можно открыть
в приложении и добавить оттуда цитаты вручную.

Запуск:  python3 ci/fetch_quotes.py [--if-missing] [--out assets/data/quotes.json]
Нужен только стандартный Python 3.
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://ru.wikisource.org/w/api.php"
WS = "https://ru.wikisource.org/wiki/"
UA = "MudryeMysliBot/1.0 (https://github.com/Murmuridis/mysli; quotes for a personal app)"


def ws_url(title):
    return WS + urllib.parse.quote(title.replace(" ", "_"), safe="/(),_")


# ---------------------------------------------------------------- источники
# mode: numbered — записи разделены номерами (1, 2, 3…), текст до первого номера
#                  (предисловие, биография) пропускается;
#       blocks   — как numbered, но без пропуска начала и с разделителем {{***}}
#                  («Круг чтения»), автор берётся из {{right|…}};
#       paras    — каждый абзац — отдельная мысль (Марк Аврелий, Эпиктет).
SOURCES = [
    dict(k="krug", n="Круг чтения", author="",
         d="Л. Н. Толстой. Мысли многих писателей, собранные на каждый день (1906). "
           "На Викитеке выложены не все дни.",
         titles="prefix:Круг чтения (Толстой)/", depth=3, mode="blocks", maxlen=520,
         u=ws_url("Круг чтения (Толстой)")),
    dict(k="laroshfuko", n="Ларошфуко. Избранные афоризмы и максимы",
         author="Франсуа де Ларошфуко",
         d="Перевод Г. А. Русанова. Изд. «Посредник», 1908",
         titles=["Избранные афоризмы и максимы (Ларошфуко)"], mode="numbered", maxlen=520),
    dict(k="vovenarg", n="Вовенарг. Избранные афоризмы и максимы",
         author="Люк де Вовенарг",
         d="Перевод Г. А. Русанова. Изд. «Посредник», 1908",
         titles=["Избранные афоризмы и максимы (Вовенарг)"], mode="numbered", maxlen=520),
    dict(k="labruyer", n="Лабрюйер. Избранные мысли", author="Жан де Лабрюйер",
         d="Перевод Г. А. Русанова, предисловие Л. Н. Толстого. Изд. «Посредник», 1908",
         titles=["Избранные мысли Лабрюйера, (Лабрюйер)"], mode="numbered", maxlen=480,
         # В конце книги — приложение с Ларошфуко, Вовенаргом и Монтескьё:
         # они есть отдельными источниками.
         stop=r"Ларошфуко|Вовенарг|Монтескь"),
    dict(k="montesquieu", n="Монтескьё. Избранные мысли", author="Шарль Монтескьё",
         d="Перевод Г. А. Русанова. Изд. «Посредник», 1908",
         titles=["Избранные мысли Монтескье (Монтескье)"], mode="numbered", maxlen=520),
    dict(k="ruskin", n="Джон Рёскин. Избранные мысли", author="Джон Рёскин",
         d="Изд. «Посредник», 1908",
         titles=["Избранные мысли Джона Рёскина (Рёскин)"], mode="numbered", maxlen=450),
    dict(k="epiktet", n="Эпиктет. Афоризмы", author="Эпиктет",
         d="Перевод В. Г. Алексеева. СПб.: А. С. Суворин, 1891",
         titles=["Афоризмы (Эпиктет)"], mode="paras", maxlen=420),
    dict(k="mark", n="Марк Аврелий. Наедине с собой", author="Марк Аврелий",
         d="Перевод С. М. Роговина, 1914. Книга первая (благодарности) не включена.",
         titles="prefix:Наедине с собой (Марк Аврелий; Роговин)/Книга ", exclude=r"/Книга 1$",
         mode="paras", maxlen=420, u=ws_url("Наедине с собой (Марк Аврелий; Роговин)")),
    dict(k="prutkov", n="Козьма Прутков. Плоды раздумья", author="Козьма Прутков",
         d="Мысли и афоризмы (1854—1860) — с улыбкой",
         titles=["Мысли и афоризмы I (Прутков)", "Мысли и афоризмы II (Прутков)"],
         mode="numbered", maxlen=420, u=ws_url("Мысли и афоризмы I (Прутков)")),
]

# Книги и сайты без выгрузки цитат: ссылки для чтения и ручного пополнения.
LINKS = [
    dict(k="l_tolstoy_mysli", n="Л. Н. Толстой. Мысли мудрых людей на каждый день",
         u="https://books.yandex.ru/books/KsggDWUY/read-online",
         d="1903. Первый «календарь мудрости» Толстого: мысль на каждый день года. "
           "Бесплатно открыта часть книги."),
    dict(k="l_tolstoy_krug1", n="Л. Н. Толстой. Круг чтения, том 1 (PDF)",
         u="https://tolstoy.ru/upload/iblock/6ed/6ed42deff8dbe5a00a03c6cb894261ef.pdf",
         d="Полное собрание сочинений, т. 41. Проект «Весь Толстой в один клик»"),
    dict(k="l_tolstoy_krug2", n="Л. Н. Толстой. Круг чтения, том 2 (PDF)",
         u="https://tolstoy.ru/upload/iblock/0af/0af7bbf06557c6f32a5645e6ce05ce76.pdf",
         d="Полное собрание сочинений, т. 42"),
    dict(k="l_tolstoy_kazhdy", n="Л. Н. Толстой. На каждый день (PDF)",
         u="https://tolstoy.ru/upload/iblock/bf7/bf7b861339ac22ff541662d0d140143d.pdf",
         d="Учение о жизни, изложенное в изречениях. ПСС, т. 43"),
    dict(k="l_tolstoy_site", n="Весь Толстой в один клик — tolstoy.ru",
         u="https://tolstoy.ru/creativity/90-volume-collection-of-the-works/",
         d="Полное собрание сочинений Толстого в 90 томах, бесплатно"),
    dict(k="l_wikiquote", n="Викицитатник",
         u="https://ru.wikiquote.org/",
         d="Свободная энциклопедия цитат с указанием источников"),
    dict(k="l_wikisource", n="Викитека — свободная библиотека",
         u="https://ru.wikisource.org/",
         d="Тексты в общественном достоянии, откуда взята встроенная подборка"),
    dict(k="l_shakespeare", n="Мысли Шекспира (изречения и афоризмы)",
         u=ws_url("Мысли Шекспира (Сальников)/ДО"),
         d="Сост. А. Н. Сальников, 1889 (дореформенная орфография)"),
    dict(k="l_azlib", n="Lib.ru: Классика",
         u="http://az.lib.ru/",
         d="Большая библиотека русской классики и старых переводов"),
    dict(k="l_gutenberg", n="Project Gutenberg",
         u="https://www.gutenberg.org/",
         d="Книги в общественном достоянии, в основном на английском"),
]


# ---------------------------------------------------------------- загрузка
def api(params, tries=4):
    params = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(params)
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # сеть Викитеки иногда отвечает не с первого раза
            if i == tries - 1:
                raise
            print(f"  повтор ({e})", file=sys.stderr)
            time.sleep(3 * (i + 1))


def prefix_titles(prefix):
    out, cont = [], {}
    while True:
        j = api(dict(action="query", list="allpages", aplimit="500", apprefix=prefix, **cont))
        out += [p["title"] for p in j["query"]["allpages"]]
        if "continue" not in j:
            return out
        cont = {"apcontinue": j["continue"]["apcontinue"]}


def wikitext(title):
    j = api(dict(action="query", prop="revisions", rvprop="content",
                 rvslots="main", titles=title))
    page = j["query"]["pages"][0]
    if "revisions" not in page:
        print(f"  нет страницы: {title}", file=sys.stderr)
        return ""
    return page["revisions"][0]["slots"]["main"]["content"]


# ---------------------------------------------------------------- разбор
AUTHOR_MARK = "\x01AUTHOR:"
SEP_MARK = "\x02SEP"


def strip_header(s):
    """Убрать шапку {{Отексте …}} — первый шаблон страницы."""
    s = s.lstrip()
    if not s.startswith("{{"):
        return s
    depth, i = 0, 0
    while i < len(s) - 1:
        two = s[i:i + 2]
        if two == "{{":
            depth += 1
            i += 2
            continue
        if two == "}}":
            depth -= 1
            i += 2
            if depth == 0:
                return s[i:]
            continue
        i += 1
    return s


def replace_templates(s):
    """Шаблоны {{…}}: автор справа — в метку автора, {{***}} — в разделитель,
    прочие — в последний позиционный параметр или в пустоту."""
    pat = re.compile(r"\{\{([^{}]*)\}\}")
    for _ in range(6):
        def repl(m):
            body = m.group(1)
            parts = [p.strip() for p in body.split("|")]
            name = parts[0].strip().lower()
            args = [p for p in parts[1:] if "=" not in p]
            # {{Библия|Мф|7:21|т=Мф., гл. 7, ст. 21}} — показываемый текст в «т=»
            named = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
            shown = (named.get("т") or named.get("текст") or "").strip()
            if shown:
                return shown
            if name in ("***", "* * *", "звёздочки", "звездочки", "---", "—"):
                return f"\n\n{SEP_MARK}\n\n"
            if name in ("right", "справа", "rs", "подпись", "r") and args:
                return f"\n{AUTHOR_MARK}{args[-1]}\n"
            if name in ("примечания", "references", "notes"):
                return ""
            if name.startswith("#") or not args:
                return ""
            return args[-1]
        new = pat.sub(repl, s)
        if new == s:
            break
        s = new
    return s


def clean(s):
    s = re.sub(r"<!--.*?-->", "", s, flags=re.S)
    s = re.sub(r"<ref[^>/]*/>", "", s)
    s = re.sub(r"<ref[^>]*>.*?</ref>", "", s, flags=re.S)
    s = re.sub(r"<sup>.*?</sup>", "", s, flags=re.S)
    s = re.sub(r"</?(onlyinclude|noinclude|includeonly)[^>]*>", "", s)
    s = replace_templates(s)
    # Автор в div справа: <div style="text-align:right">''Автор''</div>
    s = re.sub(r"<div[^>]*text-align: *right[^>]*>(.*?)</div>",
               lambda m: f"\n{AUTHOR_MARK}{m.group(1)}\n", s, flags=re.S | re.I)
    s = re.sub(r"<br\s*/?>", "\n", s)
    s = re.sub(r"</?(div|span|center|p|small|big|poem|blockquote|h\d|i|b|em|strong)[^>]*>", "\n", s, flags=re.I)
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"\[\[(?:Категория|Category|Файл|File|Изображение|Image):[^\]]*\]\]", "", s)
    s = re.sub(r"\[\[[^\]|]*\|([^\]]*)\]\]", r"\1", s)
    s = re.sub(r"\[\[([^\]]*)\]\]", r"\1", s)
    s = re.sub(r"\[https?://\S+ ([^\]]*)\]", r"\1", s)
    s = re.sub(r"\[\d+\]", "", s)  # сноски вида [1]
    s = s.replace("'''", "").replace("''", "")
    s = s.replace("&nbsp;", " ").replace("&#160;", " ").replace("&mdash;", "—")
    s = s.replace("&laquo;", "«").replace("&raquo;", "»").replace("&quot;", '"')
    s = s.replace(" ", " ")
    return s


HEADING = re.compile(r"^(=+)\s*(.*?)\s*\1\s*$")
NUMBER = re.compile(r"^[\(\[]?([IVXLC]+|\d+)[\.\)\]]?$")
NOTES = re.compile(r"^(Примечани|Комментари|Сноски|Notes)", re.I)


def tidy(t):
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r" *\n *", "\n", t)
    t = re.sub(r"\n{2,}", "\n", t)
    t = t.strip().strip("*").strip()
    t = re.sub(r"\s+([,.;:!?])", r"\1", t)
    return t


def tidy_author(a):
    a = tidy(a.replace("\n", " "))
    a = a.strip("—–- ").strip()
    a = re.sub(r"\s*\(.*?\)\s*$", "", a) if len(a) > 60 else a
    return a


def parse(text, mode, stop=None):
    """Возвращает список (текст, автор)."""
    lines = clean(strip_header(text)).split("\n")
    entries = []          # (текст, автор)
    cur, cur_author = [], ""
    started = mode != "numbered"
    stopped = False

    def flush():
        nonlocal cur, cur_author
        if cur and started:
            if mode == "paras":
                for p in cur:
                    entries.append((p, cur_author))
            else:
                entries.append(("\n".join(cur), cur_author))
        cur, cur_author = [], ""

    para = []

    def end_para():
        nonlocal para
        t = tidy(" ".join(para))
        para = []
        if t:
            cur.append(t)

    for raw in lines:
        line = raw.strip().lstrip(":").strip()
        if stopped:
            break
        if not line:
            end_para()
            continue
        h = HEADING.match(line)
        if h:
            title = h.group(2).strip()
            end_para()
            if NOTES.match(title):
                flush()
                stopped = True
                break
            if stop and started and re.search(stop, title):
                flush()
                stopped = True
                break
            flush()
            if NUMBER.match(title):
                started = True
            continue
        if NUMBER.match(line):
            end_para()
            flush()
            started = True
            continue
        if line == SEP_MARK:
            end_para()
            flush()
            continue
        if line.startswith(AUTHOR_MARK):
            end_para()
            cur_author = tidy_author(line[len(AUTHOR_MARK):])
            flush()
            continue
        if line.startswith("----") or line.startswith("__"):
            end_para()
            continue
        if line.startswith(("{|", "|}", "|-", "!")):
            continue
        para.append(line)
    end_para()
    flush()
    return entries


def polish(t):
    """Убрать следы примечаний: номера сносок «(5)», «» 14.», пометки
    редактора в квадратных скобках с латиницей или «см. прим.»."""
    t = re.sub(r"\s*\(\d{1,3}\)", "", t)
    t = re.sub(r"(?<=[»\"])\s*\d{1,3}(?=[\s.,;:!?]|$)", "", t)
    t = re.sub(r"\s*\[[^\]]*(?:[A-Za-z]|прим\.|См\.)[^\]]*\]", "", t)
    t = re.sub(r"\s+([,.;:!?])", r"\1", t)
    return t.strip()


def good(t, maxlen, minlen=12):
    if not (minlen <= len(t) <= maxlen):
        return False
    if any(x in t for x in ("{{", "}}", "[[", "]]", "|", "http", "<", ">", "\x01", "\x02")):
        return False
    if not re.search(r"[а-яё]", t, re.I):
        return False
    if not re.search(r"[.!?…»\"]$", t):  # мысль должна быть законченной
        return False
    if re.match(r"^[a-zа-яё]", t):  # начало оборвано (продолжение предыдущего)
        return False
    if re.search(r"[A-Za-z]{2,}|[A-Za-z]'", t):  # остатки иностранных пометок
        return False
    if re.match(r"^\d+\s", t):  # обрывок с номером страницы или сноски
        return False
    if re.match(r"^(Первое издание|Источник|Перевод|Печатается)", t):
        return False
    return True


def norm(t):
    return re.sub(r"[^а-яёa-z0-9]", "", t.lower().replace("ё", "е"))


def collect():
    sources, quotes, seen = [], [], set()
    stats = []
    for src in SOURCES:
        titles = src["titles"]
        if isinstance(titles, str) and titles.startswith("prefix:"):
            titles = prefix_titles(titles[len("prefix:"):])
            if src.get("depth"):
                titles = [t for t in titles if t.count("/") + 1 == src["depth"]]
            if src.get("exclude"):
                titles = [t for t in titles if not re.search(src["exclude"], t)]
            titles = sorted(titles, key=natural_key)
        n_before = len(quotes)
        dropped = 0
        for t in titles:
            print(f"· {t}", file=sys.stderr)
            for text, author in parse(wikitext(t), src["mode"], src.get("stop")):
                text = polish(text)
                if not good(text, src["maxlen"]):
                    dropped += 1
                    continue
                key = norm(text)
                if key in seen:
                    continue
                seen.add(key)
                quotes.append({"t": text, "a": author or src["author"], "s": src["k"]})
            time.sleep(0.3)
        got = len(quotes) - n_before
        stats.append((src["n"], got, dropped))
        sources.append({"k": src["k"], "n": src["n"],
                        "u": src.get("u") or ws_url(src["titles"][0]),
                        "d": src["d"]})
    for l in LINKS:
        sources.append({"k": l["k"], "n": l["n"], "u": l["u"], "d": l["d"]})
    return sources, quotes, stats


def natural_key(s):
    return [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", s)]


MONTHS = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль",
          "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/data/quotes.json")
    ap.add_argument("--if-missing", action="store_true")
    ap.add_argument("--min", type=int, default=500,
                    help="ошибка, если цитат меньше (значит, Викитека не ответила)")
    a = ap.parse_args()
    if a.if_missing and os.path.exists(a.out):
        print(f"{a.out} уже есть — пропускаю")
        return
    sources, quotes, stats = collect()
    print("\nИсточник | цитат | отброшено", file=sys.stderr)
    for n, got, dropped in stats:
        print(f"{n} | {got} | {dropped}", file=sys.stderr)
    print(f"Всего: {len(quotes)} цитат, {len(sources)} источников", file=sys.stderr)
    if len(quotes) < a.min:
        sys.exit(f"Слишком мало цитат ({len(quotes)}) — подборка не сохранена")
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write('{\n"version": 1,\n"sources": [\n')
        f.write(",\n".join(json.dumps(s, ensure_ascii=False) for s in sources))
        f.write('\n],\n"quotes": [\n')
        f.write(",\n".join(json.dumps(q, ensure_ascii=False) for q in quotes))
        f.write("\n]\n}\n")
    print(f"Сохранено в {a.out}")


if __name__ == "__main__":
    main()
