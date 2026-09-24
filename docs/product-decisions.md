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
