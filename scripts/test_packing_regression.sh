#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_root=$(mktemp -d /private/tmp/packmon-catalog-tests.XXXXXX)
mkdir -p "$test_root/baseline" "$test_root/candidate"
git archive "${PACKMON_BASELINE_REF:-packmon-ios-stage-01-accepted}" TravelGenius | tar -x -C "$test_root/baseline"
cp TravelGenius/Resources/SeedData/*.json "$test_root/candidate/"
cp "$test_root/baseline/TravelGenius/Resources/SeedData/"*.json "$test_root/baseline/"
compile() {
    local source_root="$1" output="$2"
    shift 2
    xcrun swiftc -parse-as-library -module-name PackingRegression "$@" \
        "$source_root"/Models/*.swift \
        "$source_root"/Services/UserPreferences.swift \
        "$source_root"/Services/StaticDataStore.swift \
        "$source_root"/Services/PackingListGenerator.swift \
        scripts/PackingRegression.swift -o "$output"
}
baseline_extras=()
if [[ -f "$test_root/baseline/TravelGenius/Services/PackingCatalog.swift" ]]; then
    baseline_extras+=("$test_root/baseline/TravelGenius/Services/PackingCatalog.swift")
fi
compile "$test_root/baseline/TravelGenius" "$test_root/baseline/run" -D LEGACY "${baseline_extras[@]}"
compile TravelGenius "$test_root/candidate/run" -D STAGE3 -D STAGE4 -D STAGE5 TravelGenius/Services/PackingCatalog.swift TravelGenius/Services/PackingStaples.swift TravelGenius/Services/WeatherPlanning.swift
"$test_root/baseline/run" matrix > "$test_root/baseline-results.txt"
"$test_root/candidate/run" matrix > "$test_root/candidate-results.txt"
diff -u "$test_root/baseline-results.txt" "$test_root/candidate-results.txt"
echo "7200 baseline/candidate recommendation cases: PASS"
"$test_root/baseline/run" seed "$test_root/legacy.store"
mkdir "$test_root/migration-copy"
cp "$test_root"/legacy.store* "$test_root/migration-copy/"
"$test_root/candidate/run" verify "$test_root/migration-copy/legacy.store"
"$test_root/candidate/run" verify-reopen "$test_root/migration-copy/legacy.store"
echo "Evidence and untouched legacy fixture retained at $test_root"
