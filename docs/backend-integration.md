# TravelGenius backend integration

This PR ports the implemented backend concepts from TravelGenius into PackSmart's current `dev` app. It preserves the Structure C frontend, 61 canonical items, artwork, item quantities/reasons/order, trip review flow, and all navigation. It does not cherry-pick the older TravelGenius UI or overwrite PackSmart's newer destination, weather, activity and laundry policies.

## Source and boundaries

Design evidence: local Claude Code session `3015f8bb-e400-4265-9a3c-4010dcd51a05` (2026-09-20/21), TravelGenius source `aaf1d41`, and `.claude/skills/travelgenius-packing-engine/SKILL.md`. Target baseline: PackSmart `dev` at `7fc80e8`. No session transcripts, credentials or private user data are committed.

| Backend concept | Integration | Operational boundary |
| --- | --- | --- |
| JSON tags / indexed needs | One JSON rule document replaces the Swift policy chain; `all`/`any`/`none` work on rules, needs and candidate items. Stable ID indexes and candidate priority are shared. | Context facts remain Swift-owned. Catalog identity/name/category/artwork stay app-owned. |
| Per-trip preference / weather snapshots | Existing snapshots and explicit review/apply APIs remain; a trip without a preference snapshot uses a fixed normal/phone default. | Another device's preferences cannot change that trip. No existing valid snapshots are rewritten. |
| Personal packing library | Existing `PackingStaples` UI facade now persists essentials in an independent SwiftData store; migrate old defaults once per installation and retain original bytes. Usage API preserves known weight when input is nil/zero. | Existing essentials UI is unchanged. `recordUsage` is available for future callers; this PR does not add automatic learning from every custom item. |
| CloudKit | Personal-library models have default values, optional weight and no unique constraints; private CloudKit configuration can be supplied by a signed build. | Default is local. No team, container, production schema or two-device sync is configured/verified. Main trip/legacy health store is explicitly local and is not enrolled in library sync. |
| Reference-data updates | Complete manifest, SHA-256, ETag, cross-file validation, atomic staging, next-launch promotion and whole-bundle fallback. | No default remote endpoint: the private repo cannot serve as a public CDN, and the TravelGenius CDN has incompatible contracts. |
| Cloud AI | Release cannot read a provider key and excludes `Secrets.plist`; Debug also requires explicit `-allowDebugCloudAI`. Built-in trivia remains available. | No proxy is deployed. Production AI needs a server proxy plus its own consent design; adding that UI is outside the instruction to preserve UI. |

Core packing remains local and deterministic. No REST service, account system, external database or PWA deployment is introduced.

## Data publisher contract

Publish these nine JSON files and `manifest.json` together at an HTTPS base URL:
`countries`, `cities`, `packing_items`, `packing_rules`, `prohibited_items`, `aviation_rules`, `etiquette`, `border_rules`, `seasonal_weather`.

Run `python3 scripts/build_reference_manifest.py` after editing data, then run the regressions below. The manifest uses `contractVersion: 1` and maps each extensionless file name to its lowercase SHA-256 hash. Serve an ETag for the manifest. Publishing must retain the exact bytes used to generate hashes. A concurrent deployment that serves mismatching files is rejected; the prior generation remains active.

Set the app Info key `PackSmartReferenceDataBaseURL` only after publishing a compatible tested endpoint. Debug can override via `-referenceDataBaseURL <URL>`; `-disableReferenceDataUpdate` disables downloads. There is no remote UI toggle or visible UI change.

Reference cache is partitioned by contract and app version/build. Complete generations are immutable. An atomic UUID pointer selects the active or staged directory. A download never changes the current launch's data. Every cached generation is hash-checked and semantically revalidated at launch; one missing/corrupt file selects the whole bundled generation. ETag 304 is accepted only when a validated active generation exists. Concurrent refresh calls return `busy`.

Catalog changes that alter any of the 61 IDs, names, categories or artwork keys require an app build. Recommendation formulas and tag conditions can update within the contract. Country/city references, supported destinations and seasonal coverage are checked across files; origin-only Taipei correctly does not require a seasonal profile. Hashes detect mismatching content; HTTPS and trusted publisher control remain required.

## Library persistence and release setup

`PackingLibrary` is a separate named SwiftData configuration. Migration reads/validates the original `packing.staples.v1` document before committing records and a completion marker together. Markers are installation-scoped, so a marker downloaded from another device cannot suppress that device's legacy import. Removal clears `isEssential`, preserving history and preventing the legacy defaults from restoring deleted essentials on reopen. IDs, quantities, explicit weights and ordering survive migration. Invalid source/duplicate synced essentials surface through the existing error flow and are not silently overwritten.

For library sync, set `PackSmartLibraryCloudContainer` to a provisioned private container ID and supply matching iCloud/CloudKit entitlements and developer-team signing. Use a PackSmart-owned container, not the TravelGenius container. Test production schema deployment, offline/reconnect conflicts and two physical devices before claiming sync support. Do not change the existing app bundle ID/group or main store without a separately reviewed migration. Trip/expense/legacy health cloud migration is deliberately not performed by this PR.

## Verification

Run on a Mac with Xcode and SwiftData available:

```sh
bash scripts/test_packing_regression.sh
bash scripts/test_packing_compatibility.sh
bash scripts/test_backend_regression.sh
bash scripts/test_weather_regression.sh
python3 scripts/test_destination_data.py
python3 scripts/build_reference_manifest.py --check
xcrun swiftc -parse-as-library scripts/ArtworkRegression.swift -o /tmp/packsmart-artwork-test
/tmp/packsmart-artwork-test
```

The compatibility oracle hashes output from the immutable pre-integration `7fc80e8` generator: 2,916 cases across countries/months/durations/styles/activity ordering/laundry/weather, including IDs, names, categories, quantities, reasons and sort indexes. It is intended to change only with an explicitly reviewed product-policy update.

Backend tests cover candidate priority/eligibility, unknown references, stable no-snapshot behavior, transactional migration/reopen/deletion, normalized usage/weight retention, full staging, unchanged current-launch data, malformed manifests, missing/mismatching files, unshipped artwork, partial HTTP failures, ETag 304 with/without active cache, and corrupted-cache fallback. Existing 540 packing cases, review/custom/packed-item safety, weather and destination regressions continue to run.

Simulator QA uses a separate copy and `com.packmon.integrationqa20261011`, keeping existing installed app data untouched. Debug/Release builds and the unchanged existing UI flows are checked. Release artifact must not include a dummy `Secrets.plist` even if supplied locally.

## App / PWA assessment

The JSON rule/manifest format is suitable for a future PWA consumer, but the existing PWA uses another runtime and its code is not in this repository. This user request targets the App backend and forbids UI changes. No PWA code, online content, quantities, artwork or production version is modified or deployed; functional cross-platform parity is not claimed.
