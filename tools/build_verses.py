#!/usr/bin/env python3
"""Resolve data/references.txt against public-domain Bible texts.

Writes data/verses/<lang>.json, one entry per reference, in the exact order of
references.txt so that index i means the same passage in every language.

The source texts are downloaded once into .cache/ (git-ignored). Nothing but
the resolved verses ends up in the repository.

Usage:
    python3 tools/build_verses.py            # build
    python3 tools/build_verses.py --check    # fail if committed output is stale
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache"
OUT = ROOT / "data" / "verses"
REFERENCES = ROOT / "data" / "references.txt"

MIDVASH = "https://raw.githubusercontent.com/midvash/bible-data/main/versions"
GETBIBLE = "https://api.getbible.net/v2"

# Chapters whose verse numbering differs between the three sources. References
# from these chapters cannot be kept in sync and are rejected outright, rather
# than silently resolving to a different passage in one language.
DIVERGENT = {
    (4, 12), (4, 29), (9, 23), (10, 20), (14, 33),
    (18, 35), (18, 38), (18, 40), (28, 11),
    (32, 1), (32, 2), (32, 3), (32, 4),  # Jonah: whole book is shifted
    (42, 17), (44, 8), (44, 15), (44, 19), (44, 24),
    (45, 14), (45, 16), (47, 13),
}

SOURCES = {
    "de": {
        "kind": "midvash",
        "url": f"{MIDVASH}/de/luth1912/luth1912.json",
        "file": "luth1912.json",
        "name": "Lutherbibel 1912",
        "shortName": "LUT1912",
        "year": 1912,
        "license": "public-domain",
        "sourceUrl": "https://github.com/midvash/bible-data",
        "separator": ",",          # "Johannes 3,16"
        "bookNamesFrom": "schlachter",
    },
    "en": {
        "kind": "midvash",
        "url": f"{MIDVASH}/en/web/web.json",
        "file": "web.json",
        "name": "World English Bible",
        "shortName": "WEB",
        "year": 2000,
        "license": "public-domain",
        "sourceUrl": "https://github.com/midvash/bible-data",
        "separator": ":",
        "bookNamesFrom": None,     # English names come from the source itself
    },
    "es": {
        "kind": "getbible",
        "url": f"{GETBIBLE}/valera.json",
        "file": "valera.json",
        "name": "Reina-Valera 1909",
        "shortName": "RVR1909",
        "year": 1909,
        "license": "public-domain",
        "sourceUrl": "https://getbible.net/",
        "separator": ":",
        "bookNamesFrom": None,     # Spanish names come from the source itself
    },
}

REF_RE = re.compile(r"^(?P<book>.+?)\s+(?P<ch>\d+):(?P<v1>\d+)(?:-(?P<v2>\d+))?$")

# getbible.net rejects the default urllib user agent with HTTP 403.
USER_AGENT = "bible-verse-widget-build/1.0 (+https://github.com/TechnikWeber/bible-verse-widget)"


def fetch(url: str, timeout: int = 60) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def download(url: str, dest: Path) -> Path:
    if dest.exists():
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"  downloading {url}", file=sys.stderr)
    dest.write_bytes(fetch(url, timeout=120))
    return dest


def load_midvash(cfg: dict) -> tuple[dict, dict]:
    """Return ({(book_id, chapter, verse): text}, {book_id: english_name})."""
    data = json.loads(download(cfg["url"], CACHE / cfg["file"]).read_text("utf-8"))
    verses, names = {}, {}
    for book in data["books"]:
        names[book["bookId"]] = book["englishName"]
        for chapter in book["chapters"]:
            for verse in chapter["verses"]:
                verses[(book["bookId"], chapter["chapter"], verse["number"])] = verse["text"]
    return verses, names


def load_getbible(cfg: dict) -> tuple[dict, dict]:
    data = json.loads(download(cfg["url"], CACHE / cfg["file"]).read_text("utf-8"))
    verses, names = {}, {}
    for book in data["books"]:
        names[book["nr"]] = book["name"]
        for chapter in book["chapters"]:
            for verse in chapter["verses"]:
                verses[(book["nr"], chapter["chapter"], verse["verse"])] = verse["text"]
    return verses, names


def german_book_names() -> dict[int, str]:
    """Book names from the Schlachter text — one small request per book."""
    cached = CACHE / "book-names-de.json"
    if cached.exists():
        return {int(k): v for k, v in json.loads(cached.read_text("utf-8")).items()}
    print("  fetching German book names", file=sys.stderr)
    names = {}
    for book_id in range(1, 67):
        url = f"{GETBIBLE}/schlachter/{book_id}/1.json"
        names[book_id] = json.loads(fetch(url, timeout=30))["book_name"]
    cached.parent.mkdir(parents=True, exist_ok=True)
    cached.write_text(json.dumps(names, ensure_ascii=False, indent=2), "utf-8")
    return names


def parse_references(english_names: dict[int, str]) -> list[tuple[int, int, int, int]]:
    by_name = {name: book_id for book_id, name in english_names.items()}
    refs, errors = [], []
    for lineno, raw in enumerate(REFERENCES.read_text("utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = REF_RE.match(line)
        if not match:
            errors.append(f"{REFERENCES.name}:{lineno}: cannot parse {line!r}")
            continue
        book_id = by_name.get(match["book"])
        if book_id is None:
            errors.append(f"{REFERENCES.name}:{lineno}: unknown book {match['book']!r}")
            continue
        chapter = int(match["ch"])
        first = int(match["v1"])
        last = int(match["v2"]) if match["v2"] else first
        if last < first:
            errors.append(f"{REFERENCES.name}:{lineno}: reversed verse range {line!r}")
            continue
        if (book_id, chapter) in DIVERGENT:
            errors.append(
                f"{REFERENCES.name}:{lineno}: {line!r} is in a chapter whose "
                f"versification differs between the sources"
            )
            continue
        refs.append((book_id, chapter, first, last))
    if errors:
        raise SystemExit("\n".join(errors))
    duplicates = {r for r in refs if refs.count(r) > 1}
    if duplicates:
        raise SystemExit(f"duplicate references: {sorted(duplicates)}")
    return refs


PSALMS = 19

# The Luther and WEB digitisations fold the Psalm superscription ("A Psalm by
# David", "Ein Lied im höhern Chor", …) into verse 1. Reina-Valera does not, so
# the same reference would render different content per language. These patterns
# strip a leading superscription sentence; they are applied to Psalms verse 1
# only and every removal is reported by the build for review.
SUPERSCRIPTION = {
    "de": re.compile(r"^(?:Ein|Eine|Vorzusingen)\b[^.]*\.\s+"),
    "en": re.compile(
        r"^(?:For the Chief Musician|To the Chief Musician|A Psalm|A Song|A Prayer"
        r"|A contemplation|A Michtam|A commemorative|By David|By the sons of Korah"
        r"|Of David|According to|To [A-Z])\b[^.]*\.\s+"
    ),
}

# Reina-Valera sets the first word of a chapter in full capitals as a drop cap,
# and marks the acrostic sections of Psalm 119 with the Hebrew letter name.
SPANISH_DROP_CAP = re.compile(r"^([¡¿]?)([A-ZÁÉÍÓÚÑÜ]{2,})(?=[\s,;:.!?])")
SPANISH_ACROSTIC = re.compile(r"^[A-ZÁÉÍÓÚÑÜ]{2,}\.\s+")


def normalise(text: str, lang: str, book_id: int, chapter: int, number: int,
              removals: list[str]) -> str:
    """Reconcile the typographic conventions of the three source editions."""
    if lang in SUPERSCRIPTION and book_id == PSALMS and number == 1:
        while True:
            match = SUPERSCRIPTION[lang].match(text)
            if not match:
                break
            removals.append(f"{lang} Ps {chapter}:1 superscription {match.group(0).strip()!r}")
            text = text[match.end():]

    if lang == "es":
        if book_id == PSALMS and chapter == 119:
            match = SPANISH_ACROSTIC.match(text)
            if match:
                removals.append(f"es Ps 119:{number} acrostic {match.group(0).strip()!r}")
                text = text[match.end():]
        if number == 1:
            def fold(match: re.Match) -> str:
                word = match.group(2)
                return match.group(1) + word[0] + word[1:].lower()
            text = SPANISH_DROP_CAP.sub(fold, text, count=1)

    return text


def build_language(lang: str, refs, book_names: dict[int, str]) -> dict:
    cfg = SOURCES[lang]
    verses, own_names = (load_getbible if cfg["kind"] == "getbible" else load_midvash)(cfg)
    names = book_names if cfg["bookNamesFrom"] else own_names
    separator = cfg["separator"]

    entries, missing, removals = [], [], []
    for book_id, chapter, first, last in refs:
        parts = []
        for number in range(first, last + 1):
            text = verses.get((book_id, chapter, number))
            if text is None:
                missing.append(f"{lang}: {names[book_id]} {chapter}:{number} not found")
                break
            text = normalise(" ".join(text.split()), lang, book_id, chapter, number, removals)
            parts.append(text)
        else:
            span = str(first) if first == last else f"{first}-{last}"
            entries.append({
                "id": f"{book_id}.{chapter}.{first}" + ("" if first == last else f"-{last}"),
                "ref": f"{names[book_id]} {chapter}{separator}{span}",
                "text": " ".join(parts),
            })
    if missing:
        raise SystemExit("\n".join(missing))
    for removal in removals:
        print(f"    normalised: {removal}", file=sys.stderr)

    return {
        "language": lang,
        "translation": {
            "name": cfg["name"],
            "shortName": cfg["shortName"],
            "year": cfg["year"],
            "license": cfg["license"],
            "sourceUrl": cfg["sourceUrl"],
        },
        "count": len(entries),
        "verses": entries,
    }


def check_balance() -> None:
    """Flag references whose renderings differ wildly in length.

    The three editions are of comparable verbosity, so a large imbalance means
    one of them carries something the others do not — a leftover superscription,
    a heading, or a genuine versification mismatch that slipped through.
    """
    loaded = {lang: json.loads((OUT / f"{lang}.json").read_text("utf-8"))["verses"]
              for lang in SOURCES}
    offenders = []
    for i in range(len(loaded["en"])):
        lengths = {lang: len(loaded[lang][i]["text"]) for lang in loaded}
        shortest, longest = min(lengths.values()), max(lengths.values())
        if longest > 40 and longest / shortest > 2.0:
            detail = ", ".join(f"{lang}={n}" for lang, n in sorted(lengths.items()))
            offenders.append(f"  {loaded['en'][i]['ref']}: {detail}")
    if offenders:
        raise SystemExit("unbalanced renderings — check versification:\n" + "\n".join(offenders))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed output differs from a fresh build")
    args = parser.parse_args()

    print("Loading sources…", file=sys.stderr)
    _, english_names = load_midvash(SOURCES["en"])
    refs = parse_references(english_names)
    print(f"  {len(refs)} references", file=sys.stderr)

    book_names = german_book_names()
    OUT.mkdir(parents=True, exist_ok=True)

    stale = []
    for lang in SOURCES:
        built = build_language(lang, refs, book_names)
        rendered = json.dumps(built, ensure_ascii=False, indent=2) + "\n"
        target = OUT / f"{lang}.json"
        if args.check:
            current = target.read_text("utf-8") if target.exists() else ""
            if current != rendered:
                stale.append(str(target.relative_to(ROOT)))
        else:
            target.write_text(rendered, "utf-8")
            print(f"  wrote {target.relative_to(ROOT)} ({built['count']} verses)", file=sys.stderr)

    # Index i must denote the same passage in every language.
    ids = {lang: [v["id"] for v in json.loads((OUT / f"{lang}.json").read_text("utf-8"))["verses"]]
           for lang in SOURCES}
    reference_ids = ids["en"]
    for lang, values in ids.items():
        if values != reference_ids:
            raise SystemExit(f"{lang}.json is not index-aligned with en.json")

    check_balance()

    if stale:
        raise SystemExit("stale, re-run tools/build_verses.py: " + ", ".join(stale))
    print("OK", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
