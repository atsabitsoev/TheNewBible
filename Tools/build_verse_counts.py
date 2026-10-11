#!/usr/bin/env python3
"""Builds TheNewBible/Resources/versecounts.tsv from the Russian Synodal text.

The Synodal translation (1876) is in the public domain. Its full text is
published by bolls.life as https://bolls.life/static/translations/SYNOD.zip.
Only the number of verses in each chapter of the 66 canonical books is kept.

Usage:
    python3 Tools/build_verse_counts.py [path/to/SYNOD.zip]

Output format (tab separated): book<TAB>chapter<TAB>verse count
"""

import io
import json
import os
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "TheNewBible", "Resources", "versecounts.tsv")
URL = "https://bolls.life/static/translations/SYNOD.zip"


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1], "rb") as f:
            data = f.read()
    else:
        with urllib.request.urlopen(URL) as response:
            data = response.read()
    archive = zipfile.ZipFile(io.BytesIO(data))
    verses = json.loads(archive.read(archive.namelist()[0]))

    counts = {}
    for verse in verses:
        if verse["book"] > 66:
            continue
        key = (verse["book"], verse["chapter"])
        counts[key] = max(counts.get(key, 0), verse["verse"])

    with open(OUTPUT, "w", encoding="utf-8") as out:
        for (book, chapter), count in sorted(counts.items()):
            out.write(f"{book}\t{chapter}\t{count}\n")
    print(f"wrote {len(counts)} chapters to {os.path.relpath(OUTPUT, ROOT)}")


if __name__ == "__main__":
    main()
