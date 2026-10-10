#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_root=$(mktemp -d /private/tmp/packmon-recommendation-tests.XXXXXX)
mkdir -p "$test_root/run" "$test_root/module-cache"
cp TravelGenius/Resources/SeedData/*.json "$test_root/run/"

xcrun swiftc -parse-as-library -module-name PackingRegression -module-cache-path "$test_root/module-cache" TravelGenius/Models/*.swift TravelGenius/Services/UserPreferences.swift TravelGenius/Services/StaticDataStore.swift TravelGenius/Services/ReferenceDataUpdater.swift TravelGenius/Services/PackingCatalog.swift TravelGenius/Services/PackingRuleEngine.swift TravelGenius/Services/PackingStaples.swift TravelGenius/Services/PackingLibraryStore.swift TravelGenius/Services/WeatherPlanning.swift TravelGenius/Services/PackingListGenerator.swift scripts/PackingRegression.swift -o "$test_root/run/PackingRegression"

"$test_root/run/PackingRegression"
echo "Single-engine evidence retained at $test_root"
