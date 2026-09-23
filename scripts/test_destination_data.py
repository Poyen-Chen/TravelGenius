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


if __name__ == "__main__":
    unittest.main()
