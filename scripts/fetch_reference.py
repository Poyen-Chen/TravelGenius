#!/usr/bin/env python3
"""由開放資料重建 SeedData/countries.json 與 cities.json。

資料來源（皆免 API key）：
  - 國家：mledoze/countries（ODbL），REST Countries 的上游開源資料集。
    REST Countries v5 起需要帳號與 API key，因此直接讀上游，並釘住 commit SHA。
  - 城市：GeoNames cities15000 全量檔（CC BY 4.0），不需 GeoNames 帳號。

欄位分工：
  - 自動欄位（每次覆寫）：countries 的 nameEn / currencyCode / languageCode，
    cities 的 lat / lon，以及兩者的 sourceUrl。
  - 策展欄位（沿用現有 JSON）：countries 的 nameZh / emergency / plugTypes / voltage，
    cities 的 countryCode / cityZh / isDefault。

新增資料的方式：
  - 國家：在 countries.json 加一筆只含 code 與策展欄位的物件，再跑本腳本。
  - 城市：在 cities.json 加 {"countryCode", "cityZh", "isDefault"}，腳本以中文名稱
    比對 GeoNames 別名；比對不到時，手動填 "sourceUrl": "https://www.geonames.org/<id>"。

用法：
  python3 scripts/fetch_reference.py            # 更新兩個檔案
  python3 scripts/fetch_reference.py --check    # 只比對，有差異時 exit 1（供 CI）
  python3 scripts/fetch_reference.py --only cities
"""

from __future__ import annotations

import argparse
import csv
import difflib
import io
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = ROOT / "TravelGenius" / "Resources" / "SeedData"

COUNTRIES_REPO = "mledoze/countries"
GEONAMES_DUMP_URL = "https://download.geonames.org/export/dump/cities15000.zip"
USER_AGENT = "TravelGenius-fetch_reference/1.0"

# ISO 639-3（資料源）轉成 app 使用的語言代碼
LANGUAGE_CODES = {
    "ara": "ar", "ces": "cs", "dan": "da", "deu": "de", "ell": "el", "eng": "en",
    "fin": "fi", "fra": "fr", "hin": "hi", "hun": "hu", "ind": "id", "ita": "it",
    "jpn": "ja", "kor": "ko", "msa": "ms", "nld": "nl", "nor": "no", "pol": "pl",
    "por": "pt", "rus": "ru", "spa": "es", "swe": "sv", "tha": "th", "tur": "tr",
    "vie": "vi", "zho": "zh",
}
# 資料源無法表達文字系統的國家，由人工指定
LANGUAGE_OVERRIDES = {"TW": "zh-Hant", "HK": "zh-Hant", "MO": "zh-Hant", "CN": "zh-Hans"}

COUNTRY_CURATED_FIELDS = ("nameZh", "emergency", "plugTypes", "voltage")
CITY_CURATED_FIELDS = ("countryCode", "cityZh", "isDefault")
GEONAMES_ID_PATTERN = re.compile(r"geonames\.org/(\d+)")


class DataError(Exception):
    pass


def fetch(url: str, accept: str | None = None) -> bytes:
    headers = {"User-Agent": USER_AGENT}
    if accept:
        headers["Accept"] = accept
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


# MARK: - Countries

def resolve_countries_sha(ref: str) -> str:
    url = f"https://api.github.com/repos/{COUNTRIES_REPO}/commits/{ref}"
    sha = fetch(url, accept="application/vnd.github.sha").decode().strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise DataError(f"無法解析 {COUNTRIES_REPO}@{ref} 的 commit SHA：{sha[:80]}")
    return sha


def build_countries(existing: list[dict], ref: str) -> list[dict]:
    sha = resolve_countries_sha(ref)
    raw_url = f"https://raw.githubusercontent.com/{COUNTRIES_REPO}/{sha}/countries.json"
    source_url = f"https://github.com/{COUNTRIES_REPO}/blob/{sha}/countries.json"
    source = {entry["cca2"]: entry for entry in json.loads(fetch(raw_url))}
    print(f"countries：{COUNTRIES_REPO}@{sha[:7]}，共 {len(source)} 國")

    errors: list[str] = []
    output: list[dict] = []
    for record in existing:
        code = record.get("code")
        entry = source.get(code)
        if entry is None:
            errors.append(f"{code}：資料源找不到此 ISO 3166-1 alpha-2 代碼")
            continue
        missing = [field for field in COUNTRY_CURATED_FIELDS if field not in record]
        if missing:
            errors.append(f"{code}：缺少策展欄位 {', '.join(missing)}")
            continue

        currencies = list(entry.get("currencies") or {})
        languages = list(entry.get("languages") or {})
        language = LANGUAGE_OVERRIDES.get(code)
        if language is None and languages:
            language = LANGUAGE_CODES.get(languages[0])
        if not currencies or language is None:
            errors.append(
                f"{code}：無法推導貨幣或語言（currencies={currencies}, languages={languages}），"
                "請補 LANGUAGE_CODES 或 LANGUAGE_OVERRIDES"
            )
            continue

        output.append({
            "code": code,
            "nameZh": record["nameZh"],
            "nameEn": entry["name"]["common"],
            "currencyCode": currencies[0],
            "languageCode": language,
            "emergency": record["emergency"],
            "plugTypes": record["plugTypes"],
            "voltage": record["voltage"],
            "sourceUrl": source_url,
        })

    if errors:
        raise DataError("countries.json 有問題：\n  " + "\n  ".join(errors))
    return output


# MARK: - Cities

def load_geonames_rows() -> list[list[str]]:
    archive = zipfile.ZipFile(io.BytesIO(fetch(GEONAMES_DUMP_URL)))
    with archive.open("cities15000.txt") as handle:
        text = io.TextIOWrapper(handle, encoding="utf-8")
        return list(csv.reader(text, delimiter="\t", quoting=csv.QUOTE_NONE))


def build_cities(existing: list[dict]) -> list[dict]:
    rows = load_geonames_rows()
    by_id = {row[0]: row for row in rows}
    print(f"cities：GeoNames cities15000，共 {len(rows)} 筆")

    errors: list[str] = []
    output: list[dict] = []
    for record in existing:
        missing = [field for field in CITY_CURATED_FIELDS if field not in record]
        if missing:
            errors.append(f"{record}：缺少策展欄位 {', '.join(missing)}")
            continue
        country, name = record["countryCode"], record["cityZh"]
        label = f"{country}-{name}"

        pinned = GEONAMES_ID_PATTERN.search(record.get("sourceUrl") or "")
        if pinned:
            row = by_id.get(pinned.group(1))
            if row is None:
                errors.append(f"{label}：GeoNames {pinned.group(1)} 不在 cities15000（人口不足或已刪除）")
                continue
            if row[8] != country:
                errors.append(f"{label}：GeoNames {row[0]} 屬於 {row[8]}，與 countryCode 不符")
                continue
        else:
            candidates = [r for r in rows if r[8] == country and name in r[3].split(",")]
            if not candidates:
                errors.append(
                    f"{label}：GeoNames 別名比對不到，請手動填 "
                    '"sourceUrl": "https://www.geonames.org/<id>"'
                )
                continue
            candidates.sort(key=lambda r: int(r[14] or 0), reverse=True)
            row = candidates[0]
            if len(candidates) > 1:
                others = ", ".join(f"{r[1]}({r[0]})" for r in candidates[1:4])
                print(f"  注意 {label}：有 {len(candidates)} 個同名地點，取人口最多的 {row[1]}；其他：{others}")

        output.append({
            "countryCode": country,
            "cityZh": name,
            "lat": float(row[4]),
            "lon": float(row[5]),
            "isDefault": record["isDefault"],
            "sourceUrl": f"https://www.geonames.org/{row[0]}",
        })

    if errors:
        raise DataError("cities.json 有問題：\n  " + "\n  ".join(errors))
    return output


# MARK: - Output（維持現有檔案的排版，讓 git diff 好 review）

def compact(value) -> str:
    if isinstance(value, dict):
        inner = ", ".join(f"{json.dumps(k, ensure_ascii=False)}: {compact(v)}" for k, v in value.items())
        return "{ " + inner + " }"
    if isinstance(value, list):
        return "[" + ", ".join(compact(v) for v in value) + "]"
    return json.dumps(value, ensure_ascii=False)


def render_countries(records: list[dict]) -> str:
    blocks = []
    for record in records:
        lines = [f"    {json.dumps(k, ensure_ascii=False)}: {compact(v)}" for k, v in record.items()]
        blocks.append("  {\n" + ",\n".join(lines) + "\n  }")
    return "[\n" + ",\n".join(blocks) + "\n]\n"


def render_cities(records: list[dict]) -> str:
    return "[\n" + ",\n".join(f"  {compact(r)}" for r in records) + "\n]\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="只比對不寫檔，有差異時 exit 1")
    parser.add_argument("--only", choices=("countries", "cities"), help="只處理其中一個檔案")
    parser.add_argument("--countries-ref", default="master", help="mledoze/countries 的 branch、tag 或 SHA")
    args = parser.parse_args()

    jobs = {
        "countries": lambda data: render_countries(build_countries(data, args.countries_ref)),
        "cities": lambda data: render_cities(build_cities(data)),
    }
    changed = []
    try:
        for name, job in jobs.items():
            if args.only and args.only != name:
                continue
            path = SEED_DIR / f"{name}.json"
            current = path.read_text(encoding="utf-8")
            updated = job(json.loads(current))
            if updated == current:
                print(f"  {path.name}：無變更")
                continue
            changed.append(path.name)
            diff = difflib.unified_diff(
                current.splitlines(), updated.splitlines(),
                fromfile=f"a/{path.name}", tofile=f"b/{path.name}", lineterm="",
            )
            print("\n".join(diff))
            if not args.check:
                path.write_text(updated, encoding="utf-8")
                print(f"  {path.name}：已更新")
    except DataError as error:
        print(f"錯誤：{error}", file=sys.stderr)
        return 2

    if args.check and changed:
        print(f"與開放資料不一致：{', '.join(changed)}（請執行 scripts/fetch_reference.py）", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
