#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_root=$(mktemp -d /private/tmp/packsmart-cloud-sync.XXXXXX)
mkdir -p "$test_root/run" "$test_root/module-cache"
cp TravelGenius/Resources/SeedData/*.json "$test_root/run/"

xcrun swiftc -parse-as-library -module-name CloudSyncRegression -module-cache-path "$test_root/module-cache" TravelGenius/Models/*.swift TravelGenius/Services/UserPreferences.swift TravelGenius/Services/StaticDataStore.swift TravelGenius/Services/ReferenceDataUpdater.swift TravelGenius/Services/PackingCatalog.swift TravelGenius/Services/PackingRuleEngine.swift TravelGenius/Services/PackingStaples.swift TravelGenius/Services/PackingLibraryStore.swift TravelGenius/Services/WeatherPlanning.swift TravelGenius/Services/PackingListGenerator.swift TravelGenius/Services/Cloud/*.swift scripts/CloudSyncRegression.swift -o "$test_root/run/CloudSyncRegression"

"$test_root/run/CloudSyncRegression" "$test_root"
echo "Cloud sync evidence retained at $test_root"
