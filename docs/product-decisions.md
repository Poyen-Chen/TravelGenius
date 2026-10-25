# Packmon Product Decisions

This log records accepted product choices that affect behavior, navigation, scope, defaults, user-visible data, destructive actions, or design-system policy.

## PD-001 — Structure C is the redesign source of truth

- Date: 2026-09-14
- Status: Accepted
- Decision: Use the topmost Claude Artifact section “結構 C 完整版” as the sole UI-flow and visual reference. Ignore the older alternatives below it.
- Context: The Artifact retains older explorations for reference, but implementing multiple structures would make navigation and ownership ambiguous.
- Consequences: The app uses a trip-list outer shell, four persistent root tabs, and four trip-workspace tabs.

## PD-002 — Phase-one scope and preserved entries

- Date: 2026-09-14
- Status: Accepted
- Decision: Phase one implements trip list, trip creation, trip overview, packing list, prohibited items, and standalone query. Airport mode, return mode, My, staples, and history retain visible entries but may open explanatory placeholders.
- Context: This keeps the primary preparation loop testable without prematurely implementing secondary flows.
- Consequences: Placeholder entries must remain navigable and clearly communicate their later-phase status.

## PD-003 — Swappable design systems

- Date: 2026-09-14
- Status: Accepted
- Decision: Views consume semantic `PackmonTheme` tokens through the SwiftUI environment. Testers can switch between the prior theme and Structure C from My → Preferences and Appearance.
- Context: Future Claude Design iterations need to be evaluated without rewriting feature logic.
- Consequences: Feature views should not introduce raw palette values for reusable semantic roles.

## PD-004 — No automatic sample trips

- Date: 2026-09-14
- Status: Accepted
- Decision: Normal launches and shared simulator previews start from the user's real SwiftData state and must not automatically create sample trips. `DemoSeeder` remains an explicit developer-only fixture activated solely by `-seedDemo`.
- Context: Seeded trips were mistaken for real default product behavior during review.
- Consequences: Side-panel previews launch without `-seedDemo`; empty-state testing uses a clean app container.

## PD-005 — Trip deletion is discoverable and confirmed

- Date: 2026-09-14
- Status: Accepted
- Decision: Every trip card exposes a visible ellipsis management menu containing Delete Trip. Deletion requires confirmation and removes the trip together with its SwiftData packing items. Deleting the active trip also clears the active-trip selection.
- Context: A hidden context-menu-only action is not discoverable enough for managing trips, while immediate deletion is too risky.
- Consequences: The confirmation copy explicitly states that packing data is deleted and the action cannot be undone.

## PD-006 — Brand proposals are opt-in theme experiments

- Date: 2026-09-14
- Status: Accepted
- Decision: Keep Structure C as the product baseline and add two tester-selectable color experiments based on the non-final UI and brand recommendations: “Warm Companion” uses brand orange for primary actions, while “Trust Blue CTA” uses blue for primary actions and keeps orange as the brand accent.
- Context: The team wants to compare the proposal's two plausible color-role assignments without treating the reference document as an approved redesign.
- Consequences: Both experiments reuse Structure C spacing, radii, navigation, content, and data. Theme selection is stored per device, is labeled experimental in the app, and does not by itself constitute approval of either direction.

## PD-007 — Packmon is a separate PWA, preserving Packlight

- Date: 2026-09-19
- Status: Accepted
- Decision: Create a new Site named Packmon in `web/packmon`. Leave the original Packlight Site, URL, versions, and local data unchanged. Apply PD-001's topmost “結構 C 完整版” navigation and visual baseline to Packmon.
- Context: After authorizing implementation, the user explicitly changed the scope to a separate website named Packmon.
- Consequences: New installations start empty (PD-004); the PWA has four root tabs and four trip-workspace tabs. Initial publication stays owner-private. Browser storage is scoped to the new URL and does not synchronize with Packlight or SwiftData in the iOS app.

## PD-008 — Packmon web preparation loop and local persistence

- Date: 2026-09-19
- Status: Accepted for the PWA
- Decision: Implement multi-trip creation with preview and quantity edits, packing suggestions based on the App's seed rules and preferences, six item categories, custom items, staples, undo, source-linked item queries, weight settings, JSON backup/import, and optional weather lookup. My, staples, preferences, and a basic past-trip list are functional on the web; this supersedes the optional-placeholder allowance in PD-002 for those web surfaces only. Airport, return, etiquette knowledge, and advanced history retain explicit later-phase explanations.
- Context: The user prioritized alignment with the current App while preserving the web visualization capabilities.
- Consequences: Clear empty states replace sample trips. Completed/custom items and explicit exclusions survive regeneration. Imported trips with existing IDs are skipped rather than overwritten. Data stays in localStorage; the shell, rules, and 3D assets are cached for offline use after the first successful load. The existing web defaults of a 7 kg allowance and 2.8 kg empty case remain editable estimates, not an airline entitlement. Unknown item weights are visible. Weather remains a labeled month-based estimate unless a user-requested forecast succeeds; forecasts cover the first city with coordinates within the available 16-day window. Trip deletion follows PD-005 and clears undo history.

## PD-009 — Improve 3D appearance after App alignment

- Date: 2026-09-19
- Status: Accepted for the first PWA iteration
- Decision: Retain text, card, and interactive 3D modes. Following completion of the core App alignment, replace uniform item blocks with recognizable procedural models for clothing, shoes, passports, electronics, toiletries, and other common items; add shell ribs, lining, straps, zipper rim, wheels, and material-aware lighting. Default to an opaque case, with optional transparent walls and separated layers. Preserve independent progress and free-placement modes.
- Context: The user found the old packing visualization unconvincing and asked to try improving realism, potentially with Blender or Higgsfield, after the core App work.
- Consequences: No paid media service or new credentials are required. One model group represents each checklist entry; quantities do not scale physical volume. Grid collision and bounds checks support arrangement only, not a claim that real objects fit. The interface states this limit and reports packed items that cannot be displayed in the schematic space. Higher-fidelity measured GLB assets, soft-body packing, and a Blender asset pipeline remain future work; no Higgsfield integration is claimed.

## PD-010 — Distinguish verified reminders from imported rule references

- Date: 2026-09-19
- Status: Accepted
- Decision: Use the App's country, city, packing, and rule data as the starting dataset, but do not present all imported legal reminders as freshly verified. Show source links, dates, and explicit pending-verification states. Unknown search results do not imply permission to carry an item.
- Context: Seed records include time-sensitive travel restrictions. The first web implementation verified and corrected Japan meat-product guidance, Japan medicine import guidance, and IATA 2026 power-bank guidance against their official sources.
- Consequences: Those three records carry the actual check date; remaining imported records show a generic instruction to confirm official requirements instead of repeating potentially stale legal thresholds. Outbound destinations and return-to-origin reminders remain distinct. This does not constitute comprehensive coverage of transit, airlines, customs, or individual medical circumstances.

## PD-011 — Persistent PWA installation entry and browser fallback

- Date: 2026-09-19
- Status: Accepted
- Decision: Expose “安裝 Packmon” on the trip home and My page even when no browser installation event is available. Preserve a deferred native prompt across page navigation and consume it only on a user click. If direct installation is unavailable, show platform-specific steps for desktop Chrome/Edge, macOS Safari, iOS/iPadOS Safari, and Android Chrome, plus a copyable site URL for leaving an embedded browser.
- Context: The user reported that installation to the desktop was missing. The previous button was hidden until an event arrived while My was already rendered, so navigation could hide an otherwise available installation action.
- Consequences: Dismissing or failing an install prompt never permanently removes the entry. A confirmed appinstalled event or standalone display mode suppresses repeat installation. A prompt acceptance alone is not reported as successful installation. Existing users receive versioned entry assets on refresh without clearing their trip data. Browser support still determines whether a native prompt or manual steps are available; installation is never triggered automatically.

## PD-012 — Optional per-trip bags with an all-items default

- Date: 2026-09-21
- Status: Accepted for the first PWA iteration
- Decision: Keep “全部物品” as the default on every visit to packing. Offer “分包整理” as an optional entry; first enable creates “隨身包” and “行李” without assigning existing items. Users may add or rename bags, assign an entire item entry singly or in batches, and filter text/card checklists by bag or “還沒分配”.
- Context: The user wants beginners to keep one simple overview, with separate packing available for a backpack, small bag, or multiple suitcases when needed. Implementation is authorized provided existing functionality is preserved.
- Consequences: Items, quantities, packed state, and overall progress remain one authoritative list; unassigned items remain visible in the overview and can be completed normally. Bag assignments are per-trip metadata, included in JSON backups, and never propagate through staples. Assigned items survive suggestion regeneration. Newly generated items start unassigned; custom items created while viewing a bag are assigned to that bag. Removing a bag returns its items to unassigned with packed state preserved and supports the existing session undo. Hiding the feature preserves bags and assignments for re-enabling. Existing version-1 data needs no destructive migration. Each entry's full quantity belongs to one bag in this iteration; splitting quantities, per-bag weight/allowances, and per-bag 3D are deferred. The existing whole-trip estimate and 3D placement continue unchanged; the UI labels that scope. Up to 30 uniquely named bags (1–40 characters each) are supported. This extends PD-008 and PD-009 for the PWA only; iOS and the original Packlight Site remain unchanged.

## PD-013 — Personal defaults and lightweight trip setup

- Date: 2026-09-21
- Status: Accepted direction; implementation pending
- Decision: Focus on individual packing and solo travelers. Omit questions about whom the checklist serves. Offer skippable first-use setup for personal staples, recurring needs, and devices normally taken on trips; allow later edits in My. Trip creation requires destinations and dates, with optional special activities, accommodation types, and laundry plans. Unknown or undecided answers are supported.
- Context: The user approved the discussion proposal to ask about differences specific to each trip rather than repeatedly collect personal requirements. This extends PD-008's recommendation inputs for a future change; it does not change the currently deployed behavior.
- Consequences: Initial activity groups are water/swimming, hiking/outdoors, snow/skiing, hot springs, exercise, and work/formal occasions. Ordinary sightseeing uses the base list. Related activities still require distinct recommendation logic where equipment differs (for example snow viewing versus skiing, rented versus owned gear). Accommodation choices are hotel, homestay/apartment, hostel, friends/family, and undecided, with multiple selections allowed. Accommodation types prompt checks for supplies rather than guaranteeing amenities or automatically removing items. Personal device choices cover phone, laptop, tablet/e-reader, camera, smartwatch, and headphones; accessory recommendations should avoid assuming one separate cable per device. Personal staples and needs are carried into each trip, while removing an item for one trip does not alter personal defaults. Exact item mappings and shared-accessory handling remain to be specified during implementation. No website or App implementation or deployment is part of this decision-recording step.

## PD-014 — Implement personal setup and optional trip context in the PWA

- Date: 2026-09-21
- Status: Accepted for implementation
- Decision: Implement PD-013 in Packmon web following the user's “調整” instruction. Fresh, empty installations show a skippable personal setup; existing users receive a dismissible homepage entry. My retains separate personal packing needs, custom staples, and appearance/reminder settings. New trips use destinations and dates plus a collapsed optional section for six activities, multiple accommodation types, and laundry (unknown/no/about every three days).
- Context: PD-013 recorded the approved direction without implementation; this entry supersedes that pending status for the PWA. Existing iOS work and Packlight are outside this change.
- Consequences: A version marker keeps legacy trip generation compatible. New trips target solo personal packing without age/gender/party questions. Devices default to phone when not configured; needs are explicit (glasses, contacts, skincare, period supplies, own medicine, paper reading). Existing explicit period-supply preference is carried into personal setup. Light packing uses at most four clothing sets, regular/full use trip days (existing 99-unit limit), and laundry reduces to at most three. Regular omits optional seed extras; full includes them. Accommodation items carry pending-confirmation reasons and are never treated as guaranteed amenities. Device accessories are deduplicated by item name, with one shared general charging entry and separate dedicated camera/watch/laptop accessories; connector compatibility remains a user check. Snow choices distinguish sightseeing, rental, self-provided, and unknown; only self-provided adds a ski-equipment entry to refine. New recommendations explain their source. Existing trips are never regenerated on load or personal-setting save. “調整這趟推薦” adds missing suggestions only, preserving existing items, quantities, packed state, exclusions, bag assignments, and 3D placements; users adjust existing quantities manually. Existing regenerate remains explicitly user-triggered. Backups accept optional context/preferences fields while rejecting malformed new values. Theme choices and existing install, query, backup, bag, and 3D functionality are retained.

## PD-015 — Fetch trip weather before packing recommendations

- Date: 2026-09-21
- Status: Accepted and implemented for PWA
- Decision: After destinations or dates change in trip creation, automatically query Open-Meteo with a short debounce. Generating recommendations awaits the matching request, then uses forecast tags. This supersedes PD-008's manual-only forecast timing and first-city scope. Existing manual refresh remains available.
- Context: The user requested and approved checking weather immediately after choosing dates/locations, before recommending items.
- Consequences: All destinations with coordinates are queried for the full trip date range; no per-city stay dates are inferred, and the approximation is labeled. The complete trip must fall between today and today+15 days. Missing coordinates, unavailable/incomplete data, and network timeout fall back to explicitly labeled month-based suggestions, without blocking creation. Partial success combines forecast recommendations with month-based weather suggestions. Same-condition requests reuse work; changed conditions abort prior requests and stale results cannot populate the preview. Requests time out after ten seconds. Both hot and cold tags may apply across the trip; rainy days are the union of dates across cities. Forecast source/date and fallback status appear before creating the checklist and in the saved overview. Forecasts persist with the trip; no device location is requested. Month-only fallback remains a coarse existing rule, not destination-specific climatology. Prior packing, exclusions, bag and 3D data are preserved. Official API reference checked: https://open-meteo.com/en/docs.

## PD-016 — Regional packing catalog and destination guidance

- Date: 2026-09-21
- Status: Accepted and implemented for PWA
- Decision: Extend PD-014 and supersede PD-015's global month fallback with sourced regional seasonal packing heuristics across nine countries and 21 geocoded cities. Actual forecasts take priority; partial forecasts fall back only for missing destinations. Include all months touched by a trip. Keep country-only selection with explicit uncertainty where regional variation prevents a representative climate.
- Context: The user requested an audit of existing weather recommendations and filling gaps across current countries, climates, and settings. The original rules had six forecast cities and applied temperate seasons to tropical destinations.
- Consequences: Knowledge now exposes country climate summaries, source links, scope limits, and packing thresholds. Seasonal month buckets are editorial guidance, not forecasts or measured normals. Add basic underwear, socks, sleepwear, payment tools, outdoor water/rain/light/dressing supplies, and hostel slippers for modern trips. Underwear/socks follow existing laundry/light quantity logic. Remove the Korea spicy-food medicine assumption. Forecast freezing adds thermal layers and thick socks; no UV, wind, air-quality, alpine, or comprehensive expedition logic is claimed. Legacy trip weather regeneration also benefits; other legacy preference rules remain compatible. Existing stored checklists, packed state, custom quantities, exclusions, bags, and 3D are not automatically migrated or regenerated. New suggestions require creation or an existing explicit update action. Original Packlight and iOS remain unchanged. See web/packmon/docs/recommendation-audit-2026-09-21.md for full coverage and limitations.

## PD-017 — iOS is the primary product; selectively adopt PWA experiments

- Date: 2026-09-23
- Status: Accepted direction; implementation pending
- Decision: Prioritize the iOS App. The PWA supports promotion, testing, and experiments. Keep jointly adopted features as consistent as practical; do not automatically port every PWA feature. Adapt useful TravelGenius concepts and reference data to Packmon rather than copying its implementation wholesale. Bring the weather and personal-settings improvements toward iOS, with detailed scope subject to the current checklist review.
- Context: The user clarified that feature consistency, not cross-platform user-data synchronization or transfer, is the objective. This extends PD-007 and the PWA-only work in PD-014 through PD-016 without automatically accepting those implementations as iOS requirements.
- Consequences: Cross-platform accounts, user-data sync, and transfer are outside this integration scope. PD-001 and PD-003 remain the iOS design baseline. The checklist is not blanket approval: C4 and C5 remain proposals. The user rejected C6; whether that also removes simple device/needs selections is awaiting clarification, so no existing personal-settings behavior is removed on that basis.

## PD-018 — Limit initial iOS destination coverage to five

- Date: 2026-09-23
- Status: Accepted scope; remaining destinations pending selection
- Decision: Retain Japan and South Korea and support at most five destination countries/regions initially. Select the remaining destinations with reference to places Taiwanese travelers commonly visit, rather than automatically adopting all nine PWA countries.
- Context: The user approved a narrower scope during checklist C7 review. This constrains the proposed iOS adoption of PD-016; it does not change the PWA's existing destination coverage.
- Consequences: Japan and South Korea are confirmed; the remaining entries are not yet approved. Official 2025 outbound statistics provide a selection input: Japan, mainland China, South Korea, Hong Kong, Vietnam, then Thailand. These are outbound first-destination counts, not a pure leisure-preference ranking. Source: https://www.immigration.gov.tw/5382/5385/7344/70395/414857/ . Preserve Taiwan origin/return reference data; this decision does not authorize deleting existing trips or records. Destination availability must not imply comprehensive customs-rule coverage (PD-010).

## PD-019 — Reusable item imagery for an iOS visual packing list

- Date: 2026-09-23
- Status: Accepted direction; presentation and assets pending implementation
- Decision: Include a visual packing list in the iOS scope, with representative images or illustrations for items. Do not include 3D packing in this integration. Reuse fixed assets; assets may be generated once during production or sourced from appropriately licensed web resources, rather than invoking AI on each trip or view.
- Context: The user explicitly requested the PWA's visual-list concept for the App while declining 3D packing. This is independent of PD-009's PWA-only 3D experiment.
- Consequences: Review TravelGenius's existing ItemImages assets as candidates, not automatically approved final artwork. Maintain asset provenance and applicable license/attribution information. Image style, layout, default display mode, and fallback presentation remain design details to resolve under PD-001. No AI service, per-use image generation, or PWA 3D removal is authorized by this decision.

## PD-020 — Exclude mainland China from initial iOS destinations

- Date: 2026-09-23
- Status: Accepted exclusion and replacement candidates; Thailand recommended for the checklist
- Decision: Exclude mainland China from the initial iOS destination scope. The user named the United States, Singapore, or Thailand as replacement candidates. Retain PD-018's five-destination cap and confirmed Japan/South Korea coverage.
- Context: This supersedes mainland China's inclusion in the statistical shortlist discussed under [PD-018](#pd-018--limit-initial-ios-destination-coverage-to-five). Using the user's earlier popularity criterion, recommend Thailand from the three candidates: official 2025 outbound first-destination counts are Thailand 1,026,976, United States 568,258, and Singapore 395,658. Source: https://admin.taiwan.net.tw/fapi/AttFile?id=40606&type=AttFile . These counts are not limited to leisure travel.
- Consequences: The revised recommended checklist is Japan, South Korea, Hong Kong, Vietnam, and Thailand. Thailand is the assistant's selection among user-supplied alternatives, not an explicit user ranking of those alternatives. No App or PWA destination data, existing trips, or Taiwan origin/return references are changed in this decision-recording step.

## PD-021 — Confirm five iOS destinations and a country-first city picker

- Date: 2026-09-23
- Status: Accepted; implementation pending
- Decision: Initial iOS destination coverage is Japan, South Korea, Hong Kong, the United States, and Vietnam. Destination selection first presents countries/regions, then cities belonging to the selected country/region. Do not flatten all countries' cities into one initial option list.
- Context: The user explicitly selected this roster and explained that a flat city list contains too many mixed options. This resolves the remaining selection in [PD-018](#pd-018--limit-initial-ios-destination-coverage-to-five) and supersedes the Thailand recommendation in [PD-020](#pd-020--exclude-mainland-china-from-initial-ios-destinations).
- Consequences: Use a country/region label to accommodate Hong Kong consistently. The city-selection stage is scoped to the chosen country/region; individual city coverage remains to be specified. This decision does not determine whether multiple destinations or country-only selection are supported. Retain Taiwan origin/return reference data and existing stored trips. The App's implementation and PWA changes are not part of this decision-recording step.

## PD-022 — Stage implementation behind explicit human acceptance

- Date: 2026-09-23
- Status: Accepted workflow
- Decision: Commit and push the decision/planning checkpoint after verifying Git author/committer and GitHub authentication. Implement subsequent work on new branches in bounded stages. Every stage requires the user's explicit manual acceptance before the next stage begins.
- Context: The user requested identifiable rollback points and human review because the integration spans many changes. Existing Structure C and PWA work is currently uncommitted, so a documentation commit alone cannot serve as an App baseline.
- Consequences: Follow [the staged implementation plan](ios-integration-plan.md). First preserve and verify the existing App baseline separately from new features. Record exact candidate and accepted commit IDs, verification evidence, and user acceptance. Automated test success or silence never substitutes for acceptance. Keep source rollback separate from stored-data recovery; do not erase working changes, reset shared history, or promise that reverting code reverses a database migration.

## PD-023 — Stage 1 destination candidate details

- Date: 2026-09-23
- Status: Implementation candidate; pending human acceptance
- Decision: Implement PD-021 with one explicitly selected city per new trip, preserving the actual single-city model. New trips start without a destination; city choices appear only after selecting a country/region. Switching country clears the city. Country-only new trips are not supported. Keep existing stored destinations, including legacy countries/cities, editable without silently replacing them. Update local currency when an edited destination changes.
- Context: The old creation UI offered multiple selections but saved only the first city. Single-city scope was offered as the default in an optional clarification, not explicitly approved by the user. This candidate makes the UI honest without a data migration; multi-city remains a separate decision if requested.
- Consequences: Initial cities: Japan—Tokyo, Osaka, Kyoto; South Korea—Seoul, Busan; Hong Kong—Hong Kong; USA—New York, Los Angeles; Vietnam—Hanoi, Da Nang, Ho Chi Minh City. Taiwan and existing origin/return options remain unchanged. No PWA changes, account sync, recommendation-policy changes, or complete customs-coverage claim. No SwiftData schema change. User must review this candidate before stage 2.
- Data provenance: Existing Japan/Korea/Taipei entries retained. US/Vietnam coordinates reuse the PWA destination reference data derived from Open-Meteo geocoding; they are representative city points, not precise trip locations. Hong Kong point uses HKO headquarters coordinates (https://www.hko.gov.hk/en/cis/stn.htm). Hong Kong electricity and emergency metadata checked against Hong Kong Tourism Board (https://www.discoverhongkong.com/tc/travel-guide/traveller-essentials.html and https://www.discoverhongkong.com/eng/travel-guide/traveller-essentials/emergency-useful-numbers.html). Reviewed 2026-09-23.

## PD-024 — Accept stage 1 and publish immutable acceptance checkpoints

- Date: 2026-09-23
- Status: Accepted
- Decision: Accept the stage 1 candidate described by PD-023, including its single-city scope and initial city roster. After each human acceptance, commit and push the acceptance record and publish an annotated acceptance tag before starting the next stage.
- Context: The user explicitly replied「通過」and requested commit/push before progressing, preferably with convenient rollback tags. This resolves PD-023's pending acceptance and extends PD-022's checkpoint workflow.
- Consequences: Use immutable `packmon-ios-stage-XX-accepted` tags. Verify remote branch and tag before creating the next stage branch from the accepted tag. Preserve the earlier stage 0 checkpoint with the same convention. Do not merge main automatically or equate source rollback with stored-data recovery.

## PD-025 — Stable packing identities with conservative legacy compatibility

- Date: 2026-09-23
- Status: Stage 2 implementation candidate; pending human acceptance
- Decision: Add a bundled versioned packing catalog and stable item/rule IDs while retaining current recommendation conditions, quantity policy, wording, and order. Match known old names to IDs in place; store exclusions by stable ID alongside legacy names. Preserve unknown old automatic items rather than deleting records that cannot be safely identified.
- Context: Stage 1 used display names as identity. Changing wording could create duplicate recommendations or undo exclusions. The approved stage 2 plan calls for stable identities and protection of existing packed/custom/excluded items, not wholesale import of TravelGenius's features.
- Consequences: Two additive persistence fields require upgrade verification on a copy. Preserve record UUIDs and user quantities; custom and packed records remain protected. Known obsolete unpacked automatic items retain the existing removal behavior. Adapter variants share one identity and existing labels remain snapshots. New merge previews, preference snapshots, tag/need alternatives, cloud sync, and new personalization remain outside this stage. See [contract and reproducible tests](packing-catalog-contract.md). A source tag is not a database rollback.

## PD-026 — Restore three-step creation and open the created trip's packing page

- Date: 2026-09-23
- Status: Accepted direction (user selected C); implementation candidate pending manual acceptance
- Decision: Replace the single-page creation flow with basic information → recommendation adoption/custom items → customs and aviation reference reminders. Save only at completion, then open that exact trip directly on its packing page, not the home page or overview. Recommendation adoption is explicitly distinct from packed status; all newly created items start unpacked.
- Context: The user reported being returned home without seeing the generated checklist and chose option C after comparison with the historical three-step flow. This supersedes PD-023's single-page creation presentation, not its five-country, country-first, single-city policy. It is a correction within the unaccepted stage 2, not acceptance of stage 2 or permission to start stage 3.
- Consequences: Keep current visual tokens and Taipei origin default; allow an optional trip name. Omit the nonfunctional activity chips until actual personalization is implemented. Preserve declined catalog IDs and custom drafts when navigating backward; ask before abandoning unsaved input. No persistent drafts. Save in an isolated context, show failure instead of dismissing on save error, and route only after successful save and sheet dismissal. Rules remain existing bundled references with explicit incomplete-coverage messaging; no claim of new legal verification. Existing weather refresh/merge on entering packing is unchanged, so weather-dependent items can be added after preview; weather/update policy remains stage 4/5 work. No automatic restore of the unrelated edit-trip entry in this correction.

## PD-027 — Accept stage 2 catalog and three-step creation candidate

- Date: 2026-09-23
- Status: Accepted
- Decision: Accept the stage 2 implementation at `6d15a92dbf9a5fe233cc0335e5ed9c7f2f4032b0`, including PD-025's stable packing identities and PD-026's three-step creation with direct packing navigation.
- Context: After receiving the corrected manual test instructions using regenerate-list rather than the unavailable edit-date entry, the user explicitly replied「已驗證，可往下一階段」.
- Consequences: Publish the acceptance commit and immutable `packmon-ios-stage-02-accepted` tag before preparing stage 3. This resolves the candidate status of PD-025/PD-026, but does not approve unresolved C6 details or all personalization proposals. Preserve known limitations and previously rejected scope; clarify stage 3's boundaries before implementing new personal settings.

## PD-028 — Stage 3 simplified preferences, staples, and per-trip snapshots

- Date: 2026-09-24
- Status: Simplified scope accepted; implementation pending manual acceptance
- Decision: Retain existing personal settings, add explicitly managed recurring packing supplies, and freeze each trip's packing preferences. Do not add device/special-needs selections, activities, accommodation, laundry, detailed personal profiles, new quantity policies, or cross-platform synchronization in stage 3.
- Context: The user explicitly agreed「是的，採用精簡版」after the three-item scope proposal. This resolves the C6 boundary for this stage without reinstating rejected functionality. The user also requested every delivery list implemented scope, engineering checks, and concrete human acceptance steps with expected outcomes.
- Consequences: Global preferences affect only subsequent creation flows; manual regeneration and existing weather refresh use the saved trip preferences. At upgrade, trips lacking historical preferences capture current preferences once without regeneration; this is not reconstruction of original choices. A failed snapshot save blocks entry with retry instead of proceeding with mutable settings. The existing five preference fields and 4/7-day quantity caps remain unchanged.
- Staples policy: A local versioned UserDefaults catalog supports name/category/quantity (1–99), edit, and confirmed removal. Reject blank/duplicate names and known catalog aliases that refer to the same item. Capture a copy when starting a creation flow; show it in step 2, allow removal for that trip, and save it as a protected custom item. Known matching recommendations yield to the staple's quantity/category and stable ID instead of adding duplicates. Changing/removing global staples never modifies existing trips. No automatic learning from ordinary custom items, no retroactive fill, no sync or cloud account. Library decode failure does not overwrite data or silently create a trip without staples.

## PD-029 — Themed removal confirmation and selective App/PWA alignment

- Date: 2026-09-24
- Status: Requested direction accepted; implementation pending manual review
- Decision: Use a shared themed modal confirmation for deleting saved trips, removing saved packing items, and removing staples. Display the target name, scope/consequences, a distinct cancel action and a semantic danger action. Opening, canceling or dismissing must not delete data. Replace iOS system confirmation popovers for these actions; item context menus remain entry points, not confirmations.
- Context: The user found the existing tooltip-like confirmation inconsistent with the Packmon theme and requested suitable PWA changes alongside App changes. This extends the previously iOS-only implementation scope for relevant parity work, not wholesale migration of experimental PWA features.
- Consequences: iOS uses a scrollable themed bottom sheet; PWA uses its existing accessible modal with aligned colors, wording and stacked actions. Web item removal retains undo. This change does not align storage, sync data, deploy the public site, alter recommendation policy, or imply stage 3 acceptance. Future changes should evaluate parity per feature and document intentional platform differences.

## PD-030 — Profile as a grouped settings hub

- Date: 2026-09-24
- Status: Direction accepted; candidate pending manual acceptance
- Decision: Reorganize iOS 我的 around a mascot/count summary, 打包設定 (打包偏好 and 常備用品), and App 設定 (外觀設定). Remove the unfinished history entry from this hub. Separate the existing five packing preferences from appearance; packing edits require Save and Cancel discards drafts, while appearance remains immediately applied with a Done action. Refresh summaries after returning from settings.
- Context: The user requested a PWA-inspired profile experience, accepted the proposed grouping and removal of unfinished entries, then asked to implement. This supersedes the combined 偏好與外觀 entry, not PD-028's simplified recommendation scope.
- Consequences: Retain existing experimental theme choices and mark them as experimental. Keep trip snapshots and recommendation rules unchanged. PWA profile gains matching grouping and loses its unfinished history entry; its existing backup/import and experimental personal needs remain available and are not migrated to iOS. No cross-platform data synchronization or production deployment. Other tabs' unfinished entries are outside this profile-only change.

## PD-031 — Adopt PWA profile, explicit personal needs, and staples interaction

- Date: 2026-09-24
- Status: Direction accepted (「1, 2, 4 採用pwa；3 可保留app」); implementation pending human acceptance
- Decision: Supersede PD-028's exclusion of devices/needs and PD-030's profile grouping. Use the PWA-style flat profile hierarchy: mascot/count summary, staples, personal packing needs, appearance. Personal settings use six explicit device choices and six needs, plus light/normal/full styles; remove demographic questionnaire fields from this UI and onboarding. Keep App appearance choices and immediate application. Do not restore placeholder history or add web-install UI.
- Context: The user identified that merely regrouping the existing demographic preferences did not adopt the PWA experience, reviewed the actual differences, then explicitly selected these three areas for adoption. Backup/import are separately scoped future implementation, not empty buttons or included capability. Activity/accommodation/laundry, weather rewrite, 3D, and data sync are still out of scope.
- Recommendation policy: New trips snapshot explicit device/need selections. No demographic inference of medicines, sanitary supplies or equipment; regular medicines require explicit selection, and spicy-food medicine is omitted for new trips. Shared phone/tablet/headphone charging supplies deduplicate by catalog ID. Light caps daily clothing at four; normal and full follow trip days up to 99, with full-only extras only in full. Existing seasonal/destination rules remain. Retain the PWA's baseline solo luggage/document security items with neutral wording rather than claiming the user selected solo. Existing historical snapshots remain decodable; permission to remove simulator trips does not authorize silent deletion on other installations.
- Staples: Prominent named add button, themed empty state and rows, visible remove action with confirmation, editable name/category/quantity plus optional unit weight in kg (finite 0–100, blank means unknown). Copy weight into new trips, never backfill old ones. A visible star on trip items opens an editable staple draft; saved staples show a filled star. Removing the star removes the global staple only after confirmation, not the trip item. No inferred weights or luggage weight-limit claims.
- Simulator data: The user permits removing old trips for fresh validation. Limit cleanup to this iOS simulator, preserving preferences/staples and all PWA data; record exact deleted trips and backup separately. This is not production cleanup code and not stage acceptance.

## PD-032 — Accept stage 3 and defer App backup/import

- Date: 2026-09-24
- Status: Accepted
- Decision: Accept the current iOS stage 3 implementation at `4fc8565dae27942bdb1b1043e267f50984ca6f51`, including personal needs, staples, snapshots, profile parity and themed removal confirmation. Leave App import/export out of this stage.
- Context: The user replied「算了先這樣吧，這個階段已完成，下一階段的計劃是什麼」after discussing backup/import. This resolves the iOS implementation acceptance status of PD-028 through PD-031 with PD-031 taking precedence over earlier scope.
- Consequences: Commit/push the acceptance record and publish immutable `packmon-ios-stage-03-accepted` before stage 4 implementation. Present the weather-stage plan first; this acceptance does not approve all future weather-provider or update-policy details. The previously untracked local PWA tree is preserved but is not included in this iOS checkpoint or deployed. No simulator trips are deleted by this acceptance; no additional QA is implied.

## PD-033 — Stage 4 weather direction and durable specification records

- Date: 2026-09-24
- Status: Direction accepted; detailed parameters pending; implementation not started
- Decision: Plan iOS WeatherKit as the primary forecast provider, with sourced city/month seasonal fallback. Distinguish complete, partial and unavailable forecasts; resolve weather before checklist adoption, preserve the confirmed creation snapshot, and stop automatic checklist mutations on opening saved trips. Add request identity, destination-date semantics, explicit cache freshness, honest probability wording and required attribution. Existing-list update UX remains stage 5.
- Context: After comparing the partner project's WeatherKit implementation with Packmon and explaining deficiencies and remedies, the user replied「好的」and requested technical/decision documentation covering past stages and upcoming implementation. This selects the stage 4 direction left unresolved by PD-032, not proof that WeatherKit is enabled or tested.
- Consequences: Maintain [accepted specifications](implementation-specifications.md) and [weather design](weather-integration-spec.md) alongside this append-only decision log and the stage acceptance plan. Record behavioral changes in the same implementation change; preserve superseded decisions and link replacements. Cache durations, request timeout, climate sources, thresholds and legacy manual-regeneration details remain explicitly unresolved. No new notification, trip-date editor, backup/import, PWA provider migration or production deployment is authorized by this documentation update. Continue human stage gates and immutable acceptance tags.

## PD-034 — Stage 4 candidate weather policy and legacy compatibility

- Date: 2026-09-24
- Status: Implementation authorized; candidate pending human acceptance and WeatherKit live verification
- Decision: Resolve PD-033's implementation details with 300 ms input debounce, 10-second total wait, an explicit seasonal-skip button, and a six-hour successful-forecast cache that expires at a destination-calendar-day boundary. Do not reuse expired forecasts for new recommendations. Retain existing iOS thresholds (high ≥30°C, low ≤10°C, daily precipitation chance ≥50%) rather than silently changing to PWA's different thresholds. Use bundled version-1 city/month heuristics for the 11 supported destination cities, with official reference URLs; they are packing heuristics, not measured normals or daily predictions.
- Context: The user authorized stage 4 implementation after requesting specification records. The current project has no Developer Team; a simulator request actually returned `WeatherDaemon.WDSJWTAuthenticatorServiceProxy.Errors` code 0. Therefore service fallback is functional evidence, not proof of successful WeatherKit authentication.
- Consequences: Persist an additive versioned `packingWeatherRaw` snapshot only for new confirmed trips. Preview back-navigation with unchanged city/dates keeps the same weather; changed inputs recompute recommendations but preserve excluded IDs and custom/staple drafts. Never let late responses modify the adopted preview. Stored trips do not automatically refresh or merge on opening; manual regeneration uses their saved weather or the pre-existing month policy for legacy trips without a snapshot. Corrupt nonempty snapshots block regeneration without clearing items. Snapshot UI explicitly describes creation-time evidence, not live forecasts.
- Scope correction: Remove hard-coded winter-weather and most-missing-winter-clothes statements from the home/overview; show real saved evidence or no-record wording. Keep selective PWA parity policy, but do not migrate/deploy the PWA or change its thresholds in this stage. No test-weather override is shipped to masquerade as real weather. Stage 4 acceptance tag must wait for human approval; successful provider validation remains an explicit release prerequisite.

## PD-035 — Use Open-Meteo now; retain inactive WeatherKit adapter

- Date: 2026-09-24
- Status: Accepted direction; stage 4 candidate pending human acceptance
- Decision: Supersede PD-033/034's immediate WeatherKit activation. Use Open-Meteo for the current non-commercial test App because the user does not have paid Apple Developer membership. Retain the WeatherKit adapter for a future intentional switch; do not silently fail over between providers or mix cached data.
- Context: During stage 4 testing the user explicitly asked「先保留weatherkit串接的方式，但先回去使用open meteo」.
- Consequences: Provider is part of the request, persisted snapshot and cache identity. Open-Meteo uses a maximum 16-day horizon, WeatherKit 10; actual valid returned dates remain authoritative. Open-Meteo JSON null/missing values are not zeros and array alignment is validated. Attribution follows the active source. Keep all preview/freeze/fallback/cancellation protections. Default entitlements do not require WeatherKit while inactive; future activation requires developer service provisioning plus the entitlement and real tests. Earlier WeatherKit-only test snapshots decode as WeatherKit and are not rewritten. Open-Meteo's free endpoint is not a commercial-use authorization; before commercial release switch/provision WeatherKit or arrange an appropriate commercial service plan. This change does not purchase anything or deploy PWA.

## PD-036 — Packing-first compact weather presentation

- Date: 2026-09-24
- Status: Direction accepted (user selected option 2); implementation pending human review
- Decision: Replace the verbose shared weather card with a packing reminder, forecast temperature range and rain-probability day count, explicit coverage status and a weather-details action. Use the existing Packmon theme. Keep provider attribution visible; move exact dates, retrieval time, probability definition, fallback reasons and legal/source detail into a scrollable themed sheet.
- Context: The user found the stage 4 card too text-heavy, reviewed three concepts, and selected the packing-reminder-first direction. This supersedes PD-034's verbose presentation, not its snapshot or recommendation policy.
- Consequences: Reminders derive from existing cold/hot/rain tags, including seasonal tags where relevant; they never claim an item was added. Show all applicable reminder categories. No-data and seasonal-only states show no fabricated temperature or rain count. Partial coverage remains visible and metrics describe forecast days only. Saved cards identify creation-time evidence. Apply through the shared iOS component to creation, preview, overview and packing; do not change providers, thresholds, storage or checklist contents. PWA remains unchanged in this iOS stage; its separate weather implementation is not migrated. No stage acceptance tag until human approval.

## PD-037 — Daily-list weather details

- Date: 2026-09-24
- Status: Direction accepted (second details concept); candidate pending human review
- Decision: Keep PD-036's compact main card. Present details as a large scrollable sheet with city/date range, saved-reference and coverage status, compact trip summary, and a date/temperature/rain-probability list. Highlight days at the existing ≥50% threshold with a soft accent background and filled droplet. Place the packing reminder below the list and technical/source explanation in a collapsed disclosure.
- Context: The user requested alternatives for the details itself, then selected the second displayed concept, the daily list. This supersedes PD-036's dense text details and medium-height default, not its main card or weather policy.
- Consequences: Use stored daily values, never mock numbers or inferred weather conditions. Weekdays use the destination calendar. Accessibility text sizes use stacked rows. Missing dates remain explicitly identified; seasonal-only states never fabricate daily data. Retrieval time, snapshot status and source remain visible. No refresh, persistence changes, checklist mutations or PWA migration. Human acceptance is still required before stage 4 is tagged.

## PD-038 — Selective PWA weather presentation parity and ongoing parity check

- Date: 2026-09-25
- Status: Requested; candidate pending human review
- Decision: Extend PD-036/037's packing-first weather card and daily forecast list to PWA. Persist newly fetched per-city daily values alongside existing summaries. Legacy summaries explicitly lack daily data. Use the existing modal for saved trips and inline disclosure within creation/preview to preserve form state. Always assess App/PWA suitability for future changes and report synchronization or intentional differences in deliveries; record this in AGENTS.md.
- Context: User requested synchronization and asked that future changes consider PWA too. Supersedes the PWA exclusion in PD-036/037 for this presentation scope only.
- Consequences: Preserve PWA Open-Meteo, multi-city behavior, 40% rain threshold, 28°C hot threshold, and explicit weather-refresh recommendation merge. Label that action「更新預報與推薦」and warn it adds applicable items. Viewing details never refreshes or modifies items. Multi-city dates are not represented as actual stay dates. No invented old daily values, migration of iOS recommendation rules, cross-platform data sync or public deployment. Version offline assets for the new UI.

## PD-039 — App-source weather information and design parity

- Date: 2026-09-25
- Status: Implementation requested; local candidate pending visual acceptance
- Decision: Use the actual iOS weather card/details as the source for PWA information order, date range/weekdays, coverage, icons, typography, colors, rounded daily rows and metadata. Adapt only the container to desktop or mobile. Align new PWA forecast lookups to iOS ≥50% rain and ≥30°C hot thresholds, superseding PD-038's retention of different new-query thresholds.
- Context: The user rejected functional-only parity and explicitly requires both information and basic design consistency. Local comparison precedes publishing this correction.
- Consequences: Persist reference kind, retrieval timestamp and thresholds for new queries. Existing snapshots and packing items are not rewritten; old 40% summaries remain explicitly labeled, not silently reinterpreted. Preserve accurate PWA-specific multi-city and explicit refresh/merge semantics. No data synchronization or fabricated forecasts. Creation forms retain inline details to avoid losing edits. Update the PWA knowledge explanation accordingly.
## PD-040 — Grouped PWA destinations aligned with App

- Date: 2026-09-25
- Status: Requested; local implementation pending human acceptance
- Decision: PWA new-trip destinations use country/region then city, with Japan, Korea, Hong Kong, United States and Vietnam and the same 11 city coordinates as iOS. Use two-column themed selection chips, not a flattened city/country search or country-only placeholders.
- Context: User explicitly requested updating PWA destination selection after requesting App/PWA information and basic design parity.
- Consequences: Retain existing PWA multi-city selection; switching the visible country preserves selected cities and form dates/options. Preserve legacy destinations and departure-country options. Add Hong Kong metadata from iOS so persisted trips validate; missing seasonal knowledge is explicitly labeled rather than fabricated. No cross-platform data migration or automatic public deployment. Supersedes broader PWA destination selection for new trips only.
## PD-041 — Inline, selection-only updates to existing packing lists

- Date: 2026-09-25
- Status: Direction accepted (user selected displayed preview 3); candidate pending human acceptance
- Decision: Replace direct regeneration with an inline recommendation review above the original packing list. Fetch weather explicitly, display only missing/non-excluded candidates with checkboxes, and append only confirmed selections. Preserve all existing records and original creation-weather evidence. New weather is transient evidence for this review, not a silent replacement of the saved reference.
- Context: Stage 5 C4 required confirmation. The user selected the third displayed mock after authorizing implementation. Supersedes the existing saved-list direct sync behavior and PD-038's refresh/merge semantics; does not change creation or weather-provider policy.
- Consequences: Cancel and navigation discard proposals; late results cannot mutate adopted lists. Confirm rechecks duplicates/exclusions. Unchecked proposals are skipped only this time. Empty proposals and failed saves are explicit. Sync the inline flow to PWA while retaining its multi-city/name-based engine and optional arrangements. Do not add App activities, date-edit UI, visual assets, 3D, or cross-platform synchronization. Specification: recommendation-update-spec.md.

## PD-042 — Stage 5 human acceptance and Stage 6 review gate

- Date: 2026-09-25
- Status: Accepted
- Decision: Accept the delivered PD-041 implementation (App `2eae265`, PWA `1876394` / Site 9). Save and push the acceptance record and immutable `packmon-ios-stage-05-accepted` tag before starting Stage 6 from it.
- Context: User explicitly replied「通過，下一個階段」. This updates PD-041's pending acceptance status without rewriting its historical record.
- Consequences: Stage 6 retains the existing gate: review a small set of reusable item visuals and layout before full asset production and integration. No automatic approval of image style, layout, default display mode or Stage 6 completion; no 3D or per-use image generation. Existing data remains unchanged.

## PD-043 — Two-column item-image cards

- Date: 2026-09-25
- Status: Design accepted (second displayed Stage 6 preview); implementation pending human acceptance
- Decision: Implement the selected two-column image-forward cards in App and PWA with item names, quantities, separate packing checkboxes and item actions. Preserve existing text/default preferences; selecting images is remembered locally. Large accessibility text may use one column; wide web layouts may use three.
- Context: User selected「2」after reviewing thumbnail rows versus two-column cards. Selected image: `exec-5ab1c363-1d15-451c-ab4c-b1586c158a20.png`. This resolves PD-019's layout/style review gate; it does not accept the completed stage.
- Consequences: Bundle reusable representative images, not runtime generation. First candidate covers five reviewed item concepts (charging cable versus charger kit use distinct assets); remaining/custom/unknown items have labeled category fallback and retain full controls. No fuzzy substring matching, schema migration or data duplication. Image mode uses compact progress; existing weather and web bag/weight controls remain accessible. App card quantity editing uses a cancelable 1–99 draft shared with the text list's context menu. Suggestion review stays text-only; PWA's existing 3D experiment remains PWA-only. See visual-list-spec.md for provenance, differences and acceptance limits.

## PD-044 — Stage 6 functional acceptance; defer final artwork

- Date: 2026-09-25
- Status: Accepted
- Decision: Accept Stage 6 as a functional validation of visual packing cards (App `0470a88`, PWA `d321e6a` / Site 10). Defer consistent/final artwork generation until the item catalog is confirmed. This supersedes PD-043's pending human acceptance and any expectation that full artwork coverage is required before Stage 7.
- Context: User explicitly requested「這邊先當作驗證，繼續下一階段」after discussing mixed realistic/line imagery. This is not approval of mixed artwork as the final visual standard.
- Consequences: Keep current assets and labeled fallbacks on both platforms; generate no further assets now. Preserve test limitations and provenance caveats. Commit/push acceptance and immutable Stage 6 tag before branching Stage 7, which is integration checks and scoped defect fixes only, not production release approval or a new feature phase.

## PD-045 — Stage 7 acceptance with deferred release checks

- Date: 2026-09-25
- Status: Accepted
- Decision: Close Stage 7 following the user's explicit「可以先保持這樣，完成」. Preserve the current implementation; do not change navigation in this acceptance commit. Retain direct-to-packing on App creation. The observed PWA creation-to-overview discrepancy remains documented and deferred, not falsely reported as fixed or as cross-platform parity approval.
- Context: The user accepted completion after the hands-on test report (`5919168`) and asked what comes next. Functional source remains App `0470a88`, PWA `d321e6a` / Site 10.
- Consequences: Publish an immutable Stage 7 acceptance tag after committing/pushing this record. Original phases 0–7 are complete; this does not authorize merging main, TestFlight/App Store release or commercial launch. Carry forward untested real-device, full-network-outage, accessibility and nonempty suggestion UI cases. Final artwork remains deferred under PD-044. Any further phase is a new proposal requiring scope agreement.

## PD-046 — Explicit legacy migration choice and two-way packing review

- Date: 2026-09-25
- Status: Direction accepted; specification and implementation not started
- Decision: When an existing legacy trip requests updated recommendations, ask whether to adopt the new preference logic instead of silently retaining or replacing its historical settings. The recommendation review must cover both additions and reductions: it may propose lower quantities and complete item removal, but it must never apply either without the user's explicit selection. Retain all three packing styles—light, normal and full—while separately auditing which catalog items legitimately vary by style. In the new-trip flow, expose per-trip packing overrides during creation rather than requiring users to create the trip first and edit it afterward.
- Context: After reviewing the original, current and proposed recommendation behavior, the user selected option B for legacy-trip migration, option B for reduction scope, retained all three packing styles, and selected the first placement option for per-trip overrides.
- Consequences: This supersedes PD-041's additions-only scope for the next specification, without changing the already accepted Stage 5 implementation retroactively. Legacy migration remains a prompted user choice; no automatic conversion, deletion, quantity reduction or global-setting synchronization is authorized. Reduction proposals must preserve packed, custom, staple, excluded and manually edited state until individually confirmed, and must show reasons plus before/after quantities where applicable. Style-dependent `fullOnly` classifications require a rule audit before implementation. The creation-flow placement must be designed within the accepted three-step flow and assessed for App/PWA parity. This decision records direction only and does not authorize source changes, data migration, branch creation or deployment.

## PD-047 — Port the legacy recommendation engine into the current App contract

- Date: 2026-09-25
- Status: Implementation authorized; local candidate pending human review
- Decision: Preserve the legacy engine's catalog identity, ordered rule evaluation, deduplication, quantity calculation, reasons and historical-output compatibility, but make the current App's explicit data contract authoritative for new trips. New trips use packing style, selected devices, selected needs, activity, accommodation, laundry, weather and destination; hidden age, gender, party and experience fields remain decodable only for historical snapshots and do not participate in modern recommendations. Store the modern trip context as a versioned per-trip snapshot. Keep departure country fixed to Taiwan without asserting Taipei or another airport. Place per-trip overrides in step 1 of the accepted three-step creation flow.
- Context: The user clarified that the goal is not to restore the old App, but to move the old recommendation architecture into the optimized current flow so its recommendation quality can be tested. The user also required the original and current behavior to remain distinguishable and reviewable rather than treating implementation choices as automatically accepted.
- Consequences: Existing legacy trips ask whether to retain their frozen historical inputs or preview and adopt current global settings. Adoption is committed only with the user's review confirmation. Existing-list review can propose additions, lower quantities and removals; additions start selected, while reductions and removals start unselected. Custom records are never reduction/removal candidates; packed automatic records remain selectable only with an explicit warning. Corrupt nonempty snapshots block mutation. New custom items issue a duplicate warning but allow an explicit override. Three packing styles remain, but the `fullOnly` content classification is not deemed correct merely because the mechanism is retained and still requires content review. Activity/accommodation/laundry rules are provisional recommendation content for testing, not accepted product truth. PWA remains unchanged in this App validation candidate; cross-platform parity must be decided after the engine and content are reviewed. Country-specific content for Japan, Korea, Hong Kong, the United States and Vietnam remains a separate evidence-based audit and must not be inferred as complete from this implementation.
- Verification boundary: A 7,200-case frozen legacy matrix must remain byte-for-byte equivalent. New tests cover explicit inputs, contextual rules, migration choice data, two-way review, protected custom/packed state, corrupt snapshots and reopened persistence. Passing engineering checks means the architecture is testable; it does not mean the recommendations are reasonable or human-accepted.

## PD-048 — Accept the iOS recommendation architecture without a laundry clothing cap

- Date: 2026-09-25
- Status: Accepted for the current iOS implementation
- Decision: Accept PD-047's activity mappings, accommodation confirmation behavior, three-style `fullOnly` policy, warning-based handling of packed automatic items, and repeated migration choice for legacy trips. Do not reduce clothing quantities merely because the user says laundry is available; laundry adds relevant supplies only. Keep departure at Taiwan and defer an airport selector until an evidenced recommendation difference exists. Treat the five-country content audit as separate work.
- Context: After reviewing the implemented differences, the user answered that laundry does not need a quantity limit, accepted items 2–6, asked to wait for evidence before adding airport selection, and confirmed that five-country work will be completed elsewhere. The user then authorized submitting the change.
- Consequences: For modern iOS trips, per-day clothing continues to follow trip length and packing style; the laundry context never introduces a three-day cap. This supersedes PD-047's provisional laundry candidate for iOS and intentionally does not rewrite PD-014's historical PWA behavior. Packed automatic items may be reduced or removed only after an unselected-by-default proposal and visible warning. Choosing to retain legacy recommendation settings is not stored as a permanent opt-out, so a later update asks again. The accepted direction makes the architecture ready for checklist-quality testing; future evidence may still refine individual catalog mappings. No PWA synchronization, airport UI, five-country research conclusion, deployment or release approval is included in this submission.

## PD-049 — Minimum-sufficient catalog governance and V1 audit

- Date: 2026-09-25
- Status: Accepted governance; item-level dialogue in progress
- Decision: Do not target an exhaustive travel-item database or a fixed item count. Maintain one stable-ID catalog, but assign every item a product role: core, explicit-condition, personal/selectable, reminder/task, or compatibility-only. Define supported travel needs and contexts first, choose the smallest set of items that covers them, then use tags to describe triggers, risks and relationships; tags do not independently justify adding items. Automatic recommendations favor recall for high-consequence core omissions and precision for optional/contextual items. Aggregate usage may nominate future candidates but cannot promote them without editorial review.
- Context: The current 74-item catalog mixes modern recommendations, explicit personal options, provisional activity/accommodation items and historical compatibility records. Counting all 74 as one recommendation set hides both noise and basic-coverage gaps. The user wants a compact checklist that satisfies essential travel needs, with long-tail items added by the traveler or considered later from overall usage patterns.
- Consequences: Freeze catalog expansion and final artwork while the item groups are reviewed, except for separately identified minimum-coverage candidates. Preserve published IDs and legacy aliases even when an item stops participating in new recommendations. Items that are primarily actions or checks move to reminder/task treatment instead of being disguised as packable objects. Each active item must have a need, trigger, omission impact, duplicate/substitute review and explainable reason. Per the user's requested review process, item-level decisions are confirmed group by group in conversation and are written into one final catalog specification only after the whole catalog is confirmed. No source data, saved trips, iOS recommendations or PWA recommendations change during that dialogue. The governance principle is suitable for both platforms; catalog/rule synchronization is deferred until the item decisions resolve existing iOS/PWA differences.

## PD-050 — Confirm the 61-item minimum-sufficient V1 catalog

- Date: 2026-09-26
- Status: Catalog content accepted; implementation pending
- Decision: Confirm the 61 active catalog identities, triggers, exclusions, duplicate mappings and laundry quantity policy in [the V1 catalog specification](packing-catalog-v1-spec.md). New trips start with nine basic items and add only explicit personal/device selections or evidenced destination, weather, activity, hostel and laundry conditions. Preserve compatibility-only IDs without using them for new recommendations. Do not add an independent pre-trip reminder, counter, push or reminder-page feature in this V1 catalog scope.
- Context: The user reviewed the catalog group by group, rejected country products and software as packing items, removed inferred medicine and companion rules, separated opaque bundles, clarified weather/activity additions, simplified snow and accommodation inputs, and required evidence rather than intuition. The final dialogue accepted 61 unique standard items instead of treating all 74 existing definitions as one recommendation set. The user also explicitly reversed the earlier laundry position and accepted reducing ordinary clothing quantities when laundry is planned.
- Consequences: This completes the dialogue required by PD-049 and supersedes the item mappings in PD-047's candidate specification. For modern trips, planned laundry now caps tops/underwear/socks at 3/4/5 days for light/normal/full and bottoms at 2/2/3, never beyond trip length; this supersedes PD-048's no-laundry-cap decision. Special-activity clothing and weather outerwear are unaffected. Remove hot-spring and non-hostel accommodation inputs when implementing this catalog because they no longer change V1 recommendations. Split hiking from generic outdoors, work/business from formal occasions, and snow sightseeing from skiing/snowboarding. Medications, vision supplies, first aid and unsupported long-tail items remain user-created staples/custom items. `travel-document-backup` is explicit opt-in and consolidates the prior passport/insurance/emergency-card entries. No catalog JSON, recommendation code, saved trip, PWA behavior, artwork, migration or deployment is changed by this documentation-only acceptance; implementation requires a separately reviewed change on both platforms or an explicit recorded parity exception.

## PD-051 — Complete human validation of the V1 catalog specification

- Date: 2026-09-26
- Status: Accepted
- Decision: Mark the 61-item V1 catalog specification defined by PD-050 as human-validated and use it as the frozen content baseline for a future implementation candidate.
- Context: After the consolidated specification and its 61 unique active identities were recorded and checked, the user explicitly stated「驗證完成」.
- Consequences: Future catalog or recommendation implementation must trace to [the validated V1 catalog specification](packing-catalog-v1-spec.md), preserve its compatibility boundaries and receive separate implementation verification. This acceptance does not modify iOS or PWA code, migrate saved trips, approve artwork, deploy either platform, create a release tag, or authorize starting implementation without a subsequent request. Any material content change requires a new decision rather than silently editing this accepted baseline.

## PD-052 — Implement the validated V1 catalog on iOS and PWA

- Date: 2026-09-26
- Status: Implementation candidate; pending human acceptance
- Decision: Implement PD-050／051's 61-item active catalog on both iOS and PWA. Preserve all published identities and legacy decoding, but allow modern trips to generate only active identities. Use the accepted nine-item base, explicit device／need choices, weather and activity mappings, hostel items, laundry quantities, and catalog-ID deduplication. Add an explicit self-driving activity because `driving-documents` otherwise has no honest trigger. Keep `local-cash` inactive in recommendation generation until a reliable destination or arrival input exists.
- Context: After learning that the prior conversation had only updated the specification, the user asked to continue, authorizing actual implementation. This follows the already human-validated content baseline; it does not reopen item selection or add a separate reminder feature.
- Consequences: iOS catalog version 2 contains 95 definitions and exactly 61 active IDs; modern preference/context snapshots use the V1 policy while historical snapshots preserve legacy output. PWA recommendation version 3 and offline cache 23 use the same active catalog and remove new-entry UI for hot springs, non-hostel accommodations, legacy medical／vision needs and ski-rental choices. Existing trips are not silently rewritten; updates remain review-driven. Automated evidence includes the 7,200-case iOS historical matrix, V1 regression checks, a complete unsigned device build, JavaScript syntax checks and 59 passing PWA tests. This candidate does not migrate production data, approve final artwork, deploy either platform, commit or push the branch, tag a release, or constitute human acceptance.

## PD-053 — Four-gate round-trip border review

- Date: 2026-09-28
- Status: Direction accepted; detailed content and implementation pending
- Decision: Replace the country-only customs presentation with a round-trip review organized by the four border crossings a Taiwan-origin traveler encounters: Taiwan departure, destination arrival, destination departure for the return trip, and Taiwan arrival. Each rule must declare the country or region, travel direction and applicable checkpoint instead of being reused solely because its country code matches. For a Taiwan–Japan trip, the four headings are Taiwan departure, Japan arrival, Japan departure and Taiwan arrival.
- Context: The current App shows destination-country rules as the outbound arrival section and origin-country rules as the return arrival section; another restrictions view labels those same country-wide records as Taiwan departure and Japan arrival. This omits two checkpoints and can assign import-only rules to an export checkpoint. The user explicitly requested all four reviews.
- Consequences: Customs/import-export requirements, animal and plant quarantine, and aviation security remain distinguishable even when presented in one journey. Departure sections focus on export declarations or controls that genuinely apply at departure; arrival sections focus on import declarations, allowances and quarantine. A rule may apply to one or multiple checkpoints, but direction-neutral wording must not be inferred automatically. Every legal or regulatory item retains an official source and verification date; missing coverage is shown as unverified rather than as permission. The item checker returns checkpoint-specific results and cannot claim unrestricted status merely because no local rule matched. Hard-coded summary counts must be removed. The four-gate information architecture is suitable for both iOS and PWA, but implementation and researched rule coverage require a separately reviewed task; no source data, UI, saved trips or deployment changes in this decision-only step.

## PD-054 — Compact checkpoint selector with action-first disclosure

- Date: 2026-09-28
- Status: iOS implementation candidate; pending human acceptance
- Decision: Implement the second displayed design direction in the iOS trip workspace. Rename the former prohibited-items tab to「通關」, default to destination arrival, and use one compact four-checkpoint selector for Taiwan departure, destination arrival, destination departure and Taiwan arrival. Each checkpoint shows three explicitly prioritized actions with optional review checkmarks; the complete rules, official sources and verification dates remain one level deeper. Hide the floating Jelly dock while this workspace page is active so it cannot cover a rule or confirmation control. A stored checkmark means only that the traveler reviewed the reminder, never that an authority approved the item, and a rule verification-date change invalidates the old checkmark. Empty search or coverage states say「尚未收錄」and never imply permission.
- Context: The user selected option 2 after comparing three visual directions and asked for enough information to avoid penalties without creating a dense or inconvenient flow. Simulator review exposed that generic aviation items could otherwise displace higher-consequence customs actions from the first three rows, so the selected layout uses editorial priority stored with sourced rule data rather than alphabetical ordering or hard-coded counts.
- Consequences: The iOS candidate includes sourced Taiwan/Japan directional rules and replaces unsafe blanket medication wording with a verify-by-ingredient action. Unsupported destinations or checkpoints disclose incomplete coverage. Confirmations are local per trip and versioned by source verification date; they do not sync across devices. The same information architecture is suitable for PWA, but PWA synchronization is intentionally deferred until this iOS candidate receives human review because the current request targets the App and the existing untracked web work must not be overwritten. No deployment, schema migration, saved-trip rewrite or legal guarantee is included.

## PD-055 — Date-aware, departure-aware border rules and PWA parity

- Date: 2026-09-28
- Status: Implementation candidate; pending human acceptance
- Decision: Refresh the supported Taiwan-origin routes—Japan, Korea, Hong Kong, the United States and Vietnam—from official sources, and synchronize the four-checkpoint border-review experience to iOS and PWA. Customs and quarantine rules apply at their explicit border checkpoint. Aviation rules apply from the country or region where the traveler actually departs, not merely because that jurisdiction appears anywhere on the route. City remains trip context and does not determine national customs law. Rules may define inclusive effective dates so the journey date selects the applicable version; Japan's tax-free flow switches from the current export-confirmation model to the refund method on 2026-11-01.
- Context: The user asked to re-check the currently supported origin, destinations and cities against current rules, then explicitly asked to update the product. The audit found material issues: United States agricultural goods and Korean meat products were presented as blanket bans instead of declaration／inspection cases; Hong Kong had no active supported records; Vietnam lacked the current electronic and heated-tobacco import ban; Taiwan return rules omitted electronic cigarettes and cannabis; and one route-wide aviation matcher could show a departure rule at the wrong end of the trip. Several jurisdictions also introduced stricter power-bank rules during 2026.
- Consequences: Both platforms now expose Taiwan departure, destination arrival, destination departure and Taiwan arrival in journey order, with official source links and a 2026-09-28 verification date for supported content. High-risk corrections favor explicit declaration or verification wording over unsupported permission claims; no-match states continue to say that absence is not permission. Taiwan, Japan, Korea, Hong Kong and Vietnam power-bank caps are represented separately from the United States FAA rule, whose two-battery cap applies only to 101–160Wh spare batteries rather than all power banks. The standalone item checker searches all four checkpoints and labels the applicable leg. Vietnam's broader food, plant, medicine and high-value coverage remains explicitly partial instead of being presented as complete. Airport- and airline-specific differences remain a pre-departure confirmation because the trip schema does not yet store the operating airport or carrier. This change does not deploy either platform or provide a legal guarantee.

## PD-056 — “Update PWA” includes production publication

- Date: 2026-09-28
- Status: Accepted release convention
- Decision: In this project, a user request to update the PWA means implement, verify, and publish the change to the existing Packmon production Site. Treat a local-only implementation, preview, or saved undeployed Site version as incomplete unless the user explicitly requests one of those narrower outcomes.
- Context: After the four-checkpoint work had been completed and verified locally, the user clarified that every request to update the PWA refers to the online version.
- Consequences: The PD-055 PWA candidate is published as Packmon Site version 14 to the current production URL without changing its public audience or clearing browser storage. Live verification confirmed all four checkpoints, the 2026-11-01 Japan refund rule, Japan-departure aviation rules, refreshed Taiwan-arrival rules, and no browser console errors after the new service worker activated. Future PWA deliveries must report the production version and live verification result. This convention does not automatically authorize an iOS release, App Store submission, a new Site, an audience change, destructive migration, or publication of work the user explicitly labels draft/local-only. It supersedes PD-055's no-deployment boundary for this release while preserving PD-055's implementation and safety decisions.

## PD-057 — Consolidate the pre-release iOS recommendation engine into dev

- Date: 2026-10-02
- Status: Accepted direction; local integration candidate pending complete branch verification
- Decision: Packmon 尚未上架，iOS 不保留舊版／新版雙軌、舊行程推薦選擇或歷史輸出相容引擎。V1 的 61 項目錄是唯一正式目錄；用品身分、名稱與分類保留在 packing_items.json，推薦條件、數量、去重、天氣、活動、住宿與洗衣政策只由 Swift 實作。packing_rules.json 不再是執行時輸入。
- Context: 使用者明確指出目前沒有正式使用者或已發布資料，不需要為未上架版本維持雙軌，並要求把分散在不同工作分支的功能整理到一個可完整測試的 `dev`。本候選整合來源為 `c0798b6`；來源分支曾使用 PD-053，但 canonical `dev` 已有 PD-053～056，因此以本條重新編號並保留既有決策，不以 merge strategy 覆寫決策歷史。
- Consequences: 移除 JSON PackingRule 模型與載入、人口推測欄位、可空設備／需求所代表的歷史狀態、舊推薦模式對話框、推薦偏好升級阻擋畫面及直接 sync 合併路徑。TripPackingContext 只保留目前會影響 V1 的活動、青旅與洗衣輸入；不保留溫泉、非青旅住宿、雪具租借／自備等解碼分支。Catalog 收斂為 61 筆正式定義，不再使用 95 筆定義加 active set，也不保留 legacy aliases。既有清單更新仍採唯讀新增／減量／移除提案並由使用者勾選後套用，因為這是資料安全機制而非版本雙軌。城市季節資料、國家插座及其他事實資料仍保留 JSON。
- Supersedes: PD-046 的舊行程選擇、PD-047 的歷史輸出相容、PD-048 的重複遷移選擇，以及 PD-049～PD-052 中要求保留 compatibility-only IDs、legacy aliases、歷史解碼、95 筆 catalog 與 7,200 組舊引擎比對的部分。PD-050／051 驗證過的 61 項內容、觸發、洗衣數量政策，以及 PD-041 的人工確認更新安全仍有效。
- Verification boundary: 這個整合步驟必須通過單一 Swift 引擎的 61 項目錄契約、540 組目的地／月份／天數／三種風格矩陣、設備／需求、活動、青旅、洗衣、插座、去重、唯讀 review、選擇性套用、自訂品保護、損毀快照安全、目的地資料測試與完整 App build，才可形成整合提交；所有剩餘功能分支仍須逐一評估語意衝突並各自重跑驗證後才可合入。PWA 已使用 V1 的單一路徑，本步驟不改其程式或部署狀態。

## PD-058 — Integrate trip editing and recommendation refinements into the single engine

- Date: 2026-10-02
- Status: Previously human-accepted behavior; local consolidated candidate pending complete verification
- Decision: 在 PD-057 的單一 Swift 推薦引擎上整合衣物更換週期、完整插頭型式涵蓋判定、每趟行程編輯，以及新增／增量／減量／移除的明確清單 review。無洗衣時，內衣褲與襪子維持每日一件；上衣依輕便／一般／齊全約每 2 天、每 1.5 天、每日更換；下身衣物約每 4／3／2 天更換。有洗衣時，上衣上限為 2／3／4，下身為 2／2／3，內衣褲與襪子為 3／4／5。目的地必須涵蓋出發地所有常見插頭型式才不建議轉接頭；此規則不宣稱能處理電壓差異。
- Context: 來源分支 `1db13d0` 的功能已由使用者明確表示「已驗證，可提交」，但它從舊的 modern／legacy 雙軌基線開發，且在自己的分支重複使用 PD-053～057。整合時保留其已接受的產品行為，移除歷史引擎條件與舊 API，並以新的 canonical 編號記錄，而不是覆寫 `dev` 已存在的 PD-053～057。
- Consequences: 每趟行程可獨立修改名稱、城市、日期、打包風格、設備、個人需求、活動、青旅與洗衣設定。儲存前先比較既有清單；新增與增量預設勾選，減量與移除不預選，自訂項目受到保護，未採納差異時保留待 review 提醒。目的地或日期改變時重新取得候選天氣依據，目的地改變會使先前通關確認失效。iOS 行為由本地整合測試重新驗證後才可提交或推送。PWA 目前未同步每趟編輯與衣物數量精修；依 PD-056 的發布慣例，未經另一次明確 PWA 更新範圍與線上驗證，不將本地 iOS 整合描述為跨平台完成。

## PD-059 — Integrate definition-owned final artwork into the 61-item catalog

- Date: 2026-10-02
- Status: Selected artwork direction and production assets integrated locally; pending consolidated visual acceptance
- Decision: 將方向 B（warm editorial cut-paper／gouache）的 61 張最終 PNG 納入 iOS，且每一筆 canonical 61-item definition 直接持有唯一的 `artworkKey`。卡片只透過 stable catalog ID 或非自訂項目的精確現行名稱解析 definition，不保留第二份 artwork registry、不使用 fuzzy matching，也不恢復 95-item active／legacy catalog。
- Context: 來源分支 `f09b2b2` 已完成 61/61 素材、contact sheet、provenance 與 PWA Site version 15 發布，但它建基於舊的 active/legacy catalog 並重複使用 PD-053～056。為符合 PD-057 的單一路徑架構，本次保留素材與 definition-owned 關係，捨棄舊 catalog 相容層，並以新的 canonical 編號記錄。
- Consequences: 61 筆正式定義都必須有唯一、格式有效且實際存在的 1024×1024 透明 PNG；缺圖或重複 key 由自動測試阻擋。自訂或未知物品仍顯示具名稱的分類 fallback。PWA 已在來源工作完成並驗證為 Site version 15，本地整合不重新部署或改變其線上狀態；App 仍需通過 artwork regression、packing regression、完整 build 與人工 contact-sheet／Simulator 視覺檢查，才可視為整體驗收。

## PD-060 — Integrate TravelGenius backend concepts without changing Structure C UI

- Date: 2026-10-11
- Status: User-authorized implementation; PR pending review
- Decision: 將 Claude Code session 的 JSON 標籤／需求索引、個人行李庫、逐趟快照一致性與參考資料更新機制接入 PackSmart `dev`。保持現有 Structure C UI、61 項定義／素材、衣物數量、原因、排序、插座涵蓋與人工 review 語意。常備用品透過原 API 遷移至獨立 SwiftData store，保留原始 defaults；沒有快照的行程使用固定 normal／phone 偏好，避免讀取另一裝置的全域偏好。
- Context: 使用者要求讀取 TravelGenius 後端設計的 Claude session、整合至 PackSmart、前端 UI 不改動並開 PR。來源設計早於 PackSmart 較新的活動／天氣／洗衣／通關與 artwork 政策，因此移植後端能力而非覆寫新功能。
- Consequences: 推薦仍只有一條執行路徑，JSON 是條件與公式的唯一來源；用品身分與 artwork 維持 app 版本契約。九份參考資料整批通過 manifest hash 與交叉驗證才於下次啟動採用；發布端點未設定時使用 bundle。個人庫 CloudKit 是簽名 build 的 opt-in 配置，預設本地；主行程及舊健康模型明確保留本地，未執行 cloud migration，沒有宣稱兩裝置同步已完成。Release 排除 Secrets.plist 且不讀第三方 AI key；Debug 必須以引數明確開啟。沒有部署代理、新增同意 UI、變更 bundle/group ID 或刪除使用者資料。PWA 格式同步適合後續處理，但本次 App 範圍不變更或發布 PWA；詳見 `docs/backend-integration.md`。
- Supersedes: PD-057／058 中推薦政策必須由固定 Swift 實作、packing_rules.json 不參與 runtime 的機制選擇；保留其單一路徑、61 項目錄與原有推薦政策。PD-059 的 definition-owned artwork 與 PD-041 的明確 review 安全仍有效。
- Verification: 540 組既有推薦矩陣、2,916 組整合前 oracle、快照與選擇性採納、常備遷移／重開／損毀資料、整批更新／ETag／部分失敗／離線 bundle fallback、天氣／目的地／61 張素材及 Debug／Release App build。CloudKit provisioning 與真機跨裝置同步仍需團隊設定後驗收。

## PD-061 — Visual packing page: suitcase progress and reason badges

- Date: 2026-10-19
- Status: User-selected direction (「先做概念 2 和概念 1」); local candidate pending human acceptance
- Decision: 打包頁圖片模式以「行李箱」取代文字進度：已打包物品的插圖依序放進打開的行李箱，空位以虛線格表示，箱蓋顯示出發倒數與 N / M；物品超過 12 件時依比例換算格數。每張物品卡在插圖左下顯示最多兩個原因徽章（天氣、這趟安排、你的設定、目的地、常備），清單上方「這趟為你調整了 N 件」可依原因篩選，非相關物品淡出但仍可操作。圖片模式成為新安裝的預設；既有安裝（已完成 onboarding 或已有行程）若從未切換過，啟動時寫入文字模式，維持原本畫面；已選過的使用者維持原選擇。
- Context: 使用者指出現有版面文字過多，看過五個視覺化概念的可操作原型（personalization-design-spec.md「視覺呈現」）後，選擇先做原因徽章與行李箱進度。
- Consequences: 徽章來源由推薦引擎依規則與需求所測試的標籤類別推導（weather → 天氣；activity／stay／laundry → 這趟安排；device／need／style → 你的設定；plug／country → 目的地）；`none` 條件不產生徽章，因為因「沒有某標籤」而觸發的規則是未調整的預設（例：沒有洗衣時的衣物無徽章，有洗衣而減量時才標「這趟安排」），常備由既有常備比對判斷；只用於顯示，不寫入 PackingItem、不影響推薦輸出、review 比較或 2,916 組 oracle。以這趟保存的快照重新計算，快照無效時不顯示徽章；自訂且非常備的物品沒有徽章。文字模式、review、回程模式與分享不變。天氣與常備徽章使用元件內固定色，其餘沿用主題 token，沒有新增設計系統 token。
- App / PWA: 只實作 iOS。PWA 已有自己的圖卡與 3D，原因徽章與行李箱進度適合同步，但需另行決定 PWA 範圍與部署，本次未變更或發布 PWA。
- Verification: 新增引擎原因類別測試（基本品無類別、天氣、活動、設備、插座、無洗衣衣物無類別、洗衣衣物為這趟安排），既有 backend／packing（540 組）／compatibility（2,916 組）／weather 回歸、目的地資料與 manifest 檢查通過；Debug App build 通過，模擬器以示範行程確認行李箱、徽章與篩選畫面。尚未做 VoiceOver 與動態字級的人工驗收。

## PD-062 — Supabase for accounts, cloud sync and admin backend

- Date: 2026-10-26
- Status: Proposed; awaiting team decisions（新的狀態類別：只記錄提案，不授權上線）。伺服器端已在 `supabase/` 試作並在本機測試，未部署、App 未串接
- Decision: PackSmart 以 Supabase（Auth + PostgreSQL + Edge Functions）作為唯一雲端使用者資料來源；SwiftData 保留為本機副本，推薦引擎仍在手機上計算，未登入或未同意同步時行為不變。`health` 分類的用品預設不上傳，下載雲端版本時保留本機的這些物品；使用者另外同意才同步。日常管理透過驗證 `admin_users` 與 MFA 的資料庫函式（刪除帳號經 Edge Function），查看與修改都寫入稽核紀錄；Dashboard 擁有者限 1～2 人。service_role key 只存在伺服器端。不使用雲端 AI。`feature/cloudflare-worker` 暫停、不合併。
- Supersedes: PD-060 中「沒有帳號系統、外部資料庫與部署代理」的邊界（`backend-integration.md`：「No REST service, account system, external database or PWA deployment is introduced.」「No proxy is deployed.」），以及個人庫以 CloudKit 選配同步的機制（實作時移除 CloudKit 選項，避免雙寫）；個人化規格原則 6「**資料留在本機**，不需要帳號、不使用雲端 AI」改為「未登入時資料留在本機；不使用雲端 AI」。PD-060 的單一推薦引擎、參考資料整包驗證與退回內建、常備用品遷移仍有效。
- Context: 團隊確認需要帳號與雲端同步、管理後台，且私密物品需遵守隱私法規。Cloudflare Worker 沒有帳號與資料庫，CloudKit 私有資料無法集中管理。
- Consequences: 需要隱私權政策、使用者同意、匯出與刪除帳號功能；個資法要求須另請人確認。其他裝置看不到未同意同步的健康類物品。第一版不支援切換帳號。免費方案限制與營運方式見 `docs/supabase-plan.md`。
- App / PWA: 本提案先涵蓋 iOS；PWA 之後共用同一個 Auth 與資料表，範圍另行決定。
- Verification: `supabase/tests` 以 PGlite 執行真正的 migration，驗證 RLS 隔離、直接寫入被拒、CAS 衝突、冪等重試、payload 驗證、健康類物品需同意、管理員名單／MFA／原因／稽核（含查看）、刪除 cascade；Edge Function 以模擬環境驗證只刪本人、授權失敗不刪除：PASS。另以 `supabase start` 的本機完整環境（PostgreSQL 17、Auth、Edge Runtime）執行 `npm run smoke`，以真實使用者 token 驗證同步、隔離、健康類同意、管理員 TOTP MFA 與稽核、Edge Function 刪除帳號，27 項全部通過（2026-10-26）。尚未部署到雲端專案；iOS 串接與其餘驗收條件見 `docs/supabase-plan.md`。
