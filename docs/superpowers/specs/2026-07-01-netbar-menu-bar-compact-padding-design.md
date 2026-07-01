# NetBar Menu Bar Compact Padding Design

## Overview

The menu bar status item currently feels too wide when the background capsule is enabled. The approved change is to make the capsule's left and right content padding more compact while preserving the existing text layout, character spacing, rendering cache behavior, and automatic width model.

## Goals

- Reduce the background capsule horizontal padding from 5 pt per side to 3 pt per side.
- Keep the no-background padding at 2 pt per side.
- Keep character-to-text spacing unchanged.
- Keep automatic width based on the same stable speed templates.
- Keep fixed-width user settings unchanged.
- Add focused regression coverage for the compact background padding.

## Non-Goals

- No new preference, slider, preset, or migration.
- No change to font size, line spacing, text alignment, arrows, character scale, or character positioning.
- No change to popover layout, sampling, history, notifications, update flow, or RunCat resources.
- No broad refactor of `StatusBarStyle.swift`.

## Architecture

`StatusBarDisplayRenderer` already centralizes menu bar layout in `StatusBarStyle.swift`. The implementation should change only the private `horizontalPadding(settings:)` calculation used by automatic width, stable minimum width, background drawing, character placement, and text rect calculation.

The cache key already includes `showsBackground`, so background and no-background layout variants remain separate. No cache structure change is needed.

## Data Flow

`StatusBarSettings.showsBackground` feeds `StatusBarDisplayRenderer.horizontalPadding(settings:)`. The resulting padding feeds `layout(...)`, which produces `StatusBarPresentation.width`, image bounds, text rect, and optional character x-position.

After the change:

- `showsBackground == true`: horizontal padding is 3 pt.
- `showsBackground == false`: horizontal padding remains 2 pt.

## Testing

Add a focused test in `Tests/NetBarTests/PreferencesAndPresentationTests.swift` for background automatic width. It should compute the existing stable text width for up/down speed templates and assert:

- `StatusBarDisplayRenderer.presentation(...).width == ceil(stableTextWidth + 6)`.
- `StatusBarDisplayRenderer.stableMinimumWidth(settings:) == ceil(stableTextWidth + 6)`.

Run the focused test first to watch it fail against the current 5 pt padding, then update the renderer and rerun it. Run `swift test` afterward because this touches status bar rendering behavior.

## Acceptance Criteria

- The screenshot's highlighted status item becomes visibly tighter horizontally.
- Automatic background width shrinks by 4 pt compared with the current implementation.
- No-background menu bar rendering remains unchanged.
- Existing character/text spacing remains unchanged.
- `swift test` passes.
