"""Offline tests; all fixture writes and Git staging occur in temporary directories."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_capsule_index as subject


class CapsuleIndexTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.capsules = self.root / "aiweather-capsule/capsules"
        self.capsules.mkdir(parents=True)
        self.output = self.root / "data/capsule-index.json"

    def capsule(self, day, **overrides):
        value = {"date": day, "observations": [], "chain": {"prev_hash": "genesis", "sequence_index": 0}}
        value.update(overrides)
        value["chain"]["content_hash"] = subject.compute_content_hash(value)
        target = self.capsules / (day.replace("-", "/") + ".json")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(value), encoding="utf-8")
        return target

    def generate(self):
        index = subject.build_index(self.capsules)
        subject.write_atomic(self.output, subject.encode_index(index))
        return index

    def test_empty_and_less_than_fifteen(self):
        self.assertEqual(self.generate()["capsules"], [])
        self.capsule("2026-09-05")
        self.assertEqual(len(self.generate()["capsules"]), 1)

    def test_more_than_fifteen_preserved(self):
        for day in range(1, 21):
            self.capsule(f"2026-08-{day:02}")
        entries = self.generate()["capsules"]
        self.assertEqual(len(entries), 20)
        self.assertEqual(entries[0]["date"], "2026-08-20")
        for entry in entries:
            self.assertTrue((self.output.parent / entry["path"]).is_file())

    def test_gaps_month_year_and_leap_day(self):
        days = ["2025-12-31", "2026-01-02", "2026-02-01", "2024-02-29"]
        for day in days:
            self.capsule(day)
        self.assertEqual([e["date"] for e in self.generate()["capsules"]], sorted(days, reverse=True))

    def test_duplicate_date(self):
        original = self.capsule("2026-08-01")
        (original.parent / "02.json").write_bytes(original.read_bytes())
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.generate()

    def test_bad_date_and_mismatched_path(self):
        file = self.capsule("2026-02-30")
        with self.assertRaises(ValueError):
            self.generate()
        file.unlink()
        file = self.capsule("2026-02-01")
        file.rename(file.with_name("02.json"))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            self.generate()

    def test_invalid_json_preserves_previous_index(self):
        file = self.capsule("2026-09-01")
        self.generate()
        before = self.output.read_bytes()
        file.write_text("{", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.generate()
        self.assertEqual(self.output.read_bytes(), before)

    def test_invalid_hash(self):
        file = self.capsule("2026-09-01")
        data = json.loads(file.read_text())
        data["observations"] = [{"condition": "clear"}]
        file.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "hash"):
            self.generate()

    def test_duplicate_json_keys_and_nonfinite_numbers(self):
        file = self.capsule("2026-09-01")
        for invalid in ['{"date":"2026-09-01","date":"2026-09-02"}', '{"score":NaN}', '{"score":Infinity}']:
            with self.subTest(invalid=invalid):
                file.write_text(invalid, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Invalid capsule JSON"):
                    self.generate()

    def test_insufficient_and_no_translations_included(self):
        self.capsule("2026-09-01", observations=[{"condition": "insufficient_data"}], probe_contract={"daily": {"question": "Original"}})
        self.assertEqual(len(self.generate()["capsules"]), 1)

    def test_repeat_identical_and_capsules_immutable(self):
        file = self.capsule("2026-09-01")
        capsule_before = file.read_bytes()
        self.generate()
        before, modified = self.output.read_bytes(), self.output.stat().st_mtime_ns
        with patch.object(subject.os, "replace", side_effect=AssertionError("Unexpected rewrite")):
            self.generate()
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(self.output.stat().st_mtime_ns, modified)
        self.assertEqual(file.read_bytes(), capsule_before)

    def test_interruption_before_atomic_replace(self):
        self.capsule("2026-09-01")
        self.generate()
        before = self.output.read_bytes()
        self.capsule("2026-09-02")
        def interrupt(source, destination):
            self.assertEqual(Path(source).parent, self.output.parent)
            self.assertEqual(self.output.read_bytes(), before)
            json.loads(Path(source).read_bytes())
            raise OSError("Interrupted before replacement")
        with patch.object(subject.os, "replace", side_effect=interrupt):
            with self.assertRaises(OSError):
                self.generate()
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(list(self.output.parent.glob("*.tmp")), [])

    def test_stale_manifest(self):
        self.capsule("2026-09-01")
        self.generate()
        self.capsule("2026-09-02")
        with self.assertRaises(ValueError):
            subject.check_index(self.output, subject.encode_index(subject.build_index(self.capsules)))

    def test_unpublishable_reference_and_different_staged_content(self):
        def git(*args):
            subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)
        git("init")
        git("config", "core.autocrlf", "false")
        file = self.capsule("2026-09-01")
        index = self.generate()
        git("add", "data/capsule-index.json")
        with self.assertRaises(ValueError):
            subject.check_git_index(self.root, self.output, index)
        git("add", "aiweather-capsule")
        subject.check_git_index(self.root, self.output, index)
        file.write_bytes(file.read_bytes() + b"\n")
        with self.assertRaisesRegex(ValueError, "differs"):
            subject.check_git_index(self.root, self.output, index)


if __name__ == "__main__":
    unittest.main(verbosity=2)
