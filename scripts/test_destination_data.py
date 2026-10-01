"""Stage 1 bundled destination contract; run with python3 scripts/test_destination_data.py."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA = ROOT / "TravelGenius/Resources/SeedData"


class DestinationDataTests(unittest.TestCase):
    def test_destination_contract(self):
        countries = json.loads((DATA / "countries.json").read_text())
        cities = json.loads((DATA / "cities.json").read_text())
        codes = [country["code"] for country in countries]
        self.assertEqual(len(codes), len(set(codes)))
        ids = [(city["countryCode"], city["cityZh"]) for city in cities]
        self.assertEqual(len(ids), len(set(ids)))
        source = (ROOT / "TravelGenius/Services/StaticDataStore.swift").read_text()
        self.assertIn('destinationCountryCodes = ["JP", "KR", "HK", "US", "VN"]', source)
        for code in ["JP", "KR", "HK", "US", "VN", "TW"]:
            with self.subTest(country=code):
                self.assertIn(code, codes)
                choices = [city for city in cities if city["countryCode"] == code]
                self.assertTrue(choices)
                self.assertEqual(sum(city["isDefault"] for city in choices), 1)
        for city in cities:
            self.assertIn(city["countryCode"], codes)
            self.assertTrue(-90 <= city["lat"] <= 90)
            self.assertTrue(-180 <= city["lon"] <= 180)
        # Existing trip identifiers must remain resolvable.
        for key in [("TW", "台北"), ("JP", "東京"), ("JP", "大阪"), ("JP", "京都"), ("KR", "首爾"), ("KR", "釜山")]:
            self.assertIn(key, ids)

    def test_supported_border_rule_contract(self):
        border = json.loads((DATA / "border_rules.json").read_text())
        prohibited = json.loads((DATA / "prohibited_items.json").read_text())
        aviation = json.loads((DATA / "aviation_rules.json").read_text())
        supported = {"TW", "JP", "KR", "HK", "US", "VN"}

        self.assertEqual(len({rule["id"] for rule in border}), len(border))
        self.assertTrue(all(rule["sourceUrl"].startswith("https://") for rule in border))
        self.assertTrue(all(rule["lastVerified"] == "2026-09-28" for rule in border))
        self.assertTrue(all("countries" not in rule for rule in aviation))

        expected = {("TW", "originDeparture"), ("TW", "originArrival")}
        expected |= {(code, checkpoint) for code in supported - {"TW"} for checkpoint in ["destinationArrival", "destinationDeparture"]}
        actual = {(rule["countryCode"], rule["checkpoint"]) for rule in border}
        self.assertTrue(expected <= actual)

        departure_coverage = {code for rule in aviation for code in rule.get("departureCountries", [])}
        self.assertTrue(supported <= departure_coverage)

        current_tax_free = next(rule for rule in border if rule["id"] == "jp-depart-tax-free-before-refund")
        future_tax_free = next(rule for rule in border if rule["id"] == "jp-depart-tax-free-refund-method")
        self.assertEqual(current_tax_free["effectiveUntil"], "2026-10-31")
        self.assertEqual(future_tax_free["effectiveFrom"], "2026-11-01")

        records = {(rule["countryCode"], rule["itemZh"]): rule for rule in prohibited}
        self.assertEqual(records[("KR", "肉品、動物與農產品")]["severity"], "declare")
        self.assertEqual(records[("US", "食品與農產品")]["severity"], "declare")
        self.assertEqual(records[("HK", "另類吸煙產品")]["severity"], "banned")
        self.assertEqual(records[("VN", "電子煙與加熱煙產品")]["severity"], "banned")
        self.assertEqual(records[("TW", "電子煙與未核准加熱菸")]["severity"], "banned")
        self.assertFalse(any(rule["itemZh"] == "健達出奇蛋" for rule in prohibited))


if __name__ == "__main__":
    unittest.main()
