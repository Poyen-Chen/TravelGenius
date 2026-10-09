"""Regression coverage for the Swift packing catalog / rule data contract."""

from __future__ import annotations

import contextlib
import copy
import datetime
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import validate_seed


class SeedValidationTests(unittest.TestCase):
    def setUp(self):
        self.data = {
            name: json.loads((validate_seed.SEED_DIR / f"{name}.json").read_text(encoding="utf-8"))
            for name in validate_seed.FILES
        }
        self.rule = {"id": "test-rule", "reasonZh": "測試", "needs": [{"itemId": "passport"}]}
        self.item = {"id": "test-item", "nameZh": "物品", "category": "other"}

    def schema_errors(self, name, records):
        schema = json.loads((validate_seed.SCHEMA_DIR / f"{name}.schema.json").read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
        return list(Draft202012Validator(schema).iter_errors(records))

    def consistency(self):
        report = validate_seed.Report()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            validate_seed.check_consistency(self.data, report)
        return report, output.getvalue()

    def run_main(self, data=None, *, missing=None, raw=None):
        with tempfile.TemporaryDirectory() as directory:
            seed_dir = Path(directory)
            for name, records in (self.data if data is None else data).items():
                if name == missing:
                    continue
                text = raw[name] if raw and name in raw else json.dumps(records, ensure_ascii=False)
                (seed_dir / f"{name}.json").write_text(text, encoding="utf-8")
            output = io.StringIO()
            with patch.object(validate_seed, "SEED_DIR", seed_dir), \
                 patch.object(sys, "argv", ["validate_seed.py", "--today", "2026-10-05"]), \
                 contextlib.redirect_stdout(output):
                result = validate_seed.main()
            return result, output.getvalue()

    def test_checked_in_seed_data_passes_schemas_and_consistency(self):
        report = validate_seed.Report()
        with contextlib.redirect_stdout(io.StringIO()):
            validate_seed.check_schemas(self.data, report)
            validate_seed.check_consistency(self.data, report)
        self.assertEqual(report.errors, 0)
        self.assertIn("packing_items", validate_seed.FILES)
        self.assertEqual(set(validate_seed.FILES), {
            "countries", "cities", "packing_items", "packing_rules",
            "prohibited_items", "aviation_rules", "etiquette",
        })

    def test_current_rule_contract_and_optional_fields(self):
        self.rule["when"] = {"all": ["country:JP"], "any": ["weather:rain", "weather:cold"], "none": ["style:light"]}
        self.rule["needs"] = [
            {"itemId": "passport", "quantity": 2, "perDay": False, "when": {}},
            {"need": "rain-cover", "perDay": True, "when": {"none": ["style:light"]}},
        ]
        self.assertFalse(self.schema_errors("packing_rules", [self.rule]))

    def test_empty_conditions_and_tag_lists_follow_swift_set_algebra(self):
        for condition in ({}, {"all": []}, {"any": []}, {"none": []}):
            with self.subTest(condition=condition):
                self.rule["when"] = condition
                self.rule["needs"][0]["when"] = condition
                self.assertFalse(self.schema_errors("packing_rules", [self.rule]))

    def test_legacy_and_unknown_rule_fields_are_rejected(self):
        legacy = {"layer": "base", "reasonZh": "舊規則", "items": [{"nameZh": "護照", "category": "documents"}]}
        self.assertTrue(self.schema_errors("packing_rules", [legacy]))
        for key in ("layer", "match", "items", "fullOnly", "typo"):
            with self.subTest(key=key):
                self.assertTrue(self.schema_errors("packing_rules", [{**self.rule, key: {}}]))

    def test_required_rule_fields_and_nonempty_collections(self):
        for key in ("id", "reasonZh", "needs"):
            rule = copy.deepcopy(self.rule)
            del rule[key]
            with self.subTest(missing=key):
                self.assertTrue(self.schema_errors("packing_rules", [rule]))
        for changes in ({"id": ""}, {"reasonZh": ""}, {"needs": []}):
            with self.subTest(changes=changes):
                self.assertTrue(self.schema_errors("packing_rules", [{**self.rule, **changes}]))
        self.assertTrue(self.schema_errors("packing_rules", []))

    def test_need_requires_exactly_one_reference(self):
        for need in ({}, {"itemId": "passport", "need": "rain-cover"}, {"itemId": ""}, {"need": ""}):
            with self.subTest(need=need):
                self.rule["needs"] = [need]
                self.assertTrue(self.schema_errors("packing_rules", [self.rule]))

    def test_invalid_need_fields_are_rejected(self):
        for changes in ({"quantity": 0}, {"quantity": -1}, {"quantity": 1.5}, {"quantity": True},
                        {"perDay": "true"}, {"fullOnly": True}, {"itemID": "passport"}):
            with self.subTest(changes=changes):
                self.rule["needs"] = [{"itemId": "passport", **changes}]
                self.assertTrue(self.schema_errors("packing_rules", [self.rule]))

    def test_malformed_conditions_at_both_levels_are_rejected(self):
        malformed = [None, [], "country:JP", {"and": ["country:JP"]}]
        for operator in ("all", "any", "none"):
            malformed.extend({operator: value} for value in ("country:JP", None, [1], [""], ["country:JP", "country:JP"]))
        for level in ("rule", "need"):
            for condition in malformed:
                with self.subTest(level=level, condition=condition):
                    rule = copy.deepcopy(self.rule)
                    target = rule if level == "rule" else rule["needs"][0]
                    target["when"] = condition
                    self.assertTrue(self.schema_errors("packing_rules", [rule]))

    def test_catalog_contract_and_optional_fields(self):
        self.assertFalse(self.schema_errors("packing_items", [self.item]))
        item = {**self.item, "weightGrams": 0, "priority": -1, "tags": [], "satisfies": ["rain-cover"]}
        self.assertFalse(self.schema_errors("packing_items", [item]))

    def test_invalid_catalog_fields_are_rejected(self):
        for key in ("id", "nameZh", "category"):
            item = copy.deepcopy(self.item)
            del item[key]
            with self.subTest(missing=key):
                self.assertTrue(self.schema_errors("packing_items", [item]))
        invalid = [{"id": ""}, {"nameZh": ""}, {"category": "typo"}, {"weightGrams": -1},
                   {"weightGrams": 1.5}, {"weightGrams": True}, {"priority": 1.5}, {"priority": "1"},
                   {"tags": "bulky"}, {"tags": ["bulky", "bulky"]}, {"tags": [""]},
                   {"satisfies": [1]}, {"satisfies": ["rain-cover", "rain-cover"]}, {"typo": True}]
        for changes in invalid:
            with self.subTest(changes=changes):
                self.assertTrue(self.schema_errors("packing_items", [{**self.item, **changes}]))
        self.assertTrue(self.schema_errors("packing_items", []))

    def test_duplicate_catalog_and_rule_ids_rejected_even_if_other_fields_differ(self):
        for name, field in (("packing_items", "nameZh"), ("packing_rules", "reasonZh")):
            with self.subTest(name=name):
                duplicate = {**copy.deepcopy(self.data[name][0]), field: "另一筆資料"}
                self.data[name].append(duplicate)
                report, output = self.consistency()
                self.assertEqual(report.errors, 1)
                self.assertIn(f"{name}.json", output)
                self.assertIn(duplicate["id"], output)
                self.data[name].pop()

    def test_unresolved_item_and_need_references_rejected_even_when_conditional(self):
        self.data["packing_rules"] = [{**self.rule, "needs": [
            {"itemId": "missing-item", "when": {"any": []}},
            {"need": "missing-need"},
        ]}]
        report, output = self.consistency()
        self.assertEqual(report.errors, 2)
        self.assertIn("needs[0]", output)
        self.assertIn("missing-item", output)
        self.assertIn("needs[1]", output)
        self.assertIn("missing-need", output)

    def test_multiple_catalog_candidates_for_a_need_are_valid(self):
        self.data["packing_items"] = [
            {**self.item, "id": "candidate-a", "satisfies": ["shared"]},
            {**self.item, "id": "candidate-b", "satisfies": ["shared"], "priority": 20},
        ]
        self.data["packing_rules"] = [{**self.rule, "needs": [{"need": "shared"}]}]
        report, _ = self.consistency()
        self.assertEqual(report.errors, 0)

    def test_country_and_origin_references_checked_in_all_condition_positions(self):
        for level in ("rule", "need"):
            for operator in ("all", "any", "none"):
                for prefix in ("country", "origin"):
                    with self.subTest(level=level, operator=operator, prefix=prefix):
                        rule = copy.deepcopy(self.rule)
                        target = rule if level == "rule" else rule["needs"][0]
                        target["when"] = {operator: [f"{prefix}:ZZ"]}
                        self.data["packing_rules"] = [rule]
                        report, output = self.consistency()
                        self.assertEqual(report.errors, 1)
                        self.assertIn(f"{prefix}:ZZ", output)
                        self.assertIn(f"when.{operator}", output)

    def test_valid_country_origin_and_non_geographic_tags(self):
        self.rule["when"] = {"all": ["country:JP", "origin:TW", "weather:rain"]}
        self.rule["needs"][0]["when"] = {"any": ["country:KR"], "none": ["origin:JP", "style:light"]}
        self.data["packing_rules"] = [self.rule]
        report, _ = self.consistency()
        self.assertEqual(report.errors, 0)

    def test_cli_rejects_missing_or_malformed_catalog(self):
        result, output = self.run_main(missing="packing_items")
        self.assertEqual(result, 1)
        self.assertIn("packing_items.json", output)
        result, output = self.run_main(raw={"packing_items": "[broken"})
        self.assertEqual(result, 1)
        self.assertIn("packing_items.json", output)

    def test_cli_schema_error_does_not_enter_consistency_or_crash(self):
        for malformed in (None, 1, [{"nameZh": "缺 id"}]):
            with self.subTest(malformed=malformed):
                data = {**self.data, "packing_items": malformed}
                with patch.object(validate_seed, "check_consistency") as consistency:
                    result, output = self.run_main(data)
                self.assertEqual(result, 1)
                self.assertIn("packing_items.json", output)
                consistency.assert_not_called()

    def test_staleness_still_distinguishes_warnings_errors_and_future_dates(self):
        data = copy.deepcopy(self.data)
        for name in validate_seed.VERIFIED_FILES:
            for record in data[name]:
                record["lastVerified"] = "2026-06"
        cases = [(datetime.date(2026, 10, 5), True, 0, 0),
                 (datetime.date(2027, 1, 1), False, 0, 2),
                 (datetime.date(2027, 1, 1), True, 2, 0),
                 (datetime.date(2026, 5, 1), False, 2, 0)]
        for today, fail, errors, warnings in cases:
            with self.subTest(today=today, fail=fail):
                report = validate_seed.Report()
                with contextlib.redirect_stdout(io.StringIO()):
                    validate_seed.check_staleness(data, report, today, 6, fail)
                self.assertEqual((report.errors, report.warnings), (errors, warnings))


if __name__ == "__main__":
    unittest.main()
