"""Offline regression tests for reference-data drift and provenance handling."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import tempfile
import unittest
import zipfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "fetch_reference.py"
SPEC = importlib.util.spec_from_file_location("fetch_reference", SCRIPT_PATH)
fetch_reference = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fetch_reference)

OLD_SHA = "a" * 40
NEW_SHA = "b" * 40


def source_url(sha: str) -> str:
    return f"https://github.com/mledoze/countries/blob/{sha}/countries.json"


def country_records(sha: str = OLD_SHA) -> list[dict]:
    return [{
        "code": "JP",
        "nameZh": "日本",
        "nameEn": "Japan",
        "currencyCode": "JPY",
        "languageCode": "ja",
        "emergency": {"police": "110", "ambulance": "119", "fire": "119"},
        "plugTypes": ["A", "B"],
        "voltage": "100V",
        "sourceUrl": source_url(sha),
    }, {
        "code": "KR",
        "nameZh": "韓國",
        "nameEn": "South Korea",
        "currencyCode": "KRW",
        "languageCode": "ko",
        "emergency": {"police": "112", "ambulance": "119", "fire": "119"},
        "plugTypes": ["C", "F"],
        "voltage": "220V",
        "sourceUrl": source_url(sha),
    }]


def country_source() -> list[dict]:
    return [{
        "cca2": "JP", "name": {"common": "Japan"},
        "currencies": {"JPY": {}}, "languages": {"jpn": "Japanese"},
    }, {
        "cca2": "KR", "name": {"common": "South Korea"},
        "currencies": {"KRW": {}}, "languages": {"kor": "Korean"},
    }]


def city_records() -> list[dict]:
    return [{
        "countryCode": "JP", "cityZh": "東京", "lat": 35.6895,
        "lon": 139.69171, "isDefault": True,
        "sourceUrl": "https://www.geonames.org/1850147",
    }]


def geonames_archive() -> bytes:
    row = ["1850147", "Tokyo", "Tokyo", "Tokyo,東京", "35.6895", "139.69171",
           "P", "PPLC", "JP", "", "", "", "", "", "8336599", "", "", "", ""]
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as archive:
        archive.writestr("cities15000.txt", "\t".join(row) + "\n")
    return data.getvalue()


class CountryProvenanceTests(unittest.TestCase):
    def assert_provenance_change(self, old, new, expected):
        before = copy.deepcopy((old, new))
        self.assertIs(fetch_reference.is_country_provenance_only_change(old, new), expected)
        self.assertEqual((old, new), before, "Comparison must not mutate its inputs")

    def test_only_trusted_source_commits_may_change(self):
        self.assert_provenance_change(country_records(), country_records(NEW_SHA), True)

    def test_unchanged_records_do_not_count_as_commit_updates(self):
        self.assert_provenance_change(country_records(), country_records(), False)
        self.assert_provenance_change([], [], False)

    def test_some_records_may_keep_their_existing_source_commit(self):
        updated = country_records(NEW_SHA)
        updated[0]["sourceUrl"] = source_url(OLD_SHA)
        self.assert_provenance_change(country_records(), updated, True)

    def test_hex_case_is_supported_but_is_not_a_different_commit(self):
        self.assert_provenance_change(country_records(OLD_SHA.upper()), country_records(NEW_SHA), True)
        self.assert_provenance_change(country_records(OLD_SHA.upper()), country_records(), False)

    def test_json_object_key_order_is_not_substantive(self):
        updated = [dict(reversed(list(record.items()))) for record in country_records(NEW_SHA)]
        updated[0]["emergency"] = dict(reversed(list(updated[0]["emergency"].items())))
        self.assert_provenance_change(country_records(), updated, True)

    def test_every_non_source_field_is_checked(self):
        changes = {
            "code": "TW", "nameZh": "新版日本", "nameEn": "New Japan",
            "currencyCode": "USD", "languageCode": "en",
            "emergency": {"police": "911", "ambulance": "119", "fire": "119"},
            "plugTypes": ["B", "A"], "voltage": "110V", "unknownField": "new",
        }
        for key, value in changes.items():
            with self.subTest(field=key):
                updated = country_records(NEW_SHA)
                updated[0][key] = value
                self.assert_provenance_change(country_records(), updated, False)
        updated = country_records(NEW_SHA)
        del updated[0]["nameEn"]
        self.assert_provenance_change(country_records(), updated, False)

    def test_json_type_changes_are_not_ignored(self):
        for old_value, new_value in [(True, 1), (1, 1.0), ("1", 1)]:
            with self.subTest(old=old_value, new=new_value):
                old, new = country_records(), country_records(NEW_SHA)
                old[0]["extra"] = old_value
                new[0]["extra"] = new_value
                self.assert_provenance_change(old, new, False)

    def test_record_additions_removals_and_reordering_fail(self):
        updated = country_records(NEW_SHA)
        for records in [updated[:1], updated + [copy.deepcopy(updated[0])], list(reversed(updated))]:
            with self.subTest(records=records):
                self.assert_provenance_change(country_records(), records, False)

    def test_malformed_or_untrusted_urls_are_never_exempted(self):
        valid = source_url(OLD_SHA)
        invalid_urls = [
            None, 123, "", "countries.json", valid + "?raw=true", valid + "?",
            valid + "#L1", valid + "#", valid + "/", valid + "\n", " " + valid,
            valid.replace("https://", "http://"),
            valid.replace("github.com", "github.com.example.org"),
            valid.replace("github.com", "github.com@evil.example"),
            valid.replace("github.com", "user@github.com"),
            valid.replace("github.com", "github.com:443"),
            valid.replace("github.com", "raw.githubusercontent.com"),
            valid.replace("mledoze", "someone-else"),
            valid.replace("/countries/blob/", "/countries-fork/blob/"),
            valid.replace("/blob/", "/tree/"),
            valid.replace("/countries.json", "/other.json"),
            valid.replace("/countries.json", "/data/countries.json"),
            valid.replace("/countries.json", "/../countries.json"),
            valid.replace(OLD_SHA, "master"),
            valid.replace(OLD_SHA, OLD_SHA[:7]),
            valid.replace(OLD_SHA, "a" * 39),
            valid.replace(OLD_SHA, "a" * 41),
            valid.replace(OLD_SHA, "g" * 40),
        ]
        for url in invalid_urls:
            for side in ("old", "new"):
                with self.subTest(url=url, side=side):
                    old, new = country_records(), country_records(NEW_SHA)
                    records = old if side == "old" else new
                    records[0]["sourceUrl"] = url
                    self.assert_provenance_change(old, new, False)

    def test_missing_sources_are_not_exempted(self):
        for side in ("old", "new", "both"):
            with self.subTest(side=side):
                old, new = country_records(), country_records(NEW_SHA)
                if side in ("old", "both"):
                    del old[0]["sourceUrl"]
                if side in ("new", "both"):
                    del new[0]["sourceUrl"]
                self.assert_provenance_change(old, new, False)


class ReferenceCLITests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.seed_dir = Path(self.directory.name)
        self.write_countries(country_records())
        self.write_cities(city_records())

    def write_countries(self, records):
        (self.seed_dir / "countries.json").write_text(
            fetch_reference.render_countries(records), encoding="utf-8")

    def write_cities(self, records):
        (self.seed_dir / "cities.json").write_text(
            fetch_reference.render_cities(records), encoding="utf-8")

    def invoke(self, *arguments, sha=NEW_SHA, source=None, check_no_writes=True):
        source = country_source() if source is None else source
        responses = {
            "https://api.github.com/repos/mledoze/countries/commits/master": sha.encode(),
            f"https://raw.githubusercontent.com/mledoze/countries/{sha}/countries.json":
                json.dumps(source).encode(),
            fetch_reference.GEONAMES_DUMP_URL: geonames_archive(),
        }

        def fake_fetch(url, accept=None):
            self.assertIn(url, responses, "Unexpected network request")
            return responses[url]

        before = {path.name: path.read_bytes() for path in self.seed_dir.iterdir()}
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(fetch_reference, "SEED_DIR", self.seed_dir), \
                patch.object(fetch_reference, "fetch", side_effect=fake_fetch) as network, \
                patch("sys.argv", [str(SCRIPT_PATH), *arguments]), \
                redirect_stdout(stdout), redirect_stderr(stderr):
            if check_no_writes:
                with patch.object(Path, "write_text", side_effect=AssertionError("Unexpected write")):
                    result = fetch_reference.main()
            else:
                result = fetch_reference.main()
        if check_no_writes:
            self.assertEqual({path.name: path.read_bytes() for path in self.seed_dir.iterdir()}, before)
        return result, stdout.getvalue(), stderr.getvalue(), network

    def test_check_provenance_drift_is_informational_and_does_not_write(self):
        result, stdout, stderr, network = self.invoke("--check")
        self.assertEqual(result, 0)
        self.assertIn("countries.json：僅來源 commit 更新", stdout)
        self.assertIn("cities.json：無變更", stdout)
        self.assertNotIn("--- a/", stdout)
        self.assertEqual(stderr, "")
        self.assertEqual(network.call_count, 3)

    def test_check_identical_data_succeeds(self):
        result, stdout, stderr, _ = self.invoke("--check", sha=OLD_SHA)
        self.assertEqual(result, 0)
        self.assertIn("countries.json：無變更", stdout)
        self.assertNotIn("僅來源 commit 更新", stdout)
        self.assertEqual(stderr, "")

    def test_update_still_refreshes_provenance_and_preserves_country_fields(self):
        old_cities = (self.seed_dir / "cities.json").read_bytes()
        result, stdout, stderr, _ = self.invoke("--only", "countries", check_no_writes=False)
        self.assertEqual(result, 0)
        self.assertIn("countries.json：已更新", stdout)
        self.assertIn("--- a/countries.json", stdout)
        self.assertEqual(stderr, "")
        actual = json.loads((self.seed_dir / "countries.json").read_text(encoding="utf-8"))
        self.assertEqual(actual, country_records(NEW_SHA))
        self.assertEqual((self.seed_dir / "cities.json").read_bytes(), old_cities)

    def test_check_real_upstream_country_changes_fail(self):
        for key, value in [("name", {"common": "New Japan"}), ("currencies", {"USD": {}}),
                           ("languages", {"eng": "English"})]:
            with self.subTest(field=key):
                source = country_source()
                source[0][key] = value
                result, stdout, stderr, _ = self.invoke("--check", "--only", "countries", source=source)
                self.assertEqual(result, 1)
                self.assertIn("--- a/countries.json", stdout)
                self.assertIn("與開放資料不一致：countries.json", stderr)
                self.assertNotIn("僅來源 commit 更新", stdout)

    def test_untrusted_country_provenance_still_fails_check(self):
        records = country_records()
        records[0]["sourceUrl"] = source_url(OLD_SHA) + "?raw=true"
        self.write_countries(records)
        result, stdout, stderr, _ = self.invoke("--check", "--only", "countries")
        self.assertEqual(result, 1)
        self.assertIn("countries.json", stderr)
        self.assertNotIn("僅來源 commit 更新", stdout)

    def test_missing_country_source_still_fails_check(self):
        records = country_records()
        del records[0]["sourceUrl"]
        self.write_countries(records)
        result, _, stderr, _ = self.invoke("--check", "--only", "countries")
        self.assertEqual(result, 1)
        self.assertIn("countries.json", stderr)

    def test_dropped_unknown_country_field_still_fails_check(self):
        records = country_records()
        records[0]["unexpected"] = "preserve detection"
        self.write_countries(records)
        result, _, stderr, _ = self.invoke("--check", "--only", "countries")
        self.assertEqual(result, 1)
        self.assertIn("countries.json", stderr)

    def test_city_drift_still_fails_alongside_country_provenance_only_changes(self):
        records = city_records()
        records[0]["lat"] = 0.0
        self.write_cities(records)
        result, stdout, stderr, _ = self.invoke("--check")
        self.assertEqual(result, 1)
        self.assertIn("countries.json：僅來源 commit 更新", stdout)
        self.assertIn("--- a/cities.json", stdout)
        self.assertIn("與開放資料不一致：cities.json", stderr)
        self.assertNotIn("countries.json", stderr)

    def test_city_coordinates_and_sources_remain_strict(self):
        for field, value in [("lat", 0.0), ("lon", 0.0),
                             ("sourceUrl", "https://www.geonames.org/1850147?old=1")]:
            with self.subTest(field=field):
                records = city_records()
                records[0][field] = value
                self.write_cities(records)
                result, stdout, stderr, network = self.invoke("--check", "--only", "cities")
                self.assertEqual(result, 1)
                self.assertIn("--- a/cities.json", stdout)
                self.assertIn("cities.json", stderr)
                self.assertEqual(network.call_count, 1)
                network.assert_called_once_with(fetch_reference.GEONAMES_DUMP_URL)

    def test_formatting_only_drift_without_commit_change_remains_strict(self):
        (self.seed_dir / "countries.json").write_text(json.dumps(country_records()), encoding="utf-8")
        result, _, stderr, _ = self.invoke("--check", "--only", "countries", sha=OLD_SHA)
        self.assertEqual(result, 1)
        self.assertIn("countries.json", stderr)

    def test_build_errors_keep_exit_code_two(self):
        records = country_records()
        del records[0]["emergency"]
        self.write_countries(records)
        for arguments in [("--check", "--only", "countries"), ("--only", "countries")]:
            with self.subTest(arguments=arguments):
                result, _, stderr, _ = self.invoke(*arguments)
                self.assertEqual(result, 2)
                self.assertIn("缺少策展欄位 emergency", stderr)


if __name__ == "__main__":
    unittest.main()
