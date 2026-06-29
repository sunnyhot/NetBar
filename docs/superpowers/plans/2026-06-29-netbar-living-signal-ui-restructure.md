# NetBar Living Signal UI Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild NetBar's default details window, preferences, and menu bar effects into the approved Living Signal / balanced pulse UI while preserving the current monitoring engine.

**Architecture:** Add focused Living Signal primitives first, then decompose the current large `NetworkPopoverView.swift` into small popover files under `Sources/NetBar/Popover/`. Keep `NetworkMonitor`, readers, history storage, preferences persistence, and update flow unchanged; UI consumes existing published models and presentation helpers.

**Tech Stack:** Swift 5 language mode, SwiftPM `swift-tools-version: 6.0`, macOS 13+, AppKit + SwiftUI + Combine + CoreGraphics, no third-party dependencies.

## Global Constraints

- Pure Swift and system frameworks only.
- macOS 13+.
- No packet capture, packet parsing, visited-domain display, or network payload inspection.
- No external dependencies.
- No rewrite of the network sampling engine.
- No separate full theme system.
- User-visible strings added during implementation must use Chinese and English variants through `appPreferences.text(...)` or `AppLanguage.text(...)`.
- Respect macOS Reduce Motion for recurring pulse, scan, and breathing effects.
- Keep menu bar rendering cache-friendly through `StatusBarRenderSignature` and `StatusBarRenderedImageCache`.
- Run `swift test` before completion.

---

## File Structure

Create:

- `Sources/NetBar/Popover/LivingSignalDesignSystem.swift`
  - Living Signal tones, layout constants, shared panel/chip/icon styles, reduced-motion policy, and status presentation helpers.
- `Sources/NetBar/Popover/NetworkPopoverView.swift`
  - New root details-window composition layer. It receives existing dependencies and arranges the popover sections.
- `Sources/NetBar/Popover/PopoverHeaderView.swift`
  - Signal header, realtime total speed, upload/download tiles, interface label, and status chip.
- `Sources/NetBar/Popover/TrafficPulseChartView.swift`
  - Download/upload trend chart, scan effect, legend, and chart math helpers.
- `Sources/NetBar/Popover/InsightStreamView.swift`
  - Network intelligence status and insight stream cards.
- `Sources/NetBar/Popover/NetworkSummaryPanel.swift`
  - Today summary, history ledger, seven-day summary, and top application summary panels.
- `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`
  - Application traffic controls, attribution card, app rows, badges, and lazy icon display.
- `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`
  - Interface rows, empty interface state, and system resource panel.
- `Sources/NetBar/Popover/PopoverFooterView.swift`
  - Footer refresh/preferences/quit controls and status timestamps.

Modify:

- `Sources/NetBar/NetworkPopoverView.swift`
  - Remove after the new root is in place, or replace it with a compatibility shim if SwiftPM source discovery and file moves are done in separate commits.
- `Sources/NetBar/DetailsWindowController.swift`
  - Use Living Signal width constants.
- `Sources/NetBar/NetBarDesignSystem.swift`
  - Keep general compatibility primitives and route shared panel styles to Living Signal where useful.
- `Sources/NetBar/Preferences/PreferencesComponents.swift`
  - Refresh shared preference sections and hero with Living Signal components.
- `Sources/NetBar/Preferences/PreferencesWindowController.swift`
  - Keep tab structure and apply updated panel background.
- `Sources/NetBar/StatusBarStyle.swift`
  - Add bounded pulse render policy and signature field.
- `Sources/NetBar/StatusBarController.swift`
  - Pass existing snapshot/context into updated signature and renderer paths without changing sampling behavior.
- `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
  - Add focused tests for Living Signal helpers, layout sizing, file decomposition, chart math, reduced motion, and status bar signature behavior.

Do not modify:

- `NetworkMonitor.swift` sampling behavior.
- `ApplicationTrafficReader.swift`, `NetworkStatsReader.swift`, `SystemResourceReader.swift`, `ApplicationResourceReader.swift`.
- `AppUpdater.swift`, release scripts, resources, or entitlements.

---

### Task 1: Living Signal Primitives

**Files:**
- Create: `Sources/NetBar/Popover/LivingSignalDesignSystem.swift`
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Produces: `LivingSignalTone`, `LivingSignalMotionPolicy`, `LivingSignalLayout`, `LivingSignalStatusPresentation`, `View.livingSignalPanel(...)`, `View.livingSignalPanelBackground()`
- Consumes: `NetworkSnapshot`, `NetworkAnomalyEvent`, `AppLanguage`, `ByteFormat`

- [ ] **Step 1: Write failing tests for tone, status, motion, and width constants**

Add this extension near the other presentation tests in `Tests/NetBarTests/PreferencesAndPresentationTests.swift`:

```swift
// MARK: - Living Signal Design System Tests

extension PreferencesAndPresentationTests {
    func testLivingSignalLayoutUsesApprovedPopoverWidth() {
        XCTAssertEqual(LivingSignalLayout.minimumPopoverWidth, 480)
        XCTAssertEqual(LivingSignalLayout.preferredPopoverWidth, 500)
        XCTAssertEqual(LivingSignalLayout.maximumPopoverWidth, 520)
        XCTAssertGreaterThan(LivingSignalLayout.chartHeight, 132)
    }

    func testLivingSignalMotionPolicyDisablesLoopingEffectsWhenReduceMotionIsOn() {
        let reduced = LivingSignalMotionPolicy.make(
            reduceMotion: true,
            windowVisible: true,
            isActive: true
        )

        XCTAssertFalse(reduced.allowsLoopingEffects)
        XCTAssertFalse(reduced.allowsScan)
        XCTAssertEqual(reduced.pulseScale, 1)

        let active = LivingSignalMotionPolicy.make(
            reduceMotion: false,
            windowVisible: true,
            isActive: true
        )

        XCTAssertTrue(active.allowsLoopingEffects)
        XCTAssertTrue(active.allowsScan)
        XCTAssertGreaterThan(active.pulseScale, 1)
    }

    func testLivingSignalStatusPresentationClassifiesIdleActiveUploadAndAnomaly() {
        let idle = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 0, upload: 0),
            latestEvent: nil,
            language: .english
        )
        XCTAssertEqual(idle.tone, .idle)
        XCTAssertEqual(idle.title, "Idle")

        let active = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 420_000, upload: 60_000),
            latestEvent: nil,
            language: .english
        )
        XCTAssertEqual(active.tone, .active)
        XCTAssertEqual(active.title, "Active")

        let uploadHeavy = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 80_000, upload: 900_000),
            latestEvent: nil,
            language: .english
        )
        XCTAssertEqual(uploadHeavy.tone, .uploadHeavy)
        XCTAssertEqual(uploadHeavy.title, "Upload Heavy")

        let event = NetworkAnomalyEvent(
            kind: .highTraffic,
            severity: .critical,
            title: "Traffic surge",
            message: "Traffic stayed high.",
            timestamp: Date(timeIntervalSince1970: 20),
            cooldownKey: "surge"
        )
        let anomaly = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 0, upload: 0),
            latestEvent: event,
            language: .english
        )
        XCTAssertEqual(anomaly.tone, .critical)
        XCTAssertEqual(anomaly.title, "Traffic surge")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignal
```

Expected: FAIL with errors mentioning `LivingSignalLayout`, `LivingSignalMotionPolicy`, or `LivingSignalStatusPresentation` not found.

- [ ] **Step 3: Add the Living Signal design primitives**

Create `Sources/NetBar/Popover/LivingSignalDesignSystem.swift` with:

```swift
import SwiftUI

enum LivingSignalTone: String, CaseIterable, Equatable {
    case idle
    case normal
    case active
    case uploadHeavy
    case attention
    case critical
    case neutral

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .normal:
            return .green
        case .active:
            return Color(red: 0.31, green: 0.86, blue: 0.77)
        case .uploadHeavy:
            return Color(red: 1.0, green: 0.48, blue: 0.4)
        case .attention:
            return .orange
        case .critical:
            return .red
        case .neutral:
            return .secondary
        }
    }

    var softColor: Color {
        color.opacity(0.14)
    }

    var gradient: LinearGradient {
        switch self {
        case .active:
            return LinearGradient(
                colors: [Color(red: 0.31, green: 0.86, blue: 0.77), Color(red: 0.95, green: 0.78, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .uploadHeavy:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.48, blue: 0.4), Color(red: 0.95, green: 0.78, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .critical:
            return LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .attention:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .normal:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .idle, .neutral:
            return LinearGradient(
                colors: [Color.secondary.opacity(0.38), Color.secondary.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

enum LivingSignalLayout {
    static let minimumPopoverWidth: CGFloat = 480
    static let preferredPopoverWidth: CGFloat = 500
    static let maximumPopoverWidth: CGFloat = 520
    static let minimumPopoverHeight: CGFloat = 500
    static let preferredPopoverHeight: CGFloat = 720
    static let panelCornerRadius: CGFloat = 12
    static let elevatedPanelCornerRadius: CGFloat = 16
    static let rowCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 18
    static let verticalSectionSpacing: CGFloat = 14
    static let chartHeight: CGFloat = 156
    static let iconTileSize: CGFloat = 34
}

struct LivingSignalMotionPolicy: Equatable {
    let allowsLoopingEffects: Bool
    let allowsScan: Bool
    let pulseScale: CGFloat
    let pulseOpacity: Double
    let scanDuration: Double

    static func make(
        reduceMotion: Bool,
        windowVisible: Bool,
        isActive: Bool
    ) -> LivingSignalMotionPolicy {
        guard !reduceMotion, windowVisible, isActive else {
            return LivingSignalMotionPolicy(
                allowsLoopingEffects: false,
                allowsScan: false,
                pulseScale: 1,
                pulseOpacity: 0,
                scanDuration: 0
            )
        }

        return LivingSignalMotionPolicy(
            allowsLoopingEffects: true,
            allowsScan: true,
            pulseScale: 1.035,
            pulseOpacity: 0.18,
            scanDuration: 2.6
        )
    }
}

struct LivingSignalStatusPresentation: Equatable {
    let title: String
    let subtitle: String
    let tone: LivingSignalTone
    let symbolName: String
    let totalSpeed: String
    let interfaceName: String

    static func make(
        snapshot: NetworkSnapshot,
        latestEvent: NetworkAnomalyEvent?,
        language: AppLanguage
    ) -> LivingSignalStatusPresentation {
        let primaryInterface = snapshot.interfaces.first(where: \.isPrimary)?.displayName
            ?? snapshot.interfaces.first?.displayName
            ?? language.text("无接口", "No Interface")
        let totalSpeed = ByteFormat.speed(snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond)

        if let latestEvent {
            let tone: LivingSignalTone = latestEvent.severity == .critical ? .critical : .attention
            return LivingSignalStatusPresentation(
                title: latestEvent.title,
                subtitle: latestEvent.message,
                tone: tone,
                symbolName: latestEvent.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill",
                totalSpeed: totalSpeed,
                interfaceName: primaryInterface
            )
        }

        if snapshot.downloadBytesPerSecond < 1, snapshot.uploadBytesPerSecond < 1 {
            return LivingSignalStatusPresentation(
                title: language.text("空闲", "Idle"),
                subtitle: language.text("等待新的网络活动", "Waiting for network activity"),
                tone: .idle,
                symbolName: "pause.circle.fill",
                totalSpeed: totalSpeed,
                interfaceName: primaryInterface
            )
        }

        if snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond * 1.6,
           snapshot.uploadBytesPerSecond > 100_000 {
            return LivingSignalStatusPresentation(
                title: language.text("上传占优", "Upload Heavy"),
                subtitle: language.text("上传速率高于下载", "Upload is leading download"),
                tone: .uploadHeavy,
                symbolName: "arrow.up.circle.fill",
                totalSpeed: totalSpeed,
                interfaceName: primaryInterface
            )
        }

        return LivingSignalStatusPresentation(
            title: language.text("活跃", "Active"),
            subtitle: language.text("实时信号正在流动", "Realtime signal is flowing"),
            tone: .active,
            symbolName: "waveform.path.ecg",
            totalSpeed: totalSpeed,
            interfaceName: primaryInterface
        )
    }
}

struct LivingSignalPanelModifier: ViewModifier {
    var tone: LivingSignalTone = .neutral
    var isElevated = false
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        let radius = isElevated ? LivingSignalLayout.elevatedPanelCornerRadius : LivingSignalLayout.panelCornerRadius

        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tone.softColor.opacity(isElevated ? 0.85 : 0.45))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tone.color.opacity(isElevated ? 0.2 : 0.11), lineWidth: 0.7)
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

    func livingSignalPanelBackground() -> some View {
        background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        Color(red: 0.31, green: 0.86, blue: 0.77).opacity(0.07),
                        Color(red: 1.0, green: 0.48, blue: 0.4).opacity(0.035),
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

- [ ] **Step 4: Run the focused tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignal
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/NetBar/Popover/LivingSignalDesignSystem.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add living signal design primitives"
```

---

### Task 2: Details Window Width and Root Popover Shell

**Files:**
- Create: `Sources/NetBar/Popover/NetworkPopoverView.swift`
- Modify: `Sources/NetBar/NetworkPopoverView.swift`
- Modify: `Sources/NetBar/DetailsWindowController.swift`
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: `LivingSignalLayout`, `View.livingSignalPanelBackground()`
- Produces: a root `NetworkPopoverView` in `Sources/NetBar/Popover/NetworkPopoverView.swift` with the same public initializer properties as the current view.

- [ ] **Step 1: Write failing tests for approved width and small-screen fitting**

Update existing details-window layout tests so the approved width is explicit:

```swift
func testDetailsWindowLayoutUsesLivingSignalApprovedWidthWhenSpaceAllows() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1200, height: 900)
    let anchorFrame = NSRect(x: 590, y: 880, width: 20, height: 20)

    let frame = DetailsWindowLayout.frame(
        forWindowSize: NSSize(
            width: LivingSignalLayout.preferredPopoverWidth,
            height: LivingSignalLayout.preferredPopoverHeight
        ),
        minimumSize: NSSize(
            width: LivingSignalLayout.minimumPopoverWidth,
            height: LivingSignalLayout.minimumPopoverHeight
        ),
        visibleFrame: visibleFrame,
        anchorFrame: anchorFrame,
        padding: 10
    )

    XCTAssertEqual(frame.width, LivingSignalLayout.preferredPopoverWidth)
    XCTAssertEqual(frame.maxY, anchorFrame.minY, accuracy: 0.5)
}

func testDetailsWindowLayoutShrinksLivingSignalWidthForSmallVisibleFrame() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 470, height: 700)
    let frame = DetailsWindowLayout.frame(
        forWindowSize: NSSize(
            width: LivingSignalLayout.preferredPopoverWidth,
            height: LivingSignalLayout.preferredPopoverHeight
        ),
        minimumSize: NSSize(
            width: LivingSignalLayout.minimumPopoverWidth,
            height: LivingSignalLayout.minimumPopoverHeight
        ),
        visibleFrame: visibleFrame,
        anchorFrame: nil,
        padding: 10
    )

    XCTAssertLessThanOrEqual(frame.width, 450)
    XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX + 10)
    XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX - 10)
}
```

Keep the existing anchored height tests, but replace hardcoded `440` sizes with `LivingSignalLayout.preferredPopoverWidth` where they assert the details window's default width.

- [ ] **Step 2: Run tests to verify the current hardcoded width fails the new expectations**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testDetailsWindowLayout
```

Expected: FAIL on width-related assertions because `DetailsWindowController` still uses 440 px defaults.

- [ ] **Step 3: Move the root popover shell to the new folder**

Create `Sources/NetBar/Popover/NetworkPopoverView.swift` by moving the current root `NetworkPopoverView` body from `Sources/NetBar/NetworkPopoverView.swift`, then reduce the old file to this compatibility shim for one commit:

```swift
// This file is intentionally kept as a temporary compatibility marker during
// the Living Signal popover split. The real NetworkPopoverView lives in
// Sources/NetBar/Popover/NetworkPopoverView.swift.
```

The new root file should keep this public shape:

```swift
import SwiftUI

struct NetworkPopoverView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    let openPreferences: () -> Void
    @State private var appSearchText = ""
    @State private var historyWindow: TrafficHistoryWindow = .seconds90

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(snapshot: monitor.snapshot, appPreferences: appPreferences)
                .padding(.horizontal, LivingSignalLayout.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 14)
                .layoutPriority(1)

            Divider().opacity(0.5)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: LivingSignalLayout.verticalSectionSpacing) {
                    existingContent
                }
                .padding(.horizontal, LivingSignalLayout.horizontalPadding)
                .padding(.bottom, 16)
            }
            .frame(minHeight: 0)

            Divider().opacity(0.5)

            FooterView(monitor: monitor, appPreferences: appPreferences, openPreferences: openPreferences)
                .padding(.horizontal, LivingSignalLayout.horizontalPadding)
                .padding(.vertical, 11)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(
            minWidth: LivingSignalLayout.minimumPopoverWidth,
            idealWidth: LivingSignalLayout.preferredPopoverWidth,
            maxWidth: LivingSignalLayout.preferredPopoverWidth,
            minHeight: LivingSignalLayout.minimumPopoverHeight,
            idealHeight: LivingSignalLayout.preferredPopoverHeight,
            maxHeight: .infinity
        )
        .livingSignalPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }

    @ViewBuilder
    private var existingContent: some View {
        NetworkIntelligenceStatusCard(
            presentation: NetworkIntelligenceStatusPresentation(
                event: monitor.intelligenceSummary.latestEvent,
                language: appPreferences.resolvedLanguage
            ),
            appPreferences: appPreferences,
            openPreferences: openPreferences
        )
        .padding(.top, 16)

        if appPreferences.networkIntelligenceSettings.isInsightStreamEnabled {
            insightStreamSection
        }

        if !appPreferences.hasCompletedOnboarding {
            FirstLaunchGuide(
                appPreferences: appPreferences,
                openPreferences: openPreferences,
                completeOnboarding: appPreferences.completeOnboarding
            )
        } else {
            let chartPresentation = TrafficHistoryWindowPresentation.make(
                points: monitor.recentHistory,
                window: historyWindow
            )
            TrafficChart(
                points: chartPresentation.points,
                selectedWindow: $historyWindow,
                appPreferences: appPreferences
            )
            .frame(height: LivingSignalLayout.chartHeight)
        }

        TodayNetworkSummary(
            summary: monitor.intelligenceSummary,
            appPreferences: appPreferences,
            customCharacterStore: customCharacterStore
        )

        if appPreferences.networkIntelligenceSettings.isHistoryTrackingEnabled {
            historyLedgerSection
        }

        SummaryGrid(snapshot: monitor.snapshot, appPreferences: appPreferences)

        ApplicationTopSection(
            realtimeApplications: monitor.intelligenceSummary.realtimeTopApplications,
            todayApplications: monitor.intelligenceSummary.todayTopApplications,
            appPreferences: appPreferences
        )

        ApplicationTrafficList(
            snapshot: monitor.snapshot,
            appTraffic: monitor.appTraffic,
            preferences: appPreferences,
            searchText: $appSearchText,
            retry: monitor.refreshApplicationTraffic
        )

        SevenDaySummarySection(
            summaries: monitor.intelligenceSummary.recentDays,
            appPreferences: appPreferences
        )

        InterfaceList(
            interfaces: monitor.snapshot.interfaces,
            appPreferences: appPreferences,
            refresh: monitor.refresh
        )
    }
}
```

Move the current private view definitions below the new root into the same new file for this task. Later tasks split them into focused files.

- [ ] **Step 4: Update details window sizing constants**

In `Sources/NetBar/DetailsWindowController.swift`, change the stored sizes to:

```swift
private let defaultWindowSize = NSSize(
    width: LivingSignalLayout.preferredPopoverWidth,
    height: LivingSignalLayout.preferredPopoverHeight
)
private let minimumWindowSize = NSSize(
    width: LivingSignalLayout.minimumPopoverWidth,
    height: LivingSignalLayout.minimumPopoverHeight
)
```

- [ ] **Step 5: Run focused layout tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testDetailsWindowLayout
```

Expected: PASS.

- [ ] **Step 6: Run the full test target after the source move**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/NetBar/NetworkPopoverView.swift Sources/NetBar/Popover/NetworkPopoverView.swift Sources/NetBar/DetailsWindowController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor: move popover shell to living signal folder"
```

---

### Task 3: Signal Header and Traffic Pulse Chart

**Files:**
- Create: `Sources/NetBar/Popover/PopoverHeaderView.swift`
- Create: `Sources/NetBar/Popover/TrafficPulseChartView.swift`
- Modify: `Sources/NetBar/Popover/NetworkPopoverView.swift`
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: `LivingSignalStatusPresentation`, `LivingSignalMotionPolicy`, `TrafficHistoryWindowPresentation`
- Produces: `PopoverHeaderView`, `TrafficPulseChartView`, `TrafficPulseChartScale.normalizedValues(_:)`

- [ ] **Step 1: Write failing chart math tests**

Add:

```swift
// MARK: - Traffic Pulse Chart Tests

extension PreferencesAndPresentationTests {
    func testTrafficPulseChartScaleNormalizesValuesAgainstLargestPoint() {
        XCTAssertEqual(
            TrafficPulseChartScale.normalizedValues([0, 50, 100]),
            [0, 0.5, 1.0]
        )
    }

    func testTrafficPulseChartScaleHandlesEmptyAndAllZeroValues() {
        XCTAssertEqual(TrafficPulseChartScale.normalizedValues([]), [])
        XCTAssertEqual(TrafficPulseChartScale.normalizedValues([0, 0]), [0, 0])
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testTrafficPulseChartScale
```

Expected: FAIL because `TrafficPulseChartScale` does not exist.

- [ ] **Step 3: Create the Living Signal header view**

Create `Sources/NetBar/Popover/PopoverHeaderView.swift`:

```swift
import SwiftUI

struct PopoverHeaderView: View {
    let presentation: LivingSignalStatusPresentation
    let snapshot: NetworkSnapshot
    @ObservedObject var appPreferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        let policy = LivingSignalMotionPolicy.make(
            reduceMotion: reduceMotion,
            windowVisible: true,
            isActive: presentation.tone != .idle
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: LivingSignalLayout.iconTileSize, height: LivingSignalLayout.iconTileSize)
                    .background(presentation.tone.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(
                        color: presentation.tone.color.opacity(policy.pulseOpacity),
                        radius: isPulsing ? 12 : 4,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isPulsing ? policy.pulseScale : 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(presentation.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                LivingSignalStatusChip(text: presentation.totalSpeed, tone: presentation.tone)
            }

            HStack(spacing: 8) {
                LivingSignalSpeedMetric(
                    title: appPreferences.text("下载", "Download"),
                    value: ByteFormat.speed(snapshot.downloadBytesPerSecond),
                    symbolName: "arrow.down",
                    tone: .active
                )
                LivingSignalSpeedMetric(
                    title: appPreferences.text("上传", "Upload"),
                    value: ByteFormat.speed(snapshot.uploadBytesPerSecond),
                    symbolName: "arrow.up",
                    tone: snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond ? .uploadHeavy : .neutral
                )
                LivingSignalSpeedMetric(
                    title: appPreferences.text("接口", "Interface"),
                    value: presentation.interfaceName,
                    symbolName: "antenna.radiowaves.left.and.right",
                    tone: .neutral
                )
            }
        }
        .livingSignalPanel(tone: presentation.tone, isElevated: true, padding: 14)
        .onAppear {
            guard policy.allowsLoopingEffects else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

struct LivingSignalStatusChip: View {
    let text: String
    let tone: LivingSignalTone

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.softColor, in: Capsule())
            .overlay(Capsule().strokeBorder(tone.color.opacity(0.22), lineWidth: 0.7))
    }
}

private struct LivingSignalSpeedMetric: View {
    let title: String
    let value: String
    let symbolName: String
    let tone: LivingSignalTone

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tone.color)
                .frame(width: 18, height: 18)
                .background(tone.softColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .livingSignalPanel(tone: tone)
    }
}
```

- [ ] **Step 4: Create the traffic pulse chart**

Create `Sources/NetBar/Popover/TrafficPulseChartView.swift`:

```swift
import SwiftUI

enum TrafficPulseChartScale {
    static func normalizedValues(_ values: [Double]) -> [Double] {
        guard let maxValue = values.max(), maxValue > 0 else {
            return values.map { _ in 0 }
        }
        return values.map { $0 / maxValue }
    }
}

struct TrafficPulseChartView: View {
    let presentation: TrafficHistoryWindowPresentationModel
    @Binding var selectedWindow: TrafficHistoryWindow
    @ObservedObject var appPreferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanOffset: CGFloat = -1

    var body: some View {
        let isActive = presentation.peakDownloadBytesPerSecond > 0 || presentation.peakUploadBytesPerSecond > 0
        let policy = LivingSignalMotionPolicy.make(
            reduceMotion: reduceMotion,
            windowVisible: true,
            isActive: isActive
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appPreferences.text("实时信号", "Realtime Signal"))
                        .font(.system(size: 13, weight: .bold))
                    Text(appPreferences.text(
                        "最近 \(selectedWindow.title(language: appPreferences.resolvedLanguage)) 下载 / 上传",
                        "Last \(selectedWindow.title(language: appPreferences.resolvedLanguage)) down / up"
                    ))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Picker("", selection: $selectedWindow) {
                    ForEach(TrafficHistoryWindow.allCases) { window in
                        Text(window.title(language: appPreferences.resolvedLanguage)).tag(window)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.035))

                    TrafficPulseGrid()

                    if policy.allowsScan {
                        LinearGradient(
                            colors: [.clear, LivingSignalTone.active.color.opacity(0.2), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.36)
                        .offset(x: scanOffset * geometry.size.width)
                        .allowsHitTesting(false)
                    }

                    TrafficPulseLine(
                        values: presentation.points.map(\.uploadBytesPerSecond),
                        size: geometry.size,
                        color: LivingSignalTone.uploadHeavy.color
                    )
                    TrafficPulseLine(
                        values: presentation.points.map(\.downloadBytesPerSecond),
                        size: geometry.size,
                        color: LivingSignalTone.active.color
                    )

                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            LegendDot(title: appPreferences.text("下载", "Down"), color: LivingSignalTone.active.color)
                            LegendDot(title: appPreferences.text("上传", "Up"), color: LivingSignalTone.uploadHeavy.color)
                            Spacer()
                            Text("\(presentation.points.count) pts")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(height: LivingSignalLayout.chartHeight)
        }
        .livingSignalPanel(tone: isActive ? .active : .idle, isElevated: true, padding: 12)
        .onAppear {
            guard policy.allowsScan else { return }
            scanOffset = -1
            withAnimation(.linear(duration: policy.scanDuration).repeatForever(autoreverses: false)) {
                scanOffset = 1.4
            }
        }
    }
}

private struct TrafficPulseGrid: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 0.5)
                Spacer()
            }
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

private struct TrafficPulseLine: View {
    let values: [Double]
    let size: CGSize
    let color: Color

    var body: some View {
        ZStack {
            filledPath
                .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            linePath
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var linePath: Path {
        Path { path in
            let normalized = TrafficPulseChartScale.normalizedValues(values)
            guard normalized.count > 1 else { return }
            let step = size.width / CGFloat(normalized.count - 1)
            for index in normalized.indices {
                let x = CGFloat(index) * step
                let y = size.height - (CGFloat(normalized[index]) * (size.height - 12)) - 6
                if index == normalized.startIndex {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private var filledPath: Path {
        Path { path in
            let normalized = TrafficPulseChartScale.normalizedValues(values)
            guard normalized.count > 1 else { return }
            let step = size.width / CGFloat(normalized.count - 1)
            for index in normalized.indices {
                let x = CGFloat(index) * step
                let y = size.height - (CGFloat(normalized[index]) * (size.height - 12)) - 6
                if index == normalized.startIndex {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.addLine(to: CGPoint(x: CGFloat(normalized.count - 1) * step, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }
}
```

Move `LegendDot` from the old popover file into this file so the chart owns its legend.

- [ ] **Step 5: Wire header and chart into the root**

In `Sources/NetBar/Popover/NetworkPopoverView.swift`, replace the old `HeaderView` use with:

```swift
PopoverHeaderView(
    presentation: LivingSignalStatusPresentation.make(
        snapshot: monitor.snapshot,
        latestEvent: monitor.intelligenceSummary.latestEvent,
        language: appPreferences.resolvedLanguage
    ),
    snapshot: monitor.snapshot,
    appPreferences: appPreferences
)
```

Replace the old `TrafficChart` block with:

```swift
let chartPresentation = TrafficHistoryWindowPresentation.make(
    points: monitor.recentHistory,
    window: historyWindow
)
TrafficPulseChartView(
    presentation: chartPresentation,
    selectedWindow: $historyWindow,
    appPreferences: appPreferences
)
```

Delete the old private `HeaderView`, `TrafficChart`, `ChartLine`, and duplicate `LegendDot` definitions from `Sources/NetBar/Popover/NetworkPopoverView.swift`.

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testTrafficPulseChartScale
swift test --filter PreferencesAndPresentationTests/testLivingSignalStatusPresentation
```

Expected: PASS.

- [ ] **Step 7: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/NetBar/Popover/NetworkPopoverView.swift Sources/NetBar/Popover/PopoverHeaderView.swift Sources/NetBar/Popover/TrafficPulseChartView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add living signal header and pulse chart"
```

---

### Task 4: Insight and Summary Panels

**Files:**
- Create: `Sources/NetBar/Popover/InsightStreamView.swift`
- Create: `Sources/NetBar/Popover/NetworkSummaryPanel.swift`
- Modify: `Sources/NetBar/Popover/NetworkPopoverView.swift`
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: `NetworkIntelligenceStatusPresentation`, `NetworkDailySummaryPresentation`, `NetworkHistoryPresentation`, `LivingSignalTone`
- Produces: `InsightStreamView`, `TodayNetworkSummaryPanel`, `HistoryLedgerPanel`, `ApplicationTopPanel`, `SevenDaySummaryPanel`

- [ ] **Step 1: Add a file decomposition test**

Add:

```swift
// MARK: - Popover Decomposition Tests

extension PreferencesAndPresentationTests {
    func testLivingSignalPopoverOwnsInsightAndSummaryFiles() throws {
        let insightSource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "InsightStreamView.swift"]
        )
        let summarySource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkSummaryPanel.swift"]
        )
        let rootSource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkPopoverView.swift"]
        )

        XCTAssertTrue(insightSource.contains("struct InsightStreamView"))
        XCTAssertTrue(insightSource.contains("struct NetworkIntelligenceStatusCard"))
        XCTAssertTrue(summarySource.contains("struct TodayNetworkSummaryPanel"))
        XCTAssertTrue(summarySource.contains("struct HistoryLedgerPanel"))
        XCTAssertFalse(rootSource.contains("struct TodayNetworkSummary: View"))
        XCTAssertFalse(rootSource.contains("private var insightStreamSection"))
    }
}
```

- [ ] **Step 2: Run the decomposition test to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignalPopoverOwnsInsightAndSummaryFiles
```

Expected: FAIL because the new files do not exist or root still owns those sections.

- [ ] **Step 3: Create the insight stream file**

Create `Sources/NetBar/Popover/InsightStreamView.swift` by moving these existing types and section logic out of `Sources/NetBar/Popover/NetworkPopoverView.swift`:

```swift
import SwiftUI

enum NetworkIntelligenceTone: Equatable {
    case normal
    case attention
    case critical
}

struct NetworkIntelligenceStatusPresentation: Equatable {
    let title: String
    let message: String
    let tone: NetworkIntelligenceTone
    let symbolName: String

    init(event: NetworkAnomalyEvent?, language: AppLanguage) {
        guard let event else {
            title = language.text("网络状态正常", "Network status normal")
            message = language.text("没有检测到需要注意的网络异常。", "No network anomalies need attention.")
            tone = .normal
            symbolName = "checkmark.seal.fill"
            return
        }

        title = event.title
        message = event.message
        switch event.severity {
        case .info:
            tone = .normal
            symbolName = "info.circle.fill"
        case .warning:
            tone = .attention
            symbolName = "exclamationmark.circle.fill"
        case .critical:
            tone = .critical
            symbolName = "exclamationmark.triangle.fill"
        }
    }
}

struct InsightStreamView: View {
    let summary: NetworkIntelligenceSummary
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NetworkIntelligenceStatusCard(
                presentation: NetworkIntelligenceStatusPresentation(
                    event: summary.latestEvent,
                    language: appPreferences.resolvedLanguage
                ),
                appPreferences: appPreferences,
                openPreferences: openPreferences
            )

            if appPreferences.networkIntelligenceSettings.isInsightStreamEnabled {
                insightCards
            }
        }
    }

    @ViewBuilder
    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("洞察事件", "Insights"),
                subtitle: appPreferences.text("最近异常与建议", "Recent anomalies and suggestions")
            )

            if summary.insightCards.isEmpty {
                Text(appPreferences.text("暂无新的洞察事件。", "No new insights."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .livingSignalPanel(tone: .idle, padding: 9)
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(summary.insightCards.prefix(5))) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(card.message)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if !card.suggestion.isEmpty {
                                Text(card.suggestion)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .livingSignalPanel(tone: .attention, padding: 9)
                    }
                }
            }
        }
    }
}
```

Move the current `NetworkIntelligenceStatusCard` implementation below this code, replacing `.netBarCard(...)` with `.livingSignalPanel(...)` and mapping `NetworkIntelligenceTone` to `LivingSignalTone`:

```swift
private var livingTone: LivingSignalTone {
    switch presentation.tone {
    case .normal:
        return .normal
    case .attention:
        return .attention
    case .critical:
        return .critical
    }
}
```

- [ ] **Step 4: Create the summary panel file**

Create `Sources/NetBar/Popover/NetworkSummaryPanel.swift` by moving these existing types and views from the root popover file:

```text
NetworkDailySummaryCard
CharacterPlaybackMilestone
NetworkDailySummaryPresentation
TodayNetworkSummary
DailySummaryCell
ApplicationTopSection
TopSubsectionTitle
DailyApplicationUsageRow
SevenDaySummarySection
SevenDaySummaryRow
SpeedTile
ActivityLevelBars
SummaryGrid
SummaryCell
```

Rename the public section views while keeping their initializer data the same:

```swift
private struct TodayNetworkSummary -> struct TodayNetworkSummaryPanel
private struct ApplicationTopSection -> struct ApplicationTopPanel
private struct SevenDaySummarySection -> struct SevenDaySummaryPanel
```

Add this new `HistoryLedgerPanel` wrapper in the same file:

```swift
struct HistoryLedgerPanel: View {
    let presentation: NetworkHistoryPresentationModel
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("历史账本", "Traffic Ledger"),
                subtitle: appPreferences.text("本地累计趋势", "Local accumulated trends")
            )

            HStack(spacing: 8) {
                historyMetricCard(
                    title: appPreferences.text("今日", "Today"),
                    value: ByteFormat.bytes(presentation.today.totalBytes)
                )
                historyMetricCard(
                    title: presentation.sevenDay.title,
                    value: ByteFormat.bytes(presentation.sevenDay.totalBytes)
                )
                historyMetricCard(
                    title: presentation.thirtyDay.title,
                    value: ByteFormat.bytes(presentation.thirtyDay.totalBytes)
                )
            }

            if let peak = presentation.peakDownload {
                Text("\(appPreferences.text("峰值下载", "Peak download")) \(peak.dateKey): \(ByteFormat.speed(peak.downloadBytesPerSecond))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if appPreferences.networkIntelligenceSettings.isApplicationHistoryRankingEnabled {
                applicationRanking
            }

            Text(presentation.estimateNotice)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .livingSignalPanel(tone: .neutral, padding: 12)
    }

    @ViewBuilder
    private var applicationRanking: some View {
        if presentation.applicationRanking.isEmpty {
            Text(appPreferences.text("暂无应用累计排行。", "No application ranking yet."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 5) {
                ForEach(Array(presentation.applicationRanking.prefix(5))) { app in
                    HStack {
                        Text(app.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(ByteFormat.bytes(app.totalBytes))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func historyMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .livingSignalPanel(tone: .neutral, padding: 8)
    }
}
```

- [ ] **Step 5: Wire insight and summary panels into the root**

In `Sources/NetBar/Popover/NetworkPopoverView.swift`, replace the old intelligence status card and `insightStreamSection` with:

```swift
InsightStreamView(
    summary: monitor.intelligenceSummary,
    appPreferences: appPreferences,
    openPreferences: openPreferences
)
.padding(.top, 16)
```

Replace the old today summary with:

```swift
TodayNetworkSummaryPanel(
    summary: monitor.intelligenceSummary,
    appPreferences: appPreferences,
    customCharacterStore: customCharacterStore
)
```

Replace the old history ledger section with:

```swift
HistoryLedgerPanel(
    presentation: NetworkHistoryPresentation.make(
        summary: monitor.intelligenceSummary,
        language: appPreferences.resolvedLanguage
    ),
    appPreferences: appPreferences
)
```

Replace top and seven-day sections with:

```swift
ApplicationTopPanel(
    realtimeApplications: monitor.intelligenceSummary.realtimeTopApplications,
    todayApplications: monitor.intelligenceSummary.todayTopApplications,
    appPreferences: appPreferences
)

SevenDaySummaryPanel(
    summaries: monitor.intelligenceSummary.recentDays,
    appPreferences: appPreferences
)
```

Delete the moved definitions from `Sources/NetBar/Popover/NetworkPopoverView.swift`.

- [ ] **Step 6: Run decomposition and existing summary tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignalPopoverOwnsInsightAndSummaryFiles
swift test --filter PreferencesAndPresentationTests/testNetworkDailySummaryPresentation
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryPresentation
```

Expected: PASS.

- [ ] **Step 7: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/NetBar/Popover/NetworkPopoverView.swift Sources/NetBar/Popover/InsightStreamView.swift Sources/NetBar/Popover/NetworkSummaryPanel.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "refactor: split popover insight and summary panels"
```

---

### Task 5: Application, Interface, System, and Footer Panels

**Files:**
- Create: `Sources/NetBar/Popover/ApplicationTrafficPanel.swift`
- Create: `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift`
- Create: `Sources/NetBar/Popover/PopoverFooterView.swift`
- Modify: `Sources/NetBar/Popover/NetworkPopoverView.swift`
- Delete: `Sources/NetBar/NetworkPopoverView.swift` if it only contains the temporary compatibility marker.
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: `ApplicationTrafficPresentation`, `InterfacePresentation`, `SystemResourceSummary`, `LivingSignalTone`
- Produces: `ApplicationTrafficPanel`, `InterfaceAndSystemPanel`, `PopoverFooterView`

- [ ] **Step 1: Add decomposition tests for remaining popover files**

Add:

```swift
extension PreferencesAndPresentationTests {
    func testLivingSignalPopoverOwnsApplicationInterfaceAndFooterFiles() throws {
        let appSource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "ApplicationTrafficPanel.swift"]
        )
        let interfaceSource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "InterfaceAndSystemPanel.swift"]
        )
        let footerSource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "PopoverFooterView.swift"]
        )
        let rootSource = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkPopoverView.swift"]
        )

        XCTAssertTrue(appSource.contains("struct ApplicationTrafficPanel"))
        XCTAssertTrue(appSource.contains("struct ApplicationTrafficRow"))
        XCTAssertTrue(interfaceSource.contains("struct InterfaceAndSystemPanel"))
        XCTAssertTrue(interfaceSource.contains("struct InterfaceRow"))
        XCTAssertTrue(footerSource.contains("struct PopoverFooterView"))
        XCTAssertFalse(rootSource.contains("struct ApplicationTrafficList"))
        XCTAssertFalse(rootSource.contains("struct InterfaceList"))
        XCTAssertFalse(rootSource.contains("struct FooterView"))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignalPopoverOwnsApplicationInterfaceAndFooterFiles
```

Expected: FAIL because the files are not split yet.

- [ ] **Step 3: Create the application traffic panel**

Create `Sources/NetBar/Popover/ApplicationTrafficPanel.swift` by moving these definitions from the root popover file:

```text
ApplicationTrafficList
AppTrafficAttributionCard
AppTrafficControls
AppTrafficNotice
ApplicationTrafficRow
AttributionRoleBadge
CompactMetric
AppBadgeIconResolver
AppBadge
```

Rename `ApplicationTrafficList` to:

```swift
struct ApplicationTrafficPanel: View {
    let snapshot: NetworkSnapshot
    let appTraffic: ApplicationTrafficState
    @ObservedObject var preferences: AppPreferences
    @Binding var searchText: String
    let retry: () -> Void

    var body: some View {
        ApplicationTrafficList(
            snapshot: snapshot,
            appTraffic: appTraffic,
            preferences: preferences,
            searchText: $searchText,
            retry: retry
        )
    }
}
```

Keep the moved internal `ApplicationTrafficList` as a private implementation detail in the same file for this task. Replace card wrappers in moved views from `.netBarCard(...)` to `.livingSignalPanel(...)` one view at a time, preserving all strings and controls.

- [ ] **Step 4: Create the interface and system panel**

Create `Sources/NetBar/Popover/InterfaceAndSystemPanel.swift` by moving:

```text
InterfaceList
EmptyInterfacesView
InterfaceRow
SystemResourceCard
MetricPill
```

Add this wrapper:

```swift
struct InterfaceAndSystemPanel: View {
    let snapshot: NetworkSnapshot
    let systemResources: SystemResourceSummary
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LivingSignalLayout.verticalSectionSpacing) {
            SystemResourceCard(summary: systemResources, appPreferences: appPreferences)
            InterfaceList(
                interfaces: snapshot.interfaces,
                appPreferences: appPreferences,
                refresh: refresh
            )
        }
    }
}
```

Keep `InterfacePresentation` in `NetBarDesignSystem.swift` for this task because it is already shared.

- [ ] **Step 5: Create the footer view**

Create `Sources/NetBar/Popover/PopoverFooterView.swift` by moving the existing `FooterView` implementation and renaming it:

```swift
import SwiftUI

struct PopoverFooterView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        FooterView(monitor: monitor, appPreferences: appPreferences, openPreferences: openPreferences)
    }
}
```

Keep `FooterView` private in this file during the move, then replace its cards and icon buttons with Living Signal panel/chip styles while preserving the existing button actions and `.help(...)` strings.

- [ ] **Step 6: Wire the root to the new panels**

In `Sources/NetBar/Popover/NetworkPopoverView.swift`, replace application traffic use with:

```swift
ApplicationTrafficPanel(
    snapshot: monitor.snapshot,
    appTraffic: monitor.appTraffic,
    preferences: appPreferences,
    searchText: $appSearchText,
    retry: monitor.refreshApplicationTraffic
)
```

Replace interface and system resource use with:

```swift
InterfaceAndSystemPanel(
    snapshot: monitor.snapshot,
    systemResources: monitor.appTraffic.systemResources,
    appPreferences: appPreferences,
    refresh: monitor.refresh
)
```

Replace footer use with:

```swift
PopoverFooterView(
    monitor: monitor,
    appPreferences: appPreferences,
    openPreferences: openPreferences
)
```

Delete moved definitions from the root. If `Sources/NetBar/NetworkPopoverView.swift` only contains the compatibility marker after the split, delete that old root file in this task.

- [ ] **Step 7: Run decomposition and app presentation tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testLivingSignalPopoverOwnsApplicationInterfaceAndFooterFiles
swift test --filter PreferencesAndPresentationTests/testApplicationTrafficPresentation
```

Expected: PASS.

- [ ] **Step 8: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 9: Commit**

Run:

```bash
git add Sources/NetBar/Popover/NetworkPopoverView.swift Sources/NetBar/Popover/ApplicationTrafficPanel.swift Sources/NetBar/Popover/InterfaceAndSystemPanel.swift Sources/NetBar/Popover/PopoverFooterView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git add -u Sources/NetBar/NetworkPopoverView.swift
git commit -m "refactor: split remaining popover panels"
```

---

### Task 6: Preferences Living Signal Refresh

**Files:**
- Modify: `Sources/NetBar/NetBarDesignSystem.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesComponents.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesWindowController.swift`
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: `LivingSignalTone`, `View.livingSignalPanel(...)`, `View.livingSignalPanelBackground()`
- Produces: refreshed shared preference section components without changing settings models or UserDefaults keys.

- [ ] **Step 1: Add source-structure tests for shared preference components**

Add:

```swift
extension PreferencesAndPresentationTests {
    func testPreferencesComponentsUseLivingSignalPanelStyles() throws {
        let source = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesComponents.swift"]
        )

        XCTAssertTrue(source.contains("livingSignalPanel"))
        XCTAssertTrue(source.contains("PreferencesHeroHeader"))
        XCTAssertTrue(source.contains("LivingSignalTone.active"))
    }

    func testPreferencesWindowUsesLivingSignalPanelBackground() throws {
        let source = try projectFileContents(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesWindowController.swift"]
        )

        XCTAssertTrue(source.contains("livingSignalPanelBackground()"))
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPreferencesComponentsUseLivingSignalPanelStyles
swift test --filter PreferencesAndPresentationTests/testPreferencesWindowUsesLivingSignalPanelBackground
```

Expected: FAIL because preferences still use the older `netBarCard` styling.

- [ ] **Step 3: Keep `NetBarDesignSystem` as compatibility primitives**

In `Sources/NetBar/NetBarDesignSystem.swift`, keep `NetBarTone`, `NetBarBadge`, and `NetBarIconButtonStyle` for existing call sites. Add a bridge so existing `.netBarPanelBackground()` gets the new background:

```swift
extension View {
    func netBarPanelBackground() -> some View {
        livingSignalPanelBackground()
    }
}
```

If this creates a duplicate extension method, replace the old `netBarPanelBackground()` implementation body with the one-line bridge above.

- [ ] **Step 4: Refresh shared preference sections**

In `Sources/NetBar/Preferences/PreferencesComponents.swift`, replace the content card in `CollapsiblePreferenceSection`:

```swift
.netBarCard(cornerRadius: 12, padding: 12)
```

with:

```swift
.livingSignalPanel(tone: .neutral, padding: 12)
```

Replace the content card in `PreferenceSection` with:

```swift
.livingSignalPanel(tone: .neutral, padding: 12)
```

Replace `PreferencesHeroHeader.body` with:

```swift
var body: some View {
    HStack(spacing: 12) {
        Image(systemName: "waveform.path.ecg.rectangle")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(LivingSignalTone.active.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: LivingSignalTone.active.color.opacity(0.22), radius: 12, x: 0, y: 4)

        VStack(alignment: .leading, spacing: 3) {
            Text(appPreferences.text("NetBar 信号控制台", "NetBar Signal Console"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(appPreferences.text(
                "调整菜单栏指标、信号面板、应用流量和更新策略。",
                "Tune menu bar metrics, signal panels, app traffic, and update behavior."
            ))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .lineLimit(2)
        }

        Spacer()

        LivingSignalStatusChip(text: updater.currentVersionText, tone: .neutral)
    }
    .livingSignalPanel(tone: LivingSignalTone.active, isElevated: true, padding: 14)
}
```

This introduces new copy, so the Chinese and English strings are both present in the code above.

- [ ] **Step 5: Update preferences background**

In `Sources/NetBar/Preferences/PreferencesWindowController.swift`, keep the `TabView` structure and replace:

```swift
.netBarPanelBackground()
```

with:

```swift
.livingSignalPanelBackground()
```

- [ ] **Step 6: Run focused preference tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPreferencesComponentsUseLivingSignalPanelStyles
swift test --filter PreferencesAndPresentationTests/testPreferencesWindowUsesLivingSignalPanelBackground
swift test --filter PreferencesAndPresentationTests/testAppPreferences
```

Expected: PASS.

- [ ] **Step 7: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/NetBar/NetBarDesignSystem.swift Sources/NetBar/Preferences/PreferencesComponents.swift Sources/NetBar/Preferences/PreferencesWindowController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "style: refresh preferences with living signal panels"
```

---

### Task 7: Menu Bar Balanced Pulse Policy

**Files:**
- Modify: `Sources/NetBar/StatusBarStyle.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

**Interfaces:**
- Consumes: `NetworkSnapshot`, `StatusBarRenderSignature`, existing `StatusBarDisplayRenderer.signature(...)`
- Produces: `StatusBarPulseRenderPolicy`, `StatusBarRenderSignature.statusPulseTimeBucket`

- [ ] **Step 1: Write failing pulse policy tests**

Add:

```swift
// MARK: - Status Bar Pulse Render Policy Tests

extension PreferencesAndPresentationTests {
    func testStatusBarPulseRenderPolicyDisablesBucketForIdleAndReducedMotion() {
        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: sampleSnapshot(download: 0, upload: 0),
                reduceMotion: false,
                renderTime: 12.4
            ),
            0
        )

        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: sampleSnapshot(download: 2_000_000, upload: 100_000),
                reduceMotion: true,
                renderTime: 12.4
            ),
            0
        )
    }

    func testStatusBarPulseRenderPolicyQuantizesActiveTrafficAtTwoHz() {
        let snapshot = sampleSnapshot(download: 2_000_000, upload: 100_000)

        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: false,
                renderTime: 10.24
            ),
            20
        )
        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: false,
                renderTime: 10.26
            ),
            20
        )
        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: false,
                renderTime: 10.51
            ),
            21
        )
    }

    func testStatusBarSignatureIncludesPulseBucketOnlyForActiveTraffic() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())

        let idleSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 0, upload: 0),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua",
            renderTime: 10.51,
            reduceMotion: false
        )
        XCTAssertEqual(idleSignature.statusPulseTimeBucket, 0)

        let activeSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 2_000_000, upload: 100_000),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua",
            renderTime: 10.51,
            reduceMotion: false
        )
        XCTAssertEqual(activeSignature.statusPulseTimeBucket, 21)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarPulseRenderPolicy
swift test --filter PreferencesAndPresentationTests/testStatusBarSignatureIncludesPulseBucketOnlyForActiveTraffic
```

Expected: FAIL because `StatusBarPulseRenderPolicy`, the signature parameter, and `statusPulseTimeBucket` do not exist.

- [ ] **Step 3: Add pulse policy and signature field**

In `Sources/NetBar/StatusBarStyle.swift`, add a signature field:

```swift
let statusPulseTimeBucket: Int
```

Add this policy near the render signature definitions:

```swift
enum StatusBarPulseRenderPolicy {
    static let activeTrafficThresholdBytesPerSecond: Double = 100_000

    static func isActive(snapshot: NetworkSnapshot) -> Bool {
        snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond >= activeTrafficThresholdBytesPerSecond
    }

    static func timeBucket(
        snapshot: NetworkSnapshot,
        reduceMotion: Bool,
        renderTime: TimeInterval
    ) -> Int {
        guard !reduceMotion, isActive(snapshot: snapshot) else { return 0 }
        return Int(renderTime * 2)
    }

    static func pulseAlpha(
        snapshot: NetworkSnapshot,
        reduceMotion: Bool,
        renderTime: TimeInterval
    ) -> CGFloat {
        guard timeBucket(snapshot: snapshot, reduceMotion: reduceMotion, renderTime: renderTime) > 0 else {
            return 0
        }
        let wave = 0.5 + 0.5 * sin(renderTime * .pi * 2)
        return CGFloat(0.08 + wave * 0.1)
    }
}
```

Update `StatusBarDisplayRenderer.signature(...)` to accept render time and reduced motion:

```swift
static func signature(
    snapshot: NetworkSnapshot,
    settings: StatusBarSettings,
    appearanceName: String,
    customCharacterStore: CustomCharacterStore? = nil,
    catFrameIndex: Int? = nil,
    characterOverrideID: String? = nil,
    googlyEyesState: GooglyEyesRenderState? = nil,
    smartContext: SmartStatusBarContext = .manual,
    renderTime: TimeInterval = Date().timeIntervalSince1970,
    reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
) -> StatusBarRenderSignature
```

Set the new signature field:

```swift
statusPulseTimeBucket: StatusBarPulseRenderPolicy.timeBucket(
    snapshot: snapshot,
    reduceMotion: reduceMotion,
    renderTime: renderTime
),
```

- [ ] **Step 4: Draw a bounded background pulse**

In `StatusBarDisplayRenderer.image(...)`, inside the existing background drawing block for `settings.showsBackground`, add the pulse overlay after the solid/rounded background fill:

```swift
let pulseAlpha = StatusBarPulseRenderPolicy.pulseAlpha(
    snapshot: snapshot,
    reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
    renderTime: renderTime
)
if pulseAlpha > 0 {
    let pulseColor = snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond
        ? NSColor.systemOrange
        : NSColor.systemTeal
    pulseColor.withAlphaComponent(pulseAlpha).setFill()
    backgroundPath.fill()
}
```

Use the existing background path variable. If the current code names it differently, keep the current path variable and apply the exact overlay after the background fill and before text/character drawing.

- [ ] **Step 5: Keep controller calls cache-friendly**

In `Sources/NetBar/StatusBarController.swift`, keep the existing signature call but pass `renderTime` once per render cycle if the method already computes one. If it does not, add:

```swift
let renderTime = Date().timeIntervalSince1970
```

Then call:

```swift
let signature = StatusBarDisplayRenderer.signature(
    snapshot: snapshot,
    settings: settings,
    appearanceName: appearanceName,
    customCharacterStore: customCharacterStore,
    catFrameIndex: catFrameIndex,
    characterOverrideID: characterOverrideID,
    googlyEyesState: googlyEyesState,
    smartContext: smartContext,
    renderTime: renderTime
)
```

Use the same `renderTime` when calling `StatusBarDisplayRenderer.image(...)`.

- [ ] **Step 6: Run focused status bar tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarPulseRenderPolicy
swift test --filter PreferencesAndPresentationTests/testStatusBarSignatureIncludesPulseBucketOnlyForActiveTraffic
swift test --filter PreferencesAndPresentationTests/testStatusBarRenderedImageCacheReusesMatchingSignatureAndEvictsOldest
```

Expected: PASS.

- [ ] **Step 7: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/NetBar/StatusBarStyle.swift Sources/NetBar/StatusBarController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add balanced pulse status bar policy"
```

---

### Task 8: Final Verification and Polish

**Files:**
- Modify: only files touched by fixes found during verification.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: a verified Living Signal UI restructure ready for review.

- [ ] **Step 1: Confirm temporary visual companion artifacts are ignored**

Run:

```bash
git status --short --ignored | rg "\\.superpowers|docs/superpowers/plans/2026-06-29-netbar-living-signal-ui-restructure.md|docs/superpowers/specs/2026-06-29-netbar-living-signal-ui-restructure-design.md"
```

Expected output includes `.superpowers/` only as ignored output if present, and shows no untracked visual companion files.

- [ ] **Step 2: Run formatting and whitespace check**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 3: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 4: Build the app bundle because this is a large UI restructure**

Run:

```bash
./Scripts/build-app.sh
```

Expected: `build/NetBar.app` is created successfully. Do not run `build/NetBar.app/Contents/MacOS/NetBar` directly.

- [ ] **Step 5: Verify the app bundle**

Run:

```bash
./Scripts/verify-release-app.sh build/NetBar.app
```

Expected: verification succeeds for executable, architecture, and local signing shape.

- [ ] **Step 6: Inspect changed files**

Run:

```bash
git diff --stat HEAD
git status --short
```

Expected: only intentional Living Signal UI files and tests are changed.

- [ ] **Step 7: Commit final polish if Step 6 shows changes**

If Step 6 shows changes, run:

```bash
git add Sources/NetBar Tests/NetBarTests .gitignore docs/superpowers
git commit -m "chore: verify living signal ui restructure"
```

If Step 6 shows a clean tree, do not create an empty commit.
