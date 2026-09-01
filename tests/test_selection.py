#!/usr/bin/env python3
"""Reference implementation of the verse selection, and conformance tests.

Run with:  python3 -m unittest discover -s tests

The JavaScript port in shared/selection.js is executed with node (if present)
and compared against this implementation date by date. Both must agree exactly,
because the Plasmoid and the Desklet must show the same verse on the same day.
"""

from __future__ import annotations

import datetime as dt
import json
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

MODULUS = 2147483647
MULTIPLIER = 48271
YEAR_SALT = 2654435761


def make_random(seed: int):
    state = seed % MODULUS
    if state <= 0:
        state += MODULUS - 1

    def next_value() -> int:
        nonlocal state
        state = (state * MULTIPLIER) % MODULUS
        return state

    return next_value


def year_permutation(year: int, count: int) -> list[int]:
    next_value = make_random((year * YEAR_SALT) % MODULUS)
    perm = list(range(count))
    for i in range(count - 1, 0, -1):
        j = next_value() % (i + 1)
        perm[i], perm[j] = perm[j], perm[i]
    return perm


def verse_index_for_date(date: dt.date, count: int) -> int:
    if count <= 0:
        return 0
    return year_permutation(date.year, count)[(date.timetuple().tm_yday - 1) % count]


def verse_count() -> int:
    return json.loads((ROOT / "data" / "verses" / "en.json").read_text("utf-8"))["count"]


class TestSelection(unittest.TestCase):
    def test_index_is_in_range(self):
        count = verse_count()
        date = dt.date(2026, 1, 1)
        for _ in range(366 * 4):
            self.assertIn(verse_index_for_date(date, count), range(count))
            date += dt.timedelta(days=1)

    def test_no_repeat_within_a_year(self):
        count = verse_count()
        self.assertGreaterEqual(count, 366, "list must cover a leap year without repeats")
        for year in (2025, 2026, 2027, 2028):
            days = (dt.date(year, 12, 31) - dt.date(year, 1, 1)).days + 1
            seen = [verse_index_for_date(dt.date(year, 1, 1) + dt.timedelta(days=d), count)
                    for d in range(days)]
            self.assertEqual(len(seen), len(set(seen)), f"repeated verse in {year}")

    def test_years_differ(self):
        count = verse_count()
        a = verse_index_for_date(dt.date(2026, 6, 15), count)
        b = verse_index_for_date(dt.date(2027, 6, 15), count)
        self.assertNotEqual(a, b, "the same day in two years should not repeat")

    def test_stable_across_runs(self):
        # Guards against an accidental change to the constants: these values are
        # what every already-installed widget will be showing.
        self.assertEqual(verse_index_for_date(dt.date(2026, 1, 1), 438), 146)
        self.assertEqual(verse_index_for_date(dt.date(2026, 9, 1), 438), 172)
        self.assertEqual(verse_index_for_date(dt.date(2027, 1, 1), 438), 306)

    def test_javascript_port_agrees(self):
        node = shutil.which("node")
        if node is None:
            self.skipTest("node not available")
        count = verse_count()
        script = f"""
            {(ROOT / 'shared' / 'selection.js').read_text('utf-8')}
            var out = [];
            for (var y = 2025; y <= 2029; y++) {{
                for (var m = 0; m < 12; m++) {{
                    for (var d = 1; d <= 28; d += 3) {{
                        out.push([y, m + 1, d,
                                  verseIndexForDate(new Date(y, m, d), {count})]);
                    }}
                }}
            }}
            console.log(JSON.stringify(out));
        """
        result = subprocess.run([node, "-e", script], capture_output=True, text=True,
                                check=True)
        for year, month, day, index in json.loads(result.stdout):
            self.assertEqual(
                index, verse_index_for_date(dt.date(year, month, day), count),
                f"JavaScript and Python disagree on {year}-{month:02d}-{day:02d}")


if __name__ == "__main__":
    unittest.main()
