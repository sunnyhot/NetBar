# NetBar Menu Bar Compact Padding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the menu bar background capsule horizontally tighter by reducing background-mode padding from 5 pt per side to 3 pt per side.

**Architecture:** Keep the existing `StatusBarDisplayRenderer` layout flow. Change only `horizontalPadding(settings:)`, with a focused test that verifies automatic background width and stable minimum width use 6 pt total horizontal padding.

**Tech Stack:** Swift 5 language mode, SwiftPM, AppKit/CoreGraphics renderer, XCTest.

## Global Constraints

- macOS 13+.
- No third-party dependencies.
- No new preference, slider, preset, or migration.
- No change to no-background padding, character-to-text spacing, font size, line spacing, text alignment, arrows, character scale, or character positioning.
- No broad refactor of `StatusBarStyle.swift`.

---

### Task 1: Compact Background Padding

**Files:**
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Modify: `Sources/NetBar/StatusBarStyle.swift`

**Interfaces:**
- Consumes: `StatusBarDisplayRenderer.presentation(snapshot:settings:)`, `StatusBarDisplayRenderer.stableMinimumWidth(settings:)`, `StatusBarSettings.showsBackground`.
- Produces: unchanged public renderer API; background-mode `horizontalPadding(settings:)` returns 3, no-background mode still returns 2.

- [ ] **Step 1: Write the failing test**

Update `testStatusBarBackgroundAutomaticWidthUsesCompactHorizontalPadding` in `Tests/NetBarTests/PreferencesAndPresentationTests.swift` so it expects 6 pt of total horizontal padding:

```swift
XCTAssertEqual(presentation.width, ceil(stableTextWidth + 6))
XCTAssertEqual(
    StatusBarDisplayRenderer.stableMinimumWidth(settings: settings),
    ceil(stableTextWidth + 6)
)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarBackgroundAutomaticWidthUsesCompactHorizontalPadding
```

Expected: failure showing the current width equals `ceil(stableTextWidth + 10)` instead of `ceil(stableTextWidth + 6)`.

- [ ] **Step 3: Write minimal implementation**

Change `horizontalPadding(settings:)` in `Sources/NetBar/StatusBarStyle.swift` to:

```swift
private static func horizontalPadding(settings: StatusBarSettings) -> CGFloat {
    settings.showsBackground ? 3 : 2
}
```

- [ ] **Step 4: Run focused test to verify it passes**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarBackgroundAutomaticWidthUsesCompactHorizontalPadding
```

Expected: focused test passes.

- [ ] **Step 5: Run full test suite**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Review final diff**

Run:

```bash
git diff -- Sources/NetBar/StatusBarStyle.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
```

Expected: one assertion expectation update and one padding constant update.
