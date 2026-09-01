#!/usr/bin/env python3
"""Tests for the Herrnhuter Losungen importer.

The fixture is a stand-in with public-domain wording, not real Losungen data:
that data is free for non-commercial use only and must not live in this
repository. So these tests cover the parsing, not the published file itself.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / "tests" / "fixtures" / "losungen-sample.xml"
IMPORTER = ROOT / "tools" / "import_losungen.py"


def run(source: Path, out_dir: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(IMPORTER), str(source), "--out-dir", str(out_dir)],
        capture_output=True, text=True)


class TestImporter(unittest.TestCase):
    def test_parses_xml(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            self.assertEqual(run(FIXTURE, out).returncode, 0)
            data = json.loads((out / "losungen-2026.json").read_text("utf-8"))

            # The third fixture entry has an empty Losungstext and is dropped.
            self.assertEqual(data["count"], 2)
            self.assertEqual(data["year"], 2026)
            self.assertIn("Brüder-Unität", data["copyright"])

            first = data["days"][0]
            self.assertEqual(first["date"], "2026-01-01")
            self.assertEqual(first["sunday"], "Neujahrstag")
            self.assertEqual(first["losung"]["ref"], "Jes 43,1")
            self.assertEqual(first["lehrtext"]["ref"], "1.Kor 16,14")

    def test_collapses_whitespace(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            run(FIXTURE, out)
            data = json.loads((out / "losungen-2026.json").read_text("utf-8"))
            self.assertEqual(data["days"][1]["losung"]["text"],
                             "Der HERR ist mein Hirte; mir wird nichts mangeln.")

    def test_accepts_a_zip(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "Losungen.zip"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("Losungen Free 2026.xml", FIXTURE.read_bytes())
                zf.writestr("Nutzungsbedingungen.txt", "terms")
            out = Path(tmp) / "out"
            self.assertEqual(run(archive, out).returncode, 0)
            self.assertTrue((out / "losungen-2026.json").exists())

    def test_reports_the_tags_when_nothing_matches(self):
        with tempfile.TemporaryDirectory() as tmp:
            odd = Path(tmp) / "odd.xml"
            odd.write_text("<root><entry><Tag>x</Tag></entry></root>", "utf-8")
            result = run(odd, Path(tmp) / "out")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no day entries", result.stderr)


if __name__ == "__main__":
    unittest.main()
