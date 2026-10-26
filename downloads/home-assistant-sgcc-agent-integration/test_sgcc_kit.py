import copy
import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("sgcc_kit", Path(__file__).with_name("sgcc_kit.py"))
kit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kit)


class KitTests(unittest.TestCase):
    def setUp(self):
        self.mapping = kit.load_mapping(Path(__file__).with_name("mapping.example.json"))

    def test_dated_correction_does_not_double_count(self):
        rows = kit.merge_day([], "2026-01-01", 12)
        self.assertEqual(kit.merge_day(rows, "2026-01-01", 13), [{"date": "2026-01-01", "kwh": 13}])

    def test_late_day_keeps_latest_day(self):
        rows = kit.merge_day([], "2026-01-03", 15)
        rows = kit.merge_day(rows, "2026-01-01", 12)
        self.assertEqual(rows[-1]["date"], "2026-01-03")

    def test_missing_days_stay_missing(self):
        rows = kit.merge_day([], "2026-01-01", 10)
        self.assertEqual(len(kit.merge_day(rows, "2026-01-03", 20)), 2)

    def test_invalid_daily_values_are_rejected(self):
        for value in ["unknown", "unavailable", "nan", "inf", -1, None]:
            with self.subTest(value=value), self.assertRaises((ValueError, TypeError)):
                kit.merge_day([], "2026-01-01", value)

    def test_invalid_or_future_dates_rejected(self):
        for date in ["2026-02-30", "2026-1-1", (dt.date.today() + dt.timedelta(days=1)).isoformat()]:
            with self.subTest(date=date), self.assertRaises(ValueError):
                kit.merge_day([], date, 1)

    def test_zero_is_a_valid_observed_value(self):
        self.assertEqual(kit.merge_day([], "2026-01-01", 0)[0]["kwh"], 0)

    def test_retention_is_bounded(self):
        rows = []
        for day in range(20):
            rows = kit.merge_day(rows, (dt.date(2026, 1, 1) + dt.timedelta(days=day)).isoformat(), day, 14)
        self.assertEqual(len(rows), 14)

    def test_no_statistics_without_business_confirmation(self):
        package, _ = kit.generated(self.mapping)
        self.assertNotIn("state_class:", package)
        confirmed = {**self.mapping, "yearly_counter_verified": True}
        self.assertEqual(kit.generated(confirmed)[0].count("state_class: total_increasing"), 1)
        self.assertNotIn("float(0)", package)

    def test_attach_preserves_existing_packages(self):
        config = "homeassistant:\n  name: Home\n  packages:\n    other: !include other.yaml\nrecorder:\n  purge_keep_days: 30\n"
        result, _ = kit.attach(config)
        self.assertIn("other: !include other.yaml", result)
        self.assertIn("purge_keep_days: 30", result)
        self.assertEqual(kit.attach(result)[0], result)

    def test_include_dir_named_keeps_root_config_unchanged(self):
        config = "homeassistant:\n  packages: !include_dir_named packages\n"
        result, path = kit.attach(config)
        self.assertEqual(result, config)
        self.assertEqual(path, "packages/sgcc_blog_kit.yaml")

    def test_unsupported_layout_refused(self):
        for cfg in ["homeassistant: !include home.yaml\n", "homeassistant:\n  packages: !include packages.yaml\n"]:
            with self.assertRaises(ValueError):
                kit.attach(cfg)

    def test_failed_ha_validation_restores_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            original = b"default_config:\n"
            (root / "configuration.yaml").write_bytes(original)
            with patch.object(kit, "api", return_value={"result": "invalid"}), self.assertRaises(ValueError):
                kit.apply(root, self.mapping)
            self.assertEqual((root / "configuration.yaml").read_bytes(), original)
            self.assertFalse((root / kit.OWNED / "package.yaml").exists())

    def test_success_idempotency_and_rollback(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            original = b"default_config:\n"
            (root / "configuration.yaml").write_bytes(original)
            with patch.object(kit, "api", return_value={"result": "valid"}):
                snapshot = kit.apply(root, self.mapping)
                self.assertIsNone(kit.apply(root, self.mapping))
            kit.rollback(root, snapshot)
            self.assertEqual((root / "configuration.yaml").read_bytes(), original)

    def test_rollback_does_not_overwrite_later_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "configuration.yaml").write_text("default_config:\n")
            with patch.object(kit, "api", return_value={"result": "valid"}):
                snapshot = kit.apply(root, self.mapping)
            (root / "configuration.yaml").write_text("default_config:\n# later work\n")
            with self.assertRaises(ValueError):
                kit.rollback(root, snapshot)

    def test_unknown_existing_file_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "configuration.yaml").write_text("default_config:\n")
            (root / kit.OWNED).mkdir()
            (root / kit.OWNED / "package.yaml").write_text("unrelated: true\n")
            with self.assertRaises(ValueError):
                kit.apply(root, self.mapping)


if __name__ == "__main__":
    unittest.main()
