# Stage 6 first candidate delivery — 2026-09-25

Status: implementation candidate; human acceptance pending. The first five item concepts are illustrated, not the entire catalog.

## Published versions

- Native implementation: `0470a88` on `codex/ios-06-visual-list`, pushed to GitHub.
- PWA source: `d321e6a9fa34a0cc1cd64a791d9dab12a8187d7b`, pushed to the existing Site repository.
- Site version: 10, deployment succeeded; https://packmon.stevenchen841204.chatgpt.site
- Version ID: `appgprj_6aae4c4091148191a41e5337c997f70e~appgver_fd3ec74faf7481919205527aea8c3b6c`
- Deployment ID: `appgdep_6ab611d9c5fc8191b9b09b5204d63fb0`
- PWA candidate tag: `packmon-site-stage06-candidate-2026-09-25`.
- Accepted native rollback checkpoint: `packmon-ios-stage-05-accepted`.
- Previous PWA release: Site 9, source `18763949d7198de10eb560424be96167da6a249e`, tag `packmon-site-stage05-candidate-2026-09-25`.

Rollback means restoring the selected code/deployment version; it does not restore or erase user trip data. No data schema changes were introduced.

## Verification

Native build and artwork mapping regression passed. Existing regression suite passed (7,200 matrix cases, 192 needs/style cases, persistence/migration and Stage 5 selective-add coverage). PWA tests: 55 passed. Isolated UI fixtures verified packed-state and quantity preservation across text/image modes; mobile and desktop card layouts inspected. Test fixtures were not shipped and normal App was reinstalled/launched with existing user data preserved.

Not yet verified: real-device VoiceOver, all accessibility text sizes, storage-full recovery and offline reopening. Do not treat bundled/pre-cached assets alone as an offline end-to-end test.

## Human acceptance checklist

1. Open a trip → packing → 圖片; inspect the two-column cards on App and PWA.
2. Check/uncheck an item and change quantity; switch to 文字 and confirm the same values remain.
3. On App, cancel a quantity edit and confirm no change; save another edit and reopen the trip.
4. Inspect custom/unillustrated items: 分類示意 is visible and normal item operations remain usable.
5. Check remove confirmation/cancel and that existing recommendation review still uses its original flow.
6. After first loading the release, check offline reopening separately.

Remaining: expand catalog artwork after review; confirm commercial provenance of reused artwork before commercial distribution. See `visual-list-spec.md`, decision PD-043 and `design-qa.md` for scope and evidence.
