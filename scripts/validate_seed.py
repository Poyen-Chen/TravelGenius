#!/usr/bin/env python3
"""SeedData 品質閘門：JSON Schema、跨檔一致性、lastVerified 逾期檢查。

檢查項目：
  1. 每個 SeedData/*.json 符合 schemas/<name>.schema.json。
     schema 禁止未知欄位，因為 Swift 的 Codable 會靜默忽略拼錯的 key。
  2. 跨檔一致性：id 不重複（對應 Swift 的 Identifiable.id）、國家代碼都存在於
     countries.json、每國最多一個預設城市。
  3. 逾期：prohibited_items 與 aviation_rules 的 lastVerified 距今超過 N 個月。
     預設只警告；加 --fail-on-stale 時視為錯誤（排程 CI 用來報警）。

用法：
  pip install -r scripts/requirements.txt
  python3 scripts/validate_seed.py
  python3 scripts/validate_seed.py --max-age-months 6 --fail-on-stale
"""

from __future__ import annotations

import argparse
import collections
import datetime
import json
import os
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = ROOT / "TravelGenius" / "Resources" / "SeedData"
SCHEMA_DIR = ROOT / "schemas"

FILES = ("countries", "cities", "packing_rules", "prohibited_items", "aviation_rules", "etiquette")
VERIFIED_FILES = {
    "prohibited_items": lambda r: f"{r['countryCode']}-{r['itemZh']}",
    "aviation_rules": lambda r: r["itemZh"],
}
# 與 StaticDataStore.swift 內各 struct 的 id 相同
ID_KEYS = {
    "countries": lambda r: r["code"],
    "cities": lambda r: f"{r['countryCode']}-{r['cityZh']}",
    "prohibited_items": lambda r: f"{r['countryCode']}-{r['itemZh']}",
    "aviation_rules": lambda r: r["itemZh"],
    "etiquette": lambda r: f"{r['countryCode']}-{r.get('cityZh') or '全國'}-{r['titleZh']}",
}

IN_GITHUB_ACTIONS = os.environ.get("GITHUB_ACTIONS") == "true"


class Report:
    def __init__(self) -> None:
        self.errors = 0
        self.warnings = 0

    def _emit(self, level: str, name: str, message: str) -> None:
        path = f"TravelGenius/Resources/SeedData/{name}.json"
        if IN_GITHUB_ACTIONS:
            escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print(f"::{level} file={path},title={name}.json::{escaped}")
        else:
            tag = "錯誤" if level == "error" else "警告"
            print(f"  [{tag}] {name}.json：{message}")

    def error(self, name: str, message: str) -> None:
        self.errors += 1
        self._emit("error", name, message)

    def warning(self, name: str, message: str) -> None:
        self.warnings += 1
        self._emit("warning", name, message)


def check_schemas(data: dict[str, list], report: Report) -> None:
    for name in FILES:
        schema = json.loads((SCHEMA_DIR / f"{name}.schema.json").read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        for error in sorted(validator.iter_errors(data[name]), key=lambda e: list(map(str, e.absolute_path))):
            location = "/".join(str(part) for part in error.absolute_path) or "(root)"
            report.error(name, f"[{location}] {error.message}")


def check_consistency(data: dict[str, list], report: Report) -> None:
    for name, key in ID_KEYS.items():
        counts = collections.Counter(key(record) for record in data[name])
        for record_id, count in counts.items():
            if count > 1:
                report.error(name, f"id「{record_id}」重複 {count} 次，SwiftUI 列表會顯示錯亂")

    codes = {country["code"] for country in data["countries"]}
    references = {
        "cities": [r["countryCode"] for r in data["cities"]],
        "prohibited_items": [r["countryCode"] for r in data["prohibited_items"]],
        "etiquette": [r["countryCode"] for r in data["etiquette"]],
        "aviation_rules": [c for r in data["aviation_rules"] for c in r.get("countries", [])],
        "packing_rules": [c for r in data["packing_rules"] for c in r.get("match", {}).get("countries", [])],
    }
    for name, used in references.items():
        for code in sorted(set(used) - codes):
            report.error(name, f"國家代碼 {code} 不在 countries.json")

    defaults = collections.Counter(r["countryCode"] for r in data["cities"] if r["isDefault"])
    for code, count in sorted(defaults.items()):
        if count > 1:
            report.error("cities", f"{code} 有 {count} 個 isDefault 城市，最多只能一個")


def check_staleness(data: dict[str, list], report: Report, today: datetime.date, max_age: int, fail: bool) -> None:
    current = today.year * 12 + today.month
    for name, label in VERIFIED_FILES.items():
        stale: list[tuple[int, str, str]] = []
        future: list[str] = []
        for record in data[name]:
            year, month = map(int, record["lastVerified"].split("-"))
            age = current - (year * 12 + month)
            if age < 0:
                future.append(f"{label(record)}（{record['lastVerified']}）")
            elif age > max_age:
                stale.append((age, label(record), record["lastVerified"]))
        if future:
            report.error(name, f"{len(future)} 筆 lastVerified 晚於今天：{'、'.join(future)}")
        if not stale:
            continue
        stale.sort(reverse=True)
        listing = "、".join(f"{item}（{verified}）" for _, item, verified in stale)
        message = f"{len(stale)} 筆超過 {max_age} 個月未查證：{listing}"
        (report.error if fail else report.warning)(name, message)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--max-age-months", type=int, default=6, help="lastVerified 允許的最大月數（預設 6）")
    parser.add_argument("--fail-on-stale", action="store_true", help="逾期視為錯誤，exit 1")
    parser.add_argument("--today", type=datetime.date.fromisoformat, default=datetime.date.today(),
                        help="指定今天日期（YYYY-MM-DD），測試用")
    args = parser.parse_args()
    if args.max_age_months < 1:
        parser.error("--max-age-months 必須至少為 1")

    report = Report()
    data: dict[str, list] = {}
    for name in FILES:
        try:
            data[name] = json.loads((SEED_DIR / f"{name}.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            report.error(name, f"無法讀取或不是合法 JSON：{error}")

    if report.errors == 0:
        check_schemas(data, report)
    # 結構不對時跳過後續檢查，避免一連串 KeyError
    if report.errors == 0:
        check_consistency(data, report)
        check_staleness(data, report, args.today, args.max_age_months, args.fail_on_stale)

    total = sum(len(records) for records in data.values())
    print(f"SeedData 檢查完成：{len(data)} 個檔案、{total} 筆，錯誤 {report.errors}、警告 {report.warnings}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
