# PackSmart Native iOS Overrides

This file overrides web-specific recommendations in `MASTER.md` for the SwiftUI app.

## Product principles

- Trust first: legal and customs content uses clear severity labels, official sources, and last-verified dates.
- Calm progress: one primary action per screen, visible three-step progress, predictable back and cancel routes.
- Playful support: the mascot and warm orange are supportive accents, not structural navigation icons.

## Native tokens

- Primary action: Asset Catalog `AccentColor` / SwiftUI `.tint`.
- Warm accent: system orange for highlights and the mascot.
- Success, warning, danger: system green, orange, and red, always paired with an SF Symbol and text.
- Canvas: `systemGroupedBackground`; surface: `secondarySystemGroupedBackground`; elevated surface: `systemBackground`.
- Spacing: 4, 8, 16, 24, 32 pt.
- Radius: 10, 16, 24 pt using continuous corners.
- Typography: Dynamic Type system styles with rounded design for major headings; no bundled web fonts.
- Icons: SF Symbols with text labels for navigation and important actions.
- Motion: 150–250 ms, subtle and interruptible; respect Reduce Motion.

## Interaction rules

- Minimum touch target is 44×44 pt; primary buttons are 52 pt high.
- Multi-step creation always exposes Back or Cancel; cancelling discards the unfinished trip after confirmation.
- Color never communicates trip or regulation state by itself.
- Forms use native labels, pickers, date pickers, and inline helper text.
- Top-level navigation is 行程／設定. Trip details use an inline 行程資訊／Checklist／Tips segmented switch.
- Trip lifecycle is explicit: dates trigger prompts, while only user actions start or complete a trip.
