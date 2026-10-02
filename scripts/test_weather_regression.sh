#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
weather_test_root=$(mktemp -d /private/tmp/packmon-weather-tests.XXXXXX)
xcrun swiftc -parse-as-library TravelGenius/Services/WeatherPlanning.swift TravelGenius/Services/WeatherDraft.swift TravelGenius/Services/OpenMeteoDailyResponse.swift scripts/WeatherRegression.swift -o "$weather_test_root/run"
"$weather_test_root/run" TravelGenius/Resources/SeedData/seasonal_weather.json
echo "Weather evidence retained at $weather_test_root"
