# NetBar UI Redesign Design

## Overview

This design defines a full visual redesign for NetBar's visible app UI. The approved direction is **a calmer macOS-native network instrument**, replacing the current mint-heavy Living Signal styling with clearer hierarchy, restrained color, and more durable system-like surfaces.

The redesign covers:

- Details popover.
- Preferences window.
- Shared SwiftUI design tokens used by both surfaces.

The redesign does not change network sampling, history, notifications, update logic, app traffic collection, menu bar rendering behavior, pets, RunCat assets, packaging, or release scripts.

## Goals

- Make the UI feel coherent across the details popover and preferences window.
- Replace broad pastel tinting with a restrained surface system.
- Preserve NetBar's identity as a realtime network monitor while making it look more stable and mature.
- Improve scannability for speed, chart, status, insights, app traffic, and settings sections.
- Reduce nested-card visual noise.
- Keep the interface bilingual and compatible with light mode, dark mode, and follow-system appearance.
- Keep implementation inside the existing SwiftUI and AppKit architecture with no third-party dependencies.

## Non-Goals

- No new theme selector or old-UI toggle.
- No redesign of the menu bar status item in this pass.
- No changes to monitoring, persistence, `nettop`, update, notification, history, or pet behavior.
- No new external assets, fonts, packages, or design libraries.
- No marketing page, onboarding rewrite, or product copy expansion.
- No app icon or RunCat character redesign.

## Visual Direction

### Personality

NetBar should feel like a quiet network instrument for macOS:

- Calm enough to sit beside system utilities.
- Precise enough for repeated daily inspection.
- Alive only where realtime signal matters.
- Playful only in small touches, not in every surface.

### Palette

Use one primary signal color and a small semantic palette:

- Signal teal: realtime activity, primary selected state, active charts.
- Coral: upload-heavy or upload series.
- Amber: attention, warning, temporary degraded state.
- Red: critical or destructive state only.
- Graphite neutrals: text, borders, dividers, inactive controls.
- Mist surfaces: light-mode panel backgrounds with very low saturation.

The main change is to stop tinting large panels with strong mint backgrounds. Color should appear as status dots, thin borders, icon tiles, chart lines, selected tabs, and compact chips.

### Typography

Keep Apple's system font stack:

- Section titles: system, semibold or bold, compact sizes.
- Body labels: system, regular or medium.
- Data values: monospaced digits or monospaced design where already used.
- Avoid overusing rounded design. Use it only for status labels or small identity moments.

The UI should read less like a dashboard hero page and more like a native utility.

### Surfaces

Define a shared surface model:

1. Window background: neutral material or window background with subtle tonal gradient at most.
2. Panel surface: flat elevated container with low-opacity border.
3. Row surface: compact list or metric row, visually lighter than panel.
4. Selected surface: signal teal fill at very low opacity plus a crisp border.

Avoid cards inside cards unless the inner card is a repeated row item. Page sections should not all look like floating cards.

### Motion

Preserve a living signal feel through restrained motion:

- Chart line emphasis when traffic changes.
- Small status pulse on the active indicator.
- No broad glowing backgrounds.
- Respect Reduce Motion by disabling looping effects.

## Details Popover Design

### Layout

Keep the current decomposed `Sources/NetBar/Popover/` structure, but redesign the visual composition:

1. Compact signal header.
2. Realtime chart as the main instrument.
3. Status and insight strip.
4. Summary metrics.
5. App traffic.
6. Interface and system diagnostics.
7. Footer controls.

The popover should remain anchored, transient, and menu-bar-sized. It should not become a large dashboard window.

### Signal Header

The header should be smaller and more information-dense:

- Left: active status mark, status title, short subtitle.
- Right: total throughput chip.
- Bottom row: download, upload, and interface metrics.

Use signal teal for normal active state, coral for upload-heavy state, amber/red for anomalies. Remove large pastel header washes.

### Traffic Chart

The chart becomes the visual anchor:

- Neutral chart well.
- Teal download line.
- Coral upload line.
- Light grid lines.
- Compact legend.
- Stable height to avoid layout shifts.

The segmented window picker should visually match the new selected-surface rules instead of feeling like a separate system control dropped into a tinted card.

### Insights

Normal state should be quiet and compact. Warnings should be clear without taking over the whole window:

- Use an icon, title, short message, and optional action.
- Use tone border and small chip instead of full tinted card backgrounds.
- Empty states should be short and visually calm.

### App Traffic

App traffic remains dense and operational:

- Search and sorting remain visible.
- App rows use a consistent diagnostic-row style.
- Attribution warnings become quieter but still discoverable.
- App icons remain lazy-resolved.

### Footer

Footer controls should feel like a native utility toolbar:

- Status chip on the left.
- Icon buttons on the right.
- Neutral surface, with the quit action using only a small warning color.

## Preferences Window Design

### Layout

Redesign preferences as a settings center rather than a signal dashboard:

- Keep the current window controller and SwiftUI root.
- Replace the large colorful hero with a compact title area.
- Use restrained tab navigation, either top tabs with neutral selected state or a sidebar-like rail if implementation stays simple.
- Content sections should look closer to system settings groups.

The selected navigation state can use signal teal, but the overall window should not be dominated by teal.

### Header

Replace "NetBar Signal Console" styling with a calmer identity header:

- App icon tile or simple waveform mark.
- Title: NetBar Preferences / NetBar 偏好设置.
- Subtitle: concise explanation of what can be configured.
- Version chip as a quiet trailing element.

The header may keep one small signal accent, but should not use a large active gradient panel.

### Sections

Preference sections should use consistent spacing, labels, and grouped controls:

- Section title with optional icon.
- Neutral grouped surface.
- Controls aligned on stable rows.
- Help text in tertiary text, not inside heavily tinted cards.

Existing bilingual text should remain.

## Shared Design System

### Token Ownership

Move visual decisions into shared tokens rather than local hard-coded colors:

- `LivingSignalTone` can be retained but recalibrated.
- Add or refine surface helpers for background, panel, row, selected, chip, and icon button styles.
- `NetBarDesignSystem.swift` should act as the shared compatibility layer.
- Popover-specific layout constants can remain in `LivingSignalLayout`.

### Suggested Roles

- `signal`: primary teal.
- `upload`: coral.
- `attention`: amber.
- `critical`: red.
- `neutral`: graphite.
- `panelBackground`: adaptive neutral panel.
- `rowBackground`: adaptive row surface.
- `selectedBackground`: low-opacity signal fill.
- `hairline`: adaptive border.

### Compatibility

The redesign should avoid broad API churn:

- Prefer changing existing modifiers and small view bodies.
- Keep public view inputs intact.
- Avoid introducing a new theme object unless repeated code proves it necessary.

## Implementation Boundaries

Likely affected files:

- `Sources/NetBar/Popover/LivingSignalDesignSystem.swift`
- `Sources/NetBar/NetBarDesignSystem.swift`
- `Sources/NetBar/Popover/PopoverHeaderView.swift`
- `Sources/NetBar/Popover/TrafficPulseChartView.swift`
- `Sources/NetBar/Popover/InsightStreamView.swift`
- `Sources/NetBar/Popover/NetworkSummaryPanel.swift`
- `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`
- `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`
- `Sources/NetBar/Popover/PopoverFooterView.swift`
- `Sources/NetBar/Preferences/PreferencesWindowController.swift`
- `Sources/NetBar/Preferences/PreferencesComponents.swift`
- Selected preference subviews only where section styling requires it.

Avoid changing:

- Sampling readers.
- `NetworkMonitor` behavior.
- Update and release code.
- Persistence defaults.
- RunCat resources.
- App entitlements and packaging scripts.

## Data Flow

No data-flow changes are required. Existing published state continues to drive UI:

```text
NetworkMonitor / AppPreferences / AppUpdater
  -> existing presentation models
  -> SwiftUI popover and preferences views
  -> shared design modifiers and tokens
```

The redesign only changes how existing state is presented.

## Error Handling And Empty States

Existing error and empty states remain functionally the same, but visual treatment changes:

- Empty states use neutral row surfaces.
- Warnings use amber icon and border, not broad amber backgrounds.
- Critical states use red sparingly.
- Retry and preferences actions keep their current callbacks.

## Testing And Verification

Run after implementation:

```bash
swift test
```

Because this is UI-only SwiftUI/AppKit work, also run:

```bash
./Scripts/build-app.sh
./Scripts/verify-release-app.sh build/NetBar.app
```

Manual visual QA:

- Light appearance.
- Dark appearance.
- Chinese UI.
- English UI.
- Details popover with idle, active, upload-heavy, and anomaly-like states if mocks or live conditions allow.
- Preferences window at minimum size and a larger resized size.

## Acceptance Criteria

- Details popover and preferences window look like the same product.
- Large mint/pastel washes are removed or greatly reduced.
- Active network state remains visually recognizable.
- Upload, warning, and critical states have distinct semantic color.
- Text remains readable in Chinese and English.
- Controls do not overlap or resize unpredictably.
- Existing tests pass.
- App builds through the project scripts.

