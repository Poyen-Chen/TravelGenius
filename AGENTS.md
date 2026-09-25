# Packmon Project Instructions

## Product decisions

- Any implementation that introduces or changes product behavior, navigation, scope, defaults, user-visible data, destructive actions, or design-system policy must be recorded in `docs/product-decisions.md` in the same change.
- Add a new numbered entry with date, status, decision, context, and consequences. Do not silently rewrite an accepted decision; supersede it with a new entry and link the earlier decision.
- Pure bug fixes, mechanical refactors, and visual corrections that do not change intended behavior do not require a new decision entry.

## App / PWA parity check

- For every feature, flow or style change, assess whether the same change is suitable for the other platform. Sync suitable changes within the requested scope; ask before expanding into experimental features or changing platform-specific behavior.
- In each delivery, state what was synchronized to PWA/iOS, or why it was intentionally not synchronized. This is functional/visual parity, not cross-platform data synchronization.

## Design source of truth (current redesign)

- For the current redesign, use the topmost Claude Artifact section named “結構 C 完整版” as the only design source of truth. Ignore older sections below it.
