# NetBar Living Signal UI Restructure Design

## Overview

This design defines a major UI restructure for NetBar. The approved direction is:

- Visual direction: Living Signal.
- Motion intensity: Balanced pulse.
- Details window layout: slightly wider than today, approximately 480 to 520 px.
- Rollout strategy: replace the default UI instead of adding a separate theme mode.
- Implementation depth: full UI restructure with multi-file decomposition and a larger diff.

The core product promise remains unchanged:

- Local-first macOS menu bar network monitoring.
- No packet capture.
- No network content inspection.
- No administrator permission requirement.
- Pure Swift and system frameworks only.
- macOS 13+.
- Bilingual Chinese and English UI.

The intent is to make NetBar feel like a living network signal instrument: clear enough for daily menu bar use, but more expressive through pulse, glow, scan, and status-linked motion.

## Goals

- Rebuild the visible UI architecture so details-window views are small, focused, and testable.
- Replace the current default visual language with Living Signal across the details window, preferences, and menu bar status effects.
- Make realtime network state the first visual signal in the details window.
- Improve readability of trends, insights, app traffic, history, interface state, and system resources.
- Add balanced, status-driven effects that feel alive without overwhelming a utility app.
- Respect system appearance, reduced motion, and existing language preferences.
- Preserve existing monitoring, persistence, sampling, update, history, notification, pet, and character behavior.

## Non-Goals

- No packet capture, packet parsing, visited-domain display, or network payload inspection.
- No external dependencies.
- No migration away from AppKit, SwiftUI, Combine, or CoreGraphics.
- No rewrite of the network sampling engine.
- No new account, telemetry, cloud sync, or remote analytics.
- No separate full theme system.
- No changes to update packaging, signing, release scripts, or RunCat image resources unless a later implementation task explicitly needs them.

## Product Decisions

### Default UI Replacement

Living Signal becomes the default experience. The app should not expose a separate "old UI" theme or full visual-mode switch.

Motion and intensity are controlled through:

- macOS Reduce Motion compatibility.
- Existing appearance and menu bar settings.
- Local fallback rules that reduce recurring effects when data is idle, the details window is not visible, or the system asks for lower motion.

### Balanced Pulse

The default motion level is balanced:

- Normal state: subtle material depth, soft status tint, and small transitions.
- Active traffic: visible pulse in the chart and status surfaces.
- High traffic, upload dominance, or anomaly: stronger border glow, icon pulse, or chart emphasis.
- Reduced motion: no looping scan or breathing effects, only non-looping state transitions.

### Slightly Wider Details Window

The details window should move from today's 440 px fixed width to a target width around 500 px, with small-screen safety through `DetailsWindowLayout`.

The window must still feel like a menu bar popover:

- It remains anchored to the status item when possible.
- It remains transient and easy to dismiss.
- It does not become a large dashboard window.

## Architecture

### Source Layout

Create a new popover-focused folder:

```text
Sources/NetBar/Popover/
```

The goal is to reduce `NetworkPopoverView.swift` into an entry point and data composition layer, then move display responsibilities into focused subviews.

Proposed files:

```text
Sources/NetBar/Popover/
  LivingSignalDesignSystem.swift
  NetworkPopoverView.swift
  PopoverHeaderView.swift
  TrafficPulseChartView.swift
  InsightStreamView.swift
  ApplicationTrafficPanel.swift
  NetworkSummaryPanel.swift
  InterfaceAndSystemPanel.swift
  PopoverFooterView.swift
```

Depending on implementation size, shared small components may be split further:

```text
Sources/NetBar/Popover/
  LivingSignalComponents.swift
  LivingSignalEffects.swift
```

### Entry Point

`NetworkPopoverView` remains the root view embedded by `DetailsWindowController`. Its responsibilities should become:

- Receive `NetworkMonitor`, `AppPreferences`, `CustomCharacterStore`, and callbacks.
- Build presentation values from existing models.
- Compose the major panels.
- Apply the overall background, fixed width constraints, and color scheme.

It should stop owning most individual row, chart, badge, and card implementations.

### Design System

`LivingSignalDesignSystem.swift` should provide a small app-native design layer, not a generic framework.

It should include:

- Surface styles: panel, elevated panel, inline row, compact chip.
- Status tones: normal, active, upload, attention, critical, neutral.
- Palette roles for light and dark appearance.
- Motion tokens for quick, settle, pulse, scan, and disabled-motion variants.
- Layout tokens for radius, spacing, row height, chart height, and icon tile size.
- Helpers for Reduce Motion and non-looping fallback.

Existing `NetBarDesignSystem.swift` can either:

- Become a compatibility layer that forwards to the Living Signal tokens.
- Keep general shared primitives while popover-specific styles move to `Sources/NetBar/Popover/`.

Implementation should avoid a broad style abstraction that is not used by real NetBar views.

## Details Window Design

### Layout

The details window becomes a signal panel with these high-level regions:

1. Signal header.
2. Traffic pulse chart.
3. Insight stream.
4. Network summary and history.
5. Application traffic.
6. Interface and system resources.
7. Footer controls.

The main scroll should remain lazy where possible to preserve open performance. Cards should not be nested inside decorative cards.

### Signal Header

The header should communicate current network state immediately:

- Total current throughput.
- Download and upload speed.
- Main interface display name when available.
- Active status label, such as normal, active, upload heavy, anomaly, or idle.
- A compact icon or character-adjacent signal mark.

The header can use a low-opacity pulse or glow tied to state. It must remain readable in light and dark appearances.

### Traffic Pulse Chart

The chart becomes the primary visual anchor.

Requirements:

- Show download and upload series.
- Use stable dimensions to prevent layout shifts.
- Include a subtle scan or pulse effect in normal motion mode.
- Highlight active or peak state without relying on color alone.
- Preserve selected history window behavior.
- Continue to support short, empty, or single-point data safely.

The chart should not require a third-party charting library.

### Insight Stream

Insight and anomaly cards should become more scannable:

- Strong title and severity.
- Short explanation.
- Optional suggestion.
- Tone-linked icon or chip.
- No empty fields when optional data is absent.

Normal state should be calm and compact. Warning or critical state can receive a stronger border pulse.

### Summary and History

Today, seven-day, thirty-day, and favorite-character summaries should share a consistent metric language.

Requirements:

- Keep estimate wording where history totals are shown.
- Preserve existing daily summary presentation logic.
- Keep milestone effects but align their glow with Living Signal tokens.
- Avoid shrinking long English or Chinese labels into unreadable text.

### Application Traffic

The app traffic panel should stay operational and dense:

- Search remains visible and predictable.
- Sort/filter controls remain efficient.
- Top apps and realtime app rows should use a consistent row style.
- Attribution warnings should become quieter but clearer.
- App icons remain lazy-resolved to preserve performance.

### Interface and System Resources

Interface and system resource panels should feel like diagnostic instruments:

- Interface rows show name, display name, download, upload, and role.
- Empty state explains when interface data is unavailable.
- System resource card shows memory, CPU, thermal state, and sampling freshness when useful.

## Preferences Design

Preferences should use the same Living Signal visual vocabulary, while preserving existing settings and persistence.

Scope:

- Rework shared preference section components.
- Update the hero/header area.
- Align cards, toggles, segmented controls, swatches, and preview surfaces.
- Keep tab structure unless implementation reveals a clear reason to change it.
- Avoid moving business logic out of preference view models into visual components.

User-visible strings must continue to use Chinese and English variants through existing `appPreferences.text(...)` or `AppLanguage.text(...)` patterns.

## Menu Bar Effects

The menu bar remains CoreGraphics-based through `StatusBarDisplayRenderer`.

Requirements:

- Keep render signature and image cache behavior.
- Avoid dynamic effects that force unnecessary redraws.
- Quantize time-based effects as the renderer already does for dynamic color.
- Add or tune balanced pulse effects around background, character, or state accent only when settings and context make it appropriate.
- Preserve automatic width, manual width, character position, character facing, and smart status behavior.

Potential effects:

- Soft status glow on high activity.
- Subtle background pulse when a status bar background is enabled.
- Character halo for supported characters during active traffic.
- Stronger anomaly accent with bounded redraw frequency.

Reduce Motion should disable recurring pulse effects.

## Data Flow

The UI must continue to consume existing published data:

```text
NetworkMonitor.snapshot
NetworkMonitor.appTraffic
NetworkMonitor.systemResources
NetworkMonitor.intelligenceSummary
AppPreferences
StatusBarSettings
CustomCharacterStore
```

No sampling or reader protocols should change for this UI restructure.

Presentation helpers may be introduced when they make UI code easier to test. They should stay close to existing model boundaries:

- `ApplicationTrafficPresentation`
- `NetworkHistoryPresentation`
- `NetworkDailySummaryPresentation`
- `NetworkIntelligenceStatusPresentation`

## Accessibility and Performance

### Accessibility

- Respect `accessibilityReduceMotion`.
- Preserve keyboard accessibility for buttons, search, segmented controls, and preference controls.
- Keep icon-only buttons labeled with `.help` and accessibility labels where needed.
- Do not communicate status by color alone.
- Maintain readable contrast in light and dark modes.
- Avoid font scaling based on viewport width.

### Performance

- Preserve lazy construction for below-the-fold detail sections.
- Keep expensive icon resolution deferred.
- Avoid heavy per-frame SwiftUI work.
- Prefer opacity and transform for motion.
- Avoid animating layout dimensions.
- Avoid running looping effects when the details window is not visible.
- Keep menu bar rendering cache-friendly.

## Testing Strategy

Run at minimum:

```bash
swift test
```

Add or update tests for:

- Details window layout sizing and positioning after width changes.
- Presentation helpers for header status, insight state, summary cards, and traffic chart input edge cases.
- Status bar render signature behavior when any new pulse-related setting or context is introduced.
- Reduced-motion behavior for any new animation policy helper.
- Existing preference persistence if new settings are introduced.

If implementation touches resources, packaging, update metadata, build scripts, app bundle assembly, or signing behavior, also run:

```bash
./Scripts/build-app.sh
./Scripts/verify-release-app.sh build/NetBar.app
```

This design does not require release packaging changes by itself.

## Risks

- The current `NetworkPopoverView.swift` is large. Splitting it can accidentally change behavior while moving code.
- Window width changes can break small-screen positioning.
- Animated SwiftUI effects can hurt first-frame responsiveness.
- Menu bar time-based effects can defeat render caching if not quantized.
- Preferences may drift visually if shared components are not updated first.
- A large diff can mix structural movement with visual changes, making review harder.

Mitigation:

- Split in phases.
- Keep data models and sampling unchanged.
- Add focused tests around layout and presentation helpers.
- Move code before changing behavior where practical.
- Keep menu bar effects bounded by existing render scheduling and cache strategy.

## Implementation Phases

### Phase 1: Design System and Shell

- Add Living Signal tokens and shared components.
- Update details window target sizing.
- Create popover folder and root composition structure.
- Keep visuals close to current behavior while splitting.

### Phase 2: Details Window Rebuild

- Implement signal header.
- Replace chart with traffic pulse chart.
- Rebuild insight, summary, app traffic, interface, and system panels.
- Preserve existing data and controls.

### Phase 3: Preferences Refresh

- Update shared preference sections and hero.
- Align menu bar, intelligence, application, update, diagnostics, and about sections with Living Signal style.
- Preserve all settings, keys, reset behavior, and bilingual strings.

### Phase 4: Menu Bar Balanced Pulse

- Add bounded status-linked effects in `StatusBarDisplayRenderer`.
- Keep signature/cache behavior explicit.
- Add tests for any new signature input or render policy.

### Phase 5: Verification and Polish

- Run tests.
- Fix visual regressions and layout issues.
- Review light/dark appearance.
- Review reduced motion.
- Confirm no `.superpowers/` visual-companion artifacts are committed.

## Acceptance Criteria

1. NetBar details window uses the Living Signal visual language by default.
2. The details window is decomposed into focused popover files rather than remaining one large view file.
3. The details window target width is around 480 to 520 px and still fits small visible frames.
4. Header, chart, insight, summary, app traffic, interface, system resource, and footer regions remain available.
5. Existing network sampling behavior is unchanged.
6. Existing preferences and settings persistence continue to work.
7. Menu bar rendering continues to use signature and cache paths.
8. Balanced pulse effects are status-linked and reduced-motion aware.
9. User-visible strings added during implementation have Chinese and English variants.
10. `swift test` passes.

