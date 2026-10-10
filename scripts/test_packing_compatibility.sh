#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_root=$(mktemp -d /private/tmp/packmon-recommendation-tests.XXXXXX)
mkdir -p "$test_root/run" "$test_root/module-cache"
cp TravelGenius/Resources/SeedData/*.json "$test_root/run/"

xcrun swiftc -parse-as-library -module-name PackingRegression -module-cache-path "$test_root/module-cache" TravelGenius/Models/*.swift TravelGenius/Services/UserPreferences.swift TravelGenius/Services/StaticDataStore.swift TravelGenius/Services/ReferenceDataUpdater.swift TravelGenius/Services/PackingCatalog.swift TravelGenius/Services/PackingRuleEngine.swift TravelGenius/Services/PackingStaples.swift TravelGenius/Services/PackingLibraryStore.swift TravelGenius/Services/WeatherPlanning.swift TravelGenius/Services/PackingListGenerator.swift scripts/PackingCompatibility.swift -o "$test_root/run/PackingRegression"

"$test_root/run/PackingRegression" "$test_root/actual.json"
python3 - "$test_root/actual.json" scripts/fixtures/packing-baseline-sha256.txt <<'PY'
import hashlib, pathlib, sys
assert hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() == pathlib.Path(sys.argv[2]).read_text().strip(), "2,916-case baseline changed"
print("2,916-case pre-integration baseline: PASS")
PY
echo "Single-engine evidence retained at $test_root"
