#!/usr/bin/env python3
"""Import a Herrnhuter Losungen year file for the widgets.

The Losungen are published by the Evangelische Brüder-Unität (Herrnhuter
Brüdergemeine). They are free of charge for non-commercial use, but they are
NOT free content: paid software and commercial sites are excluded. That is
incompatible with this project's GPL-3.0 licence, so the data must never be
committed to this repository. It is imported onto your own machine instead.

Download the year file yourself from https://www.losungen.de/digital/ — you
accept the terms of use there — and point this script at it:

    python3 tools/import_losungen.py ~/Downloads/Losungen_2026.zip

It writes ~/.local/share/bible-verse-widget/losungen-<year>.json, which both
widgets read when their source is set to "losungen".

Note: the site currently serves an incomplete TLS certificate chain, which
browsers paper over but command-line tools do not. That is the other reason
this script takes a local file instead of downloading one.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

TARGET_DIR = Path.home() / ".local" / "share" / "bible-verse-widget"

# The published XML uses German tag names. Several generations of the file are
# in circulation, so each field is looked up under all the spellings seen in the
# wild; if none match, the script reports the tags it actually found.
FIELDS = {
    "date": ("Datum", "date"),
    "weekday": ("Wtag", "Wochentag"),
    "sunday": ("Sonntag", "Sonntagsname"),
    "losung_text": ("Losungstext", "Losungtext"),
    "losung_ref": ("Losungsvers", "Losungvers"),
    "lehrtext_text": ("Lehrtext", "Lehrtexttext"),
    "lehrtext_ref": ("Lehrtextvers",),
}


def strip_namespace(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def find(element: ET.Element, names: tuple[str, ...]) -> str | None:
    for child in element:
        if strip_namespace(child.tag) in names:
            return (child.text or "").strip()
    return None


def read_xml(source: Path) -> bytes:
    if source.suffix.lower() != ".zip":
        return source.read_bytes()
    with zipfile.ZipFile(source) as archive:
        names = [n for n in archive.namelist() if n.lower().endswith(".xml")]
        if not names:
            raise SystemExit(f"no XML file inside {source}; it contains: "
                             + ", ".join(archive.namelist()))
        if len(names) > 1:
            print(f"  several XML files, using {names[0]}", file=sys.stderr)
        return archive.read(names[0])


def clean(text: str) -> str:
    """Normalise whitespace and the various dashes and quotes in the source."""
    text = unicodedata.normalize("NFC", text)
    return " ".join(text.split())


def parse(payload: bytes) -> list[dict]:
    root = ET.fromstring(payload)
    days, skipped = [], 0
    seen_tags: set[str] = set()

    for element in root.iter():
        raw_date = find(element, FIELDS["date"])
        if raw_date is None:
            continue
        for child in element:
            seen_tags.add(strip_namespace(child.tag))

        match = re.match(r"(\d{4})-(\d{2})-(\d{2})", raw_date)
        if not match:
            skipped += 1
            continue

        entry = {
            "date": f"{match[1]}-{match[2]}-{match[3]}",
            "weekday": clean(find(element, FIELDS["weekday"]) or ""),
            "sunday": clean(find(element, FIELDS["sunday"]) or ""),
            "losung": {
                "text": clean(find(element, FIELDS["losung_text"]) or ""),
                "ref": clean(find(element, FIELDS["losung_ref"]) or ""),
            },
            "lehrtext": {
                "text": clean(find(element, FIELDS["lehrtext_text"]) or ""),
                "ref": clean(find(element, FIELDS["lehrtext_ref"]) or ""),
            },
        }
        if not entry["losung"]["text"] or not entry["lehrtext"]["text"]:
            skipped += 1
            continue
        days.append(entry)

    if not days:
        raise SystemExit(
            "found no day entries. The tags in this file are:\n  "
            + ", ".join(sorted(seen_tags) or ["<none>"])
            + "\nAdd the right ones to FIELDS in this script."
        )
    if skipped:
        print(f"  skipped {skipped} incomplete entries", file=sys.stderr)
    return days


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", type=Path,
                        help="the ZIP or XML downloaded from losungen.de")
    parser.add_argument("--out-dir", type=Path, default=TARGET_DIR)
    args = parser.parse_args()

    if not args.file.exists():
        raise SystemExit(f"no such file: {args.file}")

    days = parse(read_xml(args.file))
    days.sort(key=lambda d: d["date"])

    years = sorted({day["date"][:4] for day in days})
    args.out_dir.mkdir(parents=True, exist_ok=True)

    for year in years:
        of_year = [day for day in days if day["date"].startswith(year)]
        target = args.out_dir / f"losungen-{year}.json"
        target.write_text(json.dumps({
            "source": "Herrnhuter Losungen",
            "year": int(year),
            "copyright": "© Evangelische Brüder-Unität – Herrnhuter Brüdergemeine",
            "url": "https://www.losungen.de/",
            "note": "Non-commercial use only. Not redistributable with this program.",
            "count": len(of_year),
            "days": of_year,
        }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"  wrote {target} ({len(of_year)} days)", file=sys.stderr)

    print("Set the widget's source to \"Herrnhuter Losungen\" to use it.",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
