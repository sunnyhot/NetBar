# NetBar UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign NetBar's details popover and preferences window into a calmer macOS-native network instrument with shared visual tokens and restrained semantic color.

**Architecture:** Keep the existing SwiftUI/AppKit object graph and the current `Sources/NetBar/Popover/` decomposition. First recalibrate shared design tokens, then update the popover composition, then update preferences surfaces, with focused tests guarding token roles and source ownership.

**Tech Stack:** Swift 5 language mode, SwiftPM, AppKit, SwiftUI, Combine, XCTest, macOS 13+.

## Global Constraints

- macOS 13+.
- No third-party dependencies.
- No new theme selector or old-UI toggle.
- No redesign of the menu bar status item in this pass.
- No changes to monitoring, persistence, `nettop`, update, notification, history, pet behavior, app entitlements, packaging scripts, or RunCat resources.
- No new external assets, fonts, packages, or design libraries.
- User-visible copy must remain bilingual through `appPreferences.text("中文", "English")` or `AppLanguage.text(...)`.
- Build App bundles only with `./Scripts/build-app.sh`; do not manually assemble `.app` resources.

---

## File Structure

Modify the existing files; do not add a second theme system.

- `Sources/NetBar/Popover/LivingSignalDesignSystem.swift`: Owns the restrained palette, tone roles, surface constants, panel/row/selected/toolbar modifiers, and motion policy.
- `Sources/NetBar/NetBarDesignSystem.swift`: Compatibility layer for shared badges, icon tiles, icon buttons, section headers, and card-style wrappers.
- `Sources/NetBar/Popover/PopoverHeaderView.swift`: Compact signal header and metric rows.
- `Sources/NetBar/Popover/TrafficPulseChartView.swift`: Neutral chart well, teal download line, coral upload line, compact legend.
- `Sources/NetBar/Popover/InsightStreamView.swift`: Quiet normal state, compact warning/critical rows.
- `Sources/NetBar/Popover/NetworkSummaryPanel.swift`: Summary, history, top applications, seven-day rows, and milestone styling.
- `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`: Search/sort controls, attribution row, app rows, metric colors, app badge.
- `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`: Interface rows, system resource row, metric pill styling.
- `Sources/NetBar/Popover/PopoverFooterView.swift`: Native utility toolbar footer.
- `Sources/NetBar/Preferences/PreferencesWindowController.swift`: Preferences root layout and tab bar.
- `Sources/NetBar/Preferences/PreferencesComponents.swift`: Preferences header, grouped section surface, collapsible section surface.
- `Tests/NetBarTests/PreferencesAndPresentationTests.swift`: Token tests and source-boundary tests for the redesign.

---

### Task 1: Restrained Shared Visual Tokens

**Files:**
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Modify: `Sources/NetBar/Popover/LivingSignalDesignSystem.swift`
- Modify: `Sources/NetBar/NetBarDesignSystem.swift`

**Interfaces:**
- Consumes: `LivingSignalTone`, `LivingSignalLayout`, `NetBarTone`, `NetBarIconButtonStyle`, `NetBarCardModifier`.
- Produces: `LivingSignalColorRole`, `LivingSignalColorSpec`, `LivingSignalPalette`, `LivingSignalSurface`, `LivingSignalTone.role`, `LivingSignalColorSpec.color`, `View.livingSignalRow(tone:padding:)`, `View.livingSignalSelectedSurface(cornerRadius:)`, and `View.livingSignalToolbarSurface(padding:)`.

- [ ] **Step 1: Write the failing token test**

Add this test inside the `// MARK: - Living Signal Design System Tests` extension in `Tests/NetBarTests/PreferencesAndPresentationTests.swift`:

```swift
func testLivingSignalPaletteUsesRestrainedNativeInstrumentRoles() {
    XCTAssertEqual(LivingSignalPalette.signal.red, 0.12, accuracy: 0.001)
    XCTAssertEqual(LivingSignalPalette.signal.green, 0.62, accuracy: 0.001)
    XCTAssertEqual(LivingSignalPalette.signal.blue, 0.57, accuracy: 0.001)

    XCTAssertEqual(LivingSignalPalette.upload.red, 0.88, accuracy: 0.001)
    XCTAssertEqual(LivingSignalPalette.upload.green, 0.41, accuracy: 0.001)
    XCTAssertEqual(LivingSignalPalette.upload.blue, 0.34, accuracy: 0.001)

    XCTAssertEqual(LivingSignalTone.active.role, .signal)
    XCTAssertEqual(LivingSignalTone.normal.role, .signal)
    XCTAssertEqual(LivingSignalTone.uploadHeavy.role, .upload)
    XCTAssertEqual(LivingSignalTone.attention.role, .attention)
    XCTAssertEqual(LivingSignalTone.critical.role, .critical)
    XCTAssertEqual(LivingSignalTone.idle.role, .neutral)
    XCTAssertEqual(LivingSignalTone.neutral.role, .neutral)

    XCTAssertLessThanOrEqual(LivingSignalSurface.windowSignalTintOpacity, 0.025)
    XCTAssertLessThanOrEqual(LivingSignalSurface.windowUploadTintOpacity, 0.018)
    XCTAssertLessThanOrEqual(LivingSignalSurface.selectedFillOpacity, 0.12)
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignalPaletteUsesRestrainedNativeInstrumentRoles
```

Expected: compile failure because `LivingSignalPalette`, `LivingSignalSurface`, and `LivingSignalTone.role` do not exist.

- [ ] **Step 3: Add the restrained palette and surface primitives**

In `Sources/NetBar/Popover/LivingSignalDesignSystem.swift`, replace the current `LivingSignalTone` color and gradient implementation with this token layer, keeping `LivingSignalStatusPresentation`, `LivingSignalLayout`, and `LivingSignalMotionPolicy` in the same file:

```swift
enum LivingSignalColorRole: Equatable {
    case signal
    case upload
    case attention
    case critical
    case neutral
}

struct LivingSignalColorSpec: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

enum LivingSignalPalette {
    static let signal = LivingSignalColorSpec(red: 0.12, green: 0.62, blue: 0.57)
    static let upload = LivingSignalColorSpec(red: 0.88, green: 0.41, blue: 0.34)
    static let attention = LivingSignalColorSpec(red: 0.79, green: 0.53, blue: 0.13)
    static let critical = LivingSignalColorSpec(red: 0.85, green: 0.29, blue: 0.29)
    static let neutral = LivingSignalColorSpec(red: 0.42, green: 0.45, blue: 0.50)
}

enum LivingSignalSurface {
    static let windowSignalTintOpacity = 0.022
    static let windowUploadTintOpacity = 0.014
    static let elevatedFillOpacity = 0.82
    static let panelFillOpacity = 0.66
    static let rowFillOpacity = 0.46
    static let selectedFillOpacity = 0.10
    static let toneFillOpacity = 0.055
    static let rowToneFillOpacity = 0.035
    static let borderOpacity = 0.075
    static let selectedBorderOpacity = 0.22
}

enum LivingSignalTone: String, CaseIterable, Equatable {
    case idle
    case normal
    case active
    case uploadHeavy
    case attention
    case critical
    case neutral

    var role: LivingSignalColorRole {
        switch self {
        case .normal, .active:
            return .signal
        case .uploadHeavy:
            return .upload
        case .attention:
            return .attention
        case .critical:
            return .critical
        case .idle, .neutral:
            return .neutral
        }
    }

    var spec: LivingSignalColorSpec {
        switch role {
        case .signal:
            return LivingSignalPalette.signal
        case .upload:
            return LivingSignalPalette.upload
        case .attention:
            return LivingSignalPalette.attention
        case .critical:
            return LivingSignalPalette.critical
        case .neutral:
            return LivingSignalPalette.neutral
        }
    }

    var color: Color {
        spec.color
    }

    var softColor: Color {
        color.opacity(role == .neutral ? 0.10 : 0.12)
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(role == .neutral ? 0.42 : 0.76)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
```

Then replace `LivingSignalPanelModifier.body` and the view extension at the bottom of the same file with:

```swift
struct LivingSignalPanelModifier: ViewModifier {
    var tone: LivingSignalTone = .neutral
    var isElevated = false
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        let radius = isElevated ? LivingSignalLayout.elevatedPanelCornerRadius : LivingSignalLayout.panelCornerRadius
        let baseFill = Color(nsColor: .controlBackgroundColor)
            .opacity(isElevated ? LivingSignalSurface.elevatedFillOpacity : LivingSignalSurface.panelFillOpacity)

        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tone.color.opacity(tone.role == .neutral ? 0 : LivingSignalSurface.toneFillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        tone.color.opacity(tone.role == .neutral ? LivingSignalSurface.borderOpacity : LivingSignalSurface.selectedBorderOpacity),
                        lineWidth: 0.7
                    )
            )
    }
}

struct LivingSignalRowModifier: ViewModifier {
    var tone: LivingSignalTone = .neutral
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: LivingSignalLayout.rowCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(LivingSignalSurface.rowFillOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: LivingSignalLayout.rowCornerRadius, style: .continuous)
                            .fill(tone.color.opacity(tone.role == .neutral ? 0 : LivingSignalSurface.rowToneFillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: LivingSignalLayout.rowCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(LivingSignalSurface.borderOpacity), lineWidth: 0.6)
            )
    }
}

struct LivingSignalSelectedSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LivingSignalTone.active.color.opacity(LivingSignalSurface.selectedFillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LivingSignalTone.active.color.opacity(LivingSignalSurface.selectedBorderOpacity), lineWidth: 0.6)
            )
    }
}

struct LivingSignalToolbarSurfaceModifier: ViewModifier {
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: LivingSignalLayout.panelCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LivingSignalLayout.panelCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(LivingSignalSurface.borderOpacity), lineWidth: 0.6)
            )
    }
}

extension View {
    func livingSignalPanel(
        tone: LivingSignalTone = .neutral,
        isElevated: Bool = false,
        padding: CGFloat = 0
    ) -> some View {
        modifier(LivingSignalPanelModifier(tone: tone, isElevated: isElevated, padding: padding))
    }

    func livingSignalRow(tone: LivingSignalTone = .neutral, padding: CGFloat = 0) -> some View {
        modifier(LivingSignalRowModifier(tone: tone, padding: padding))
    }

    func livingSignalSelectedSurface(cornerRadius: CGFloat = 8) -> some View {
        modifier(LivingSignalSelectedSurfaceModifier(cornerRadius: cornerRadius))
    }

    func livingSignalToolbarSurface(padding: CGFloat = 0) -> some View {
        modifier(LivingSignalToolbarSurfaceModifier(padding: padding))
    }

    func livingSignalPanelBackground() -> some View {
        background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        LivingSignalTone.active.color.opacity(LivingSignalSurface.windowSignalTintOpacity),
                        LivingSignalTone.uploadHeavy.color.opacity(LivingSignalSurface.windowUploadTintOpacity),
                        Color(nsColor: .windowBackgroundColor).opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
}
```

In `Sources/NetBar/NetBarDesignSystem.swift`, map shared tones to the recalibrated palette:

```swift
var color: Color {
    switch self {
    case .download:
        return LivingSignalTone.active.color
    case .upload:
        return LivingSignalTone.uploadHeavy.color
    case .neutral:
        return LivingSignalTone.neutral.color
    case .success:
        return LivingSignalTone.normal.color
    case .warning:
        return LivingSignalTone.attention.color
    case .purple:
        return LivingSignalTone.neutral.color
    case .danger:
        return LivingSignalTone.critical.color
    }
}
```

Keep the existing `NetBarTone.gradient` property, but make each case use `color` plus a lower-opacity second stop:

```swift
var gradient: LinearGradient {
    LinearGradient(
        colors: [color, color.opacity(0.72)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
```

- [ ] **Step 4: Run the focused token test**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignalPaletteUsesRestrainedNativeInstrumentRoles
```

Expected: focused test passes.

- [ ] **Step 5: Run the existing Living Signal tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignal
```

Expected: existing Living Signal layout, motion, status presentation, and decomposition tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/Popover/LivingSignalDesignSystem.swift Sources/NetBar/NetBarDesignSystem.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "style: recalibrate netbar ui tokens"
```

---

### Task 2: Popover Header, Chart, And Footer Instrument Surfaces

**Files:**
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Modify: `Sources/NetBar/Popover/PopoverHeaderView.swift`
- Modify: `Sources/NetBar/Popover/TrafficPulseChartView.swift`
- Modify: `Sources/NetBar/Popover/PopoverFooterView.swift`

**Interfaces:**
- Consumes: `LivingSignalPalette`, `LivingSignalTone.color`, `View.livingSignalPanel`, `View.livingSignalRow`, `View.livingSignalToolbarSurface`.
- Produces: `LivingSignalStatusDot`, chart well styling using `chartWellBackground`, and a footer toolbar using `livingSignalToolbarSurface(padding:)`.

- [ ] **Step 1: Write the failing source-boundary test**

Add this test to the `// MARK: - Popover Decomposition Tests` extension:

```swift
func testPopoverHeaderChartAndFooterUseNativeInstrumentPrimitives() throws {
    let headerSource = try sourceFileContent(
        pathComponents: ["Sources", "NetBar", "Popover", "PopoverHeaderView.swift"]
    )
    let chartSource = try sourceFileContent(
        pathComponents: ["Sources", "NetBar", "Popover", "TrafficPulseChartView.swift"]
    )
    let footerSource = try sourceFileContent(
        pathComponents: ["Sources", "NetBar", "Popover", "PopoverFooterView.swift"]
    )

    XCTAssertTrue(headerSource.contains("struct LivingSignalStatusDot"))
    XCTAssertTrue(headerSource.contains("livingSignalRow"))
    XCTAssertFalse(headerSource.contains("presentation.tone.gradient"))

    XCTAssertTrue(chartSource.contains("chartWellBackground"))
    XCTAssertTrue(chartSource.contains("LivingSignalTone.active.color"))
    XCTAssertTrue(chartSource.contains("LivingSignalTone.uploadHeavy.color"))

    XCTAssertTrue(footerSource.contains("livingSignalToolbarSurface"))
    XCTAssertFalse(footerSource.contains(".livingSignalPanel(tone: monitor.isRunning ? .normal : .attention"))
}
```

- [ ] **Step 2: Run the focused source-boundary test and verify it fails**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPopoverHeaderChartAndFooterUseNativeInstrumentPrimitives
```

Expected: failure because `LivingSignalStatusDot`, `chartWellBackground`, and `livingSignalToolbarSurface` are not used in these files yet.

- [ ] **Step 3: Redesign `PopoverHeaderView`**

In `Sources/NetBar/Popover/PopoverHeaderView.swift`, add this component below `LivingSignalStatusChip`:

```swift
private struct LivingSignalStatusDot: View {
    let tone: LivingSignalTone

    var body: some View {
        ZStack {
            Circle()
                .fill(tone.color.opacity(0.14))
                .frame(width: 30, height: 30)
            Circle()
                .fill(tone.color)
                .frame(width: 10, height: 10)
            Circle()
                .strokeBorder(tone.color.opacity(0.32), lineWidth: 1)
                .frame(width: 18, height: 18)
        }
        .accessibilityHidden(true)
    }
}
```

Then replace the icon block in `PopoverHeaderView.body` with the status dot and replace metric card styling with row surfaces:

```swift
LivingSignalStatusDot(tone: presentation.tone)

VStack(alignment: .leading, spacing: 3) {
    Text(presentation.title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)
    Text(presentation.subtitle)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(2)
}
```

In `LivingSignalSpeedMetric.body`, change the outer modifier from `.livingSignalPanel(tone: tone)` to:

```swift
.livingSignalRow(tone: tone, padding: 8)
```

Keep the header's outer `.livingSignalPanel(tone:isElevated:padding:)`; Task 1 has already made it neutral enough for the redesigned surface model.

- [ ] **Step 4: Redesign the chart well**

In `Sources/NetBar/Popover/TrafficPulseChartView.swift`, add this computed property inside `TrafficPulseChartView`:

```swift
private var chartWellBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.54))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(LivingSignalSurface.borderOpacity), lineWidth: 0.6)
        )
}
```

Then replace the current chart background rectangle:

```swift
RoundedRectangle(cornerRadius: 14, style: .continuous)
    .fill(Color.primary.opacity(0.035))
```

with:

```swift
chartWellBackground
```

Keep these line colors so the chart uses the shared semantic palette:

```swift
color: LivingSignalTone.uploadHeavy.color
color: LivingSignalTone.active.color
```

- [ ] **Step 5: Redesign the footer toolbar**

In `Sources/NetBar/Popover/PopoverFooterView.swift`, replace the last modifier in `FooterView.body`:

```swift
.livingSignalPanel(tone: monitor.isRunning ? .normal : .attention, padding: 8)
```

with:

```swift
.livingSignalToolbarSurface(padding: 8)
```

Keep the running/paused status chip tone unchanged so the left-side state remains recognizable.

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPopoverHeaderChartAndFooterUseNativeInstrumentPrimitives
swift test --filter PreferencesAndPresentationTests/testTrafficPulseChartScale
```

Expected: focused source-boundary and chart-scale tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/Popover/PopoverHeaderView.swift Sources/NetBar/Popover/TrafficPulseChartView.swift Sources/NetBar/Popover/PopoverFooterView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "style: redesign popover instrument chrome"
```

---

### Task 3: Popover Panels And Diagnostic Rows

**Files:**
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Modify: `Sources/NetBar/Popover/InsightStreamView.swift`
- Modify: `Sources/NetBar/Popover/NetworkSummaryPanel.swift`
- Modify: `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`
- Modify: `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`

**Interfaces:**
- Consumes: `View.livingSignalRow(tone:padding:)`, `LivingSignalTone`, `NetBarTone`, `MetricPill`, `CompactMetric`, `ApplicationTrafficMetric`.
- Produces: popover panel files that use shared tone colors instead of direct `.blue`, `.green`, `.mint`, and `.orange` system color literals for traffic semantics.

- [ ] **Step 1: Write the failing source-boundary test**

Add this test to the `// MARK: - Popover Decomposition Tests` extension:

```swift
func testPopoverPanelsAvoidBroadSystemTrafficColorLiterals() throws {
    let panelFiles = [
        ["Sources", "NetBar", "Popover", "InsightStreamView.swift"],
        ["Sources", "NetBar", "Popover", "NetworkSummaryPanel.swift"],
        ["Sources", "NetBar", "Popover", "ApplicationTrafficPanel.swift"],
        ["Sources", "NetBar", "Popover", "InterfaceAndSystemPanel.swift"]
    ]

    for pathComponents in panelFiles {
        let source = try sourceFileContent(pathComponents: pathComponents)
        XCTAssertFalse(source.contains("return .blue"), pathComponents.joined(separator: "/"))
        XCTAssertFalse(source.contains("return .orange"), pathComponents.joined(separator: "/"))
        XCTAssertFalse(source.contains("return .green"), pathComponents.joined(separator: "/"))
        XCTAssertFalse(source.contains("Color.blue"), pathComponents.joined(separator: "/"))
        XCTAssertFalse(source.contains("Color.orange"), pathComponents.joined(separator: "/"))
        XCTAssertFalse(source.contains("Color.mint"), pathComponents.joined(separator: "/"))
    }
}
```

- [ ] **Step 2: Run the focused source-boundary test and verify it fails**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPopoverPanelsAvoidBroadSystemTrafficColorLiterals
```

Expected: failure because current panel files still use direct system color literals for traffic and milestone styling.

- [ ] **Step 3: Convert panel row surfaces**

In `Sources/NetBar/Popover/InsightStreamView.swift`, change the empty insight row and insight card row modifiers from `.livingSignalPanel(...)` to row surfaces:

```swift
.livingSignalRow(tone: .idle, padding: 9)
```

and:

```swift
.livingSignalRow(tone: .attention, padding: 9)
```

Keep `NetworkIntelligenceStatusCard` as `.livingSignalPanel(...)` because it is the main status strip.

In `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`, change these row-like wrappers to row surfaces:

```swift
.livingSignalRow(tone: livingTone, padding: 9)
.livingSignalRow(tone: .neutral, padding: 8)
.livingSignalRow(tone: actionTitle == nil ? .idle : .attention, padding: 12)
.livingSignalRow(tone: rowTone, padding: 6)
```

In `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`, change row-like wrappers to:

```swift
.livingSignalRow(tone: hasKnownInterfaces ? .idle : .attention, padding: 12)
.livingSignalRow(tone: interface.isPrimary ? .active : .neutral, padding: 10)
.livingSignalRow(tone: .neutral, padding: 10)
```

- [ ] **Step 4: Replace traffic color literals in shared metric components**

In `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`, update `ApplicationTrafficMetric.tint` to:

```swift
var tint: Color {
    switch kind {
    case .download:
        return LivingSignalTone.active.color
    case .upload:
        return LivingSignalTone.uploadHeavy.color
    case .memory:
        return LivingSignalTone.neutral.color
    case .cpu:
        return LivingSignalTone.critical.color
    }
}
```

Update `AttributionRoleBadge.tint` to:

```swift
private var tint: Color {
    switch role {
    case .application:
        return LivingSignalTone.neutral.color
    case .proxyOrVPN:
        return LivingSignalTone.attention.color
    case .helper:
        return LivingSignalTone.active.color
    case .systemService:
        return LivingSignalTone.neutral.color.opacity(0.82)
    }
}
```

Update `AppTrafficAttributionCard.tint` to:

```swift
private var tint: Color {
    switch summary.status {
    case .idle:
        return LivingSignalTone.neutral.color
    case .covered:
        return LivingSignalTone.normal.color
    case .partial:
        return LivingSignalTone.attention.color
    }
}
```

In `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`, replace traffic metric calls:

```swift
MetricPill(symbol: "arrow.down", value: ByteFormat.speed(interface.downloadBytesPerSecond), tint: LivingSignalTone.active.color)
MetricPill(symbol: "arrow.up", value: ByteFormat.speed(interface.uploadBytesPerSecond), tint: LivingSignalTone.uploadHeavy.color)
```

Replace the primary interface icon foreground:

```swift
.foregroundStyle(interface.isPrimary ? LivingSignalTone.active.color : LivingSignalTone.neutral.color)
```

Replace the CPU bar fill:

```swift
.fill(LivingSignalTone.attention.color.opacity(0.45))
```

- [ ] **Step 5: Replace summary and history color literals**

In `Sources/NetBar/Popover/NetworkSummaryPanel.swift`, change `CharacterPlaybackMilestone.accent` to:

```swift
var accent: Color {
    switch self {
    case .spark:
        return LivingSignalTone.active.color
    case .volt:
        return LivingSignalTone.active.color.opacity(0.9)
    case .crown:
        return LivingSignalTone.attention.color
    case .legend:
        return LivingSignalTone.uploadHeavy.color
    }
}
```

Change `backgroundGradient` to use restrained low-opacity stops:

```swift
var backgroundGradient: LinearGradient {
    LinearGradient(
        colors: [accent.opacity(0.11), accent.opacity(0.035)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
```

Change `strokeGradient` to:

```swift
var strokeGradient: LinearGradient {
    LinearGradient(
        colors: [accent.opacity(0.84), accent.opacity(0.36)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
```

Replace metric calls in `DailyApplicationUsageRow` and `SevenDaySummaryRow`:

```swift
MetricPill(symbol: "arrow.down", value: ByteFormat.bytes(application.downloadBytes), tint: LivingSignalTone.active.color, fixedWidth: 92)
MetricPill(symbol: "arrow.up", value: ByteFormat.bytes(application.uploadBytes), tint: LivingSignalTone.uploadHeavy.color, fixedWidth: 92)
```

and:

```swift
MetricPill(symbol: "arrow.down", value: ByteFormat.bytes(summary.downloadBytes), tint: LivingSignalTone.active.color)
MetricPill(symbol: "arrow.up", value: ByteFormat.bytes(summary.uploadBytes), tint: LivingSignalTone.uploadHeavy.color)
```

Change `DailySummaryCell`, `DailyApplicationUsageRow`, `SevenDaySummaryRow`, and `SummaryCell` wrappers from `.netBarCard(...)` to `.livingSignalRow(...)`:

```swift
.livingSignalRow(tone: tone == .upload ? .uploadHeavy : tone == .warning ? .attention : tone == .danger ? .critical : .neutral, padding: 9)
```

For `DailyApplicationUsageRow` and `SevenDaySummaryRow`, use:

```swift
.livingSignalRow(tone: .neutral, padding: 7)
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPopoverPanelsAvoidBroadSystemTrafficColorLiterals
swift test --filter PreferencesAndPresentationTests/testApplicationTraffic
```

Expected: source-boundary tests pass and application traffic presentation tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/Popover/InsightStreamView.swift Sources/NetBar/Popover/NetworkSummaryPanel.swift Sources/NetBar/Popover/ApplicationTrafficPanel.swift Sources/NetBar/Popover/InterfaceAndSystemPanel.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "style: unify popover panel surfaces"
```

---

### Task 4: Preferences Settings-Center Redesign

**Files:**
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesWindowController.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesComponents.swift`

**Interfaces:**
- Consumes: `PreferencesView`, `PreferencesTabBar`, `PreferenceSection`, `CollapsiblePreferenceSection`, `LivingSignalStatusChip`, `View.livingSignalPanelBackground`, `View.livingSignalRow`, `View.livingSignalSelectedSurface`.
- Produces: `PreferencesHeader` replacing the hero-style header, neutral grouped preference sections, and tab selection using `livingSignalSelectedSurface(cornerRadius:)`.

- [ ] **Step 1: Replace the existing preferences source tests**

In `Tests/NetBarTests/PreferencesAndPresentationTests.swift`, replace `testPreferencesComponentsUseLivingSignalPanelStyles` with:

```swift
func testPreferencesComponentsUseNativeInstrumentHeaderAndSections() throws {
    let source = try sourceFileContent(
        pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesComponents.swift"]
    )

    XCTAssertTrue(source.contains("struct PreferencesHeader"))
    XCTAssertTrue(source.contains("livingSignalRow"))
    XCTAssertTrue(source.contains("NetBar 偏好设置"))
    XCTAssertFalse(source.contains("struct PreferencesHeroHeader"))
    XCTAssertFalse(source.contains("NetBar 信号控制台"))
    XCTAssertFalse(source.contains("LivingSignalTone.active.gradient"))
}
```

Replace `testPreferencesWindowUsesLivingSignalPanelBackground` with:

```swift
func testPreferencesWindowUsesNativeInstrumentBackgroundAndTabs() throws {
    let source = try sourceFileContent(
        pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesWindowController.swift"]
    )

    XCTAssertTrue(source.contains("PreferencesHeader(appPreferences: appPreferences, updater: updater)"))
    XCTAssertTrue(source.contains("livingSignalPanelBackground()"))
    XCTAssertTrue(source.contains("livingSignalSelectedSurface"))
    XCTAssertFalse(source.contains("PreferencesHeroHeader"))
}
```

- [ ] **Step 2: Run the focused preferences tests and verify they fail**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPreferencesComponentsUseNativeInstrumentHeaderAndSections
swift test --filter PreferencesAndPresentationTests/testPreferencesWindowUsesNativeInstrumentBackgroundAndTabs
```

Expected: failure because the source still contains `PreferencesHeroHeader`, the old title, active gradients, and tab backgrounds without `livingSignalSelectedSurface`.

- [ ] **Step 3: Replace the preferences hero with a compact header**

In `Sources/NetBar/Preferences/PreferencesComponents.swift`, rename `PreferencesHeroHeader` to `PreferencesHeader` and replace its body with:

```swift
struct PreferencesHeader: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LivingSignalTone.active.color)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LivingSignalTone.active.color.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(LivingSignalTone.active.color.opacity(0.20), lineWidth: 0.6)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(appPreferences.text("NetBar 偏好设置", "NetBar Preferences"))
                    .font(.system(size: 16, weight: .semibold))
                Text(appPreferences.text(
                    "调整菜单栏显示、详情面板、应用流量和更新策略。",
                    "Tune menu bar display, detail panels, app traffic, and update behavior."
                ))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer()

            LivingSignalStatusChip(text: updater.currentVersionText, tone: .neutral)
        }
        .livingSignalToolbarSurface(padding: 12)
    }
}
```

Update `PreferenceSection` and `CollapsiblePreferenceSection` content wrappers from `.livingSignalPanel(tone: .neutral, padding: 12)` to:

```swift
.livingSignalRow(tone: .neutral, padding: 12)
```

- [ ] **Step 4: Update preferences root and tab selected state**

In `Sources/NetBar/Preferences/PreferencesWindowController.swift`, replace:

```swift
PreferencesHeroHeader(appPreferences: appPreferences, updater: updater)
```

with:

```swift
PreferencesHeader(appPreferences: appPreferences, updater: updater)
```

In `PreferencesTabBar`, replace the selected background and overlay block with this compact selected-state surface:

```swift
.background(
    Group {
        if selectedTab == tab {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)
        } else {
            Color.clear
        }
    }
)
.modifier(SelectedTabSurface(isSelected: selectedTab == tab))
```

Add this helper below `PreferencesTabBar`:

```swift
private struct SelectedTabSurface: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.livingSignalSelectedSurface(cornerRadius: 8)
        } else {
            content
        }
    }
}
```

Keep the existing manual tab structure and `.buttonStyle(.plain)`.

- [ ] **Step 5: Run focused preferences tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPreferencesComponentsUseNativeInstrumentHeaderAndSections
swift test --filter PreferencesAndPresentationTests/testPreferencesWindowUsesNativeInstrumentBackgroundAndTabs
swift test --filter PreferencesAndPresentationTests/testPreferencesWindowUsesLightweightManualTabs
```

Expected: all three focused preferences tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/Preferences/PreferencesWindowController.swift Sources/NetBar/Preferences/PreferencesComponents.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "style: redesign preferences surfaces"
```

---

### Task 5: Full Verification And Visual QA

**Files:**
- Review: all files changed by Tasks 1-4.
- No source files should be modified in this task unless verification exposes a concrete compile, test, or visual defect.

**Interfaces:**
- Consumes: all changes from Tasks 1-4.
- Produces: verified Swift tests, verified app bundle, and a final review of the UI redesign diff.

- [ ] **Step 1: Run the full test suite**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Build the app bundle through the project script**

Run:

```bash
./Scripts/build-app.sh
```

Expected: `build/NetBar.app` is assembled by the script with copied `Resources/` content.

- [ ] **Step 3: Verify the app bundle**

Run:

```bash
./Scripts/verify-release-app.sh build/NetBar.app
```

Expected: verification reports a valid executable, expected architecture shape, and acceptable local signing shape.

- [ ] **Step 4: Review the final diff for scope control**

Run:

```bash
git diff --stat HEAD~4..HEAD
git diff HEAD~4..HEAD -- Sources/NetBar/Popover Sources/NetBar/Preferences Sources/NetBar/NetBarDesignSystem.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
```

Expected: changes are limited to shared UI tokens, popover UI, preferences UI, and focused tests. No sampling, update, notification, history, pet, packaging, entitlement, or RunCat resource files are changed.

- [ ] **Step 5: Manual visual QA**

Open the app through LaunchServices from the user environment:

```bash
open build/NetBar.app
```

Expected checks:

- Details popover and preferences window look like the same product.
- Light appearance keeps surfaces neutral and readable.
- Dark appearance keeps borders and text readable.
- Chinese strings fit inside header, tabs, chips, and rows.
- English strings fit inside header, tabs, chips, and rows.
- Details popover idle state is quiet.
- Active state has a clear teal signal.
- Upload-heavy state uses coral only in status, chip, and chart line.
- Warning or anomaly state uses amber/red without broad pastel panel washes.
- Preferences window behaves at minimum size and a wider resized size.

- [ ] **Step 6: Commit any verification fix or record clean verification**

If Step 1-4 required a code fix, commit it:

```bash
git add Sources/NetBar Tests/NetBarTests
git commit -m "fix: polish ui redesign verification"
```

If Step 1-4 passed without further source changes, do not create an empty commit. Record the successful commands in the final handoff.

