#!/usr/bin/env python3
"""Builds TheNewBible/Resources/pericopes.tsv.

Pericope boundaries come from the section headings of the Berean Standard
Bible (dedicated to the public domain in 2023), fetched from the
HelloAO Free Use Bible API. Titles are replaced by the Russian
translations from Tools/pericope_titles_ru.tsv. Positions are converted
to Synodal numbering (Psalms and the chapters where verses move between
chapters), so run Tools/build_verse_counts.py first.

Usage:
    python3 Tools/build_pericopes.py [path/to/BSB-complete.json]

Without an argument the BSB JSON is downloaded from
https://bible.helloao.org/api/BSB/complete.json.

Output format (UTF-8, tab separated, one heading per line):
    book<TAB>chapter<TAB>verse<TAB>title
book is 1...66 in Protestant order (the same ids bolls.life uses).
Several headings can share one position: the first ones are section
titles, the last one is the pericope title.
"""

import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TITLES = os.path.join(ROOT, "Tools", "pericope_titles_ru.tsv")
OUTPUT = os.path.join(ROOT, "TheNewBible", "Resources", "pericopes.tsv")
BSB_URL = "https://bible.helloao.org/api/BSB/complete.json"
PSALMS = 19


def load_bsb(path):
    if path:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    with urllib.request.urlopen(BSB_URL) as response:
        return json.load(response)


def load_titles():
    titles = {}
    with open(TITLES, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            english, russian = line.split("\t")
            titles[english] = russian
    return titles


def synodal_psalm(psalm, verse):
    """Maps a Hebrew/English psalm position to Synodal (LXX) numbering."""
    if psalm <= 8:
        return psalm, verse
    if psalm == 9:
        return 9, verse
    if psalm == 10:
        return 9, verse + 21
    if psalm <= 113:
        return psalm - 1, verse
    if psalm == 114:
        return 113, verse
    if psalm == 115:
        return 113, verse + 8
    if psalm == 116:
        return (114, verse) if verse <= 9 else (115, verse - 9)
    if psalm <= 146:
        return psalm - 1, verse
    if psalm == 147:
        return (146, verse) if verse <= 11 else (147, verse - 11)
    return psalm, verse


def synodal_position(book, chapter, verse):
    """Maps a BSB (English) position to Synodal versification.

    Only the places where the Synodal text shifts verses between chapters
    are handled; everything else keeps its number.
    """
    if book == PSALMS:
        return synodal_psalm(chapter, verse)
    if book == 4:  # Numbers
        if (chapter, verse) == (12, 16):
            return 13, 1
        if chapter == 13:
            return 13, verse + 1
        if (chapter, verse) == (29, 40):
            return 30, 1
        if chapter == 30:
            return 30, verse + 1
    if book == 6:  # Joshua
        if (chapter, verse) == (6, 1):
            return 5, 16
        if chapter == 6:
            return 6, verse - 1
    if book == 9:  # 1 Samuel
        if (chapter, verse) == (23, 29):
            return 24, 1
        if chapter == 24:
            return 24, verse + 1
    if book == 18:  # Job
        if chapter == 40 and verse <= 5:
            return 39, verse + 30
        if chapter == 40:
            return 40, verse - 5
        if chapter == 41 and verse <= 8:
            return 40, verse + 19
        if chapter == 41:
            return 41, verse - 8
    if book == 21:  # Ecclesiastes
        if (chapter, verse) == (5, 1):
            return 4, 17
        if chapter == 5:
            return 5, verse - 1
    if book == 22:  # Song of Songs
        if (chapter, verse) == (6, 13):
            return 7, 1
        if chapter == 7:
            return 7, verse + 1
    if book == 27:  # Daniel
        if chapter == 3 and verse >= 24:
            return 3, verse + 67
        if chapter == 4 and verse <= 3:
            return 3, verse + 97
        if chapter == 4:
            return 4, verse - 3
    if book == 28:  # Hosea
        if (chapter, verse) == (13, 16):
            return 14, 1
        if chapter == 14:
            return 14, verse + 1
    if book == 32:  # Jonah
        if (chapter, verse) == (1, 17):
            return 2, 1
        if chapter == 2:
            return 2, verse + 1
    if book == 45 and chapter == 16 and verse >= 25:  # Romans doxology
        return 14, verse - 1
    return chapter, verse


def load_verse_counts():
    path = os.path.join(ROOT, "TheNewBible", "Resources", "versecounts.tsv")
    counts = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            book, chapter, count = map(int, line.split("\t"))
            counts[(book, chapter)] = count
    return counts


def main():
    bsb = load_bsb(sys.argv[1] if len(sys.argv) > 1 else None)
    titles = load_titles()
    counts = load_verse_counts()
    rows = []
    for book_number, book in enumerate(bsb["books"], start=1):
        for chapter in book["chapters"]:
            number = chapter["chapter"]["number"]
            content = chapter["chapter"]["content"]
            for index, item in enumerate(content):
                if item["type"] != "heading":
                    continue
                english = " ".join(item["content"]).strip()
                verse = next(
                    (c["number"] for c in content[index + 1:] if c["type"] == "verse"),
                    None,
                )
                if verse is None:
                    continue
                ch, vs = synodal_position(book_number, number, verse)
                if vs > counts.get((book_number, ch), 0):
                    print(f"skip {book_number} {ch}:{vs} {english}", file=sys.stderr)
                    continue
                rows.append([book_number, ch, vs, titles[english]])

    # Every Synodal psalm should open with a heading. Psalms that the
    # Synodal text splits (114/115 and 146/147) reuse the title of the
    # Hebrew psalm they come from; Psalm 151 exists only in the Synodal.
    starts = {(r[1], r[2]) for r in rows if r[0] == PSALMS}
    by_psalm = {}
    for r in rows:
        if r[0] == PSALMS:
            by_psalm.setdefault(r[1], r[3])
    for psalm in range(1, 152):
        if (psalm, 1) in starts:
            continue
        if psalm == 151:
            title = "Псалом Давида о победе над Голиафом"
        else:
            title = by_psalm.get(psalm) or by_psalm.get(psalm - 1) or f"Псалом {psalm}"
        rows.append([PSALMS, psalm, 1, title])

    rows.sort(key=lambda r: (r[0], r[1], r[2]))
    with open(OUTPUT, "w", encoding="utf-8") as out:
        for book, chapter, verse, title in rows:
            out.write(f"{book}\t{chapter}\t{verse}\t{title}\n")
    print(f"wrote {len(rows)} headings to {os.path.relpath(OUTPUT, ROOT)}")


if __name__ == "__main__":
    main()
