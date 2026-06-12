# NetBar v0.39 Product Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the v0.39 broad product enhancement release across network insights, smart menu bar behavior, 30-day history, diagnostics, and pet feedback.

**Architecture:** Keep `NetworkMonitor` as the sampling coordinator and add focused collaborators for insight cards, smart status-bar context, history presentation, diagnostics, and pet activity state. Extend existing SwiftUI preference/detail views through presentation models instead of embedding product rules directly in views.

**Tech Stack:** Swift 5 language mode, Swift Package Manager, AppKit, SwiftUI, Combine, XCTest, macOS 13 system frameworks only.

---

## File Structure

Create:

- `Sources/NetBar/NetworkInsightCenter.swift`: Builds bounded user-facing insight cards from anomaly events and context.
- `Sources/NetBar/StatusBarContextEvaluator.swift`: Computes smart menu bar emphasis without drawing UI.
- `Sources/NetBar/NetworkHistoryPresentation.swift`: Builds today, 7-day, 30-day, peak, and application ranking display models.
- `Sources/NetBar/DiagnosticsCenter.swift`: Builds privacy-safe diagnostics snapshots and copyable text.
- `Sources/NetBar/Preferences/DiagnosticsPreferencesView.swift`: Renders diagnostics status and copy action inside preferences.

Modify:

- `Sources/NetBar/NetworkIntelligenceModels.swift`: Extend settings and summary models for v0.39.
- `Sources/NetBar/AppPreferences.swift`: Persist the extended `NetworkIntelligenceSettings`.
- `Sources/NetBar/NetworkHistoryStore.swift`: Support 30-day retention, tracking enablement, and storage status.
- `Sources/NetBar/NetworkMonitor.swift`: Configure history tracking, publish insight cards, expose sampling diagnostics.
- `Sources/NetBar/NetworkIntelligenceCoordinator.swift`: Forward insight events without owning product rules.
- `Sources/NetBar/StatusBarController.swift`: Evaluate smart status-bar context and pass it into rendering.
- `Sources/NetBar/StatusBarStyle.swift`: Accept optional smart context in signatures, presentation, and layout.
- `Sources/NetBar/PetState.swift`: Add pet activity level and feedback settings.
- `Sources/NetBar/PetController.swift`: Respect pet feedback settings and update activity level.
- `Sources/NetBar/NetworkPopoverView.swift`: Add insight stream and richer history sections.
- `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`: Add v0.39 insight/history toggles.
- `Sources/NetBar/Preferences/MenuBarPreferencesView.swift`: Add smart menu bar controls.
- `Sources/NetBar/Preferences/AboutPreferencesView.swift`: Add diagnostics section.
- `Tests/NetBarTests/PreferencesAndPresentationTests.swift`: Add most model and presentation tests.
- `Tests/NetBarTests/SystemResourceTests.swift`: Add monitor integration diagnostics tests.
- `CHANGELOG.md`: Add an unreleased v0.39 entry after implementation is complete.

Avoid broad rewrites of `StatusBarStyle.swift`, `NetworkPopoverView.swift`, and preference tab structure. Touch only the narrow areas called out by each task.

---

### Task 1: v0.39 Settings Model

**Files:**
- Modify: `Sources/NetBar/NetworkIntelligenceModels.swift`
- Modify: `Sources/NetBar/AppPreferences.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing settings tests**

Add these tests near the existing `NetworkIntelligenceSettings` tests in `Tests/NetBarTests/PreferencesAndPresentationTests.swift`.

```swift
func testNetworkIntelligenceSettingsV039Defaults() {
    let settings = NetworkIntelligenceSettings.default

    XCTAssertTrue(settings.isInsightStreamEnabled)
    XCTAssertEqual(settings.insightRetentionLimit, 20)
    XCTAssertTrue(settings.isInsightSuggestionEnabled)
    XCTAssertFalse(settings.isSmartStatusBarModeEnabled)
    XCTAssertTrue(settings.showsSmartAnomalyMarker)
    XCTAssertTrue(settings.showsSmartTopApplication)
    XCTAssertEqual(settings.historyRetentionDays, 30)
    XCTAssertTrue(settings.isApplicationHistoryRankingEnabled)
}

func testNetworkIntelligenceSettingsDecodesMissingV039FieldsWithDefaults() throws {
    let legacyJSON = """
    {
      "hasSeenNotificationOnboarding": true,
      "isAnomalyDetectionEnabled": false,
      "isSystemNotificationEnabled": true,
      "highTrafficThreshold": 26214400,
      "isApplicationSpikeAlertEnabled": false,
      "isNetworkDropAlertEnabled": true,
      "isProxyAttributionAlertEnabled": false,
      "isHistoryTrackingEnabled": true
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(NetworkIntelligenceSettings.self, from: legacyJSON)

    XCTAssertTrue(decoded.hasSeenNotificationOnboarding)
    XCTAssertFalse(decoded.isAnomalyDetectionEnabled)
    XCTAssertEqual(decoded.highTrafficThreshold, .mbps25)
    XCTAssertTrue(decoded.isInsightStreamEnabled)
    XCTAssertEqual(decoded.insightRetentionLimit, 20)
    XCTAssertFalse(decoded.isSmartStatusBarModeEnabled)
    XCTAssertEqual(decoded.historyRetentionDays, 30)
    XCTAssertTrue(decoded.isApplicationHistoryRankingEnabled)
}
```

- [ ] **Step 2: Run settings tests and confirm failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkIntelligenceSettingsV039Defaults
```

Expected: FAIL because `NetworkIntelligenceSettings` does not yet have the v0.39 properties.

- [ ] **Step 3: Extend `NetworkIntelligenceSettings`**

In `Sources/NetBar/NetworkIntelligenceModels.swift`, add the v0.39 properties after `isHistoryTrackingEnabled`.

```swift
var isInsightStreamEnabled: Bool
var insightRetentionLimit: Int
var isInsightSuggestionEnabled: Bool
var isSmartStatusBarModeEnabled: Bool
var showsSmartAnomalyMarker: Bool
var showsSmartTopApplication: Bool
var historyRetentionDays: Int
var isApplicationHistoryRankingEnabled: Bool
```

Update the initializer by appending defaulted parameters so existing call sites keep compiling.

```swift
isHistoryTrackingEnabled: Bool,
isInsightStreamEnabled: Bool = true,
insightRetentionLimit: Int = 20,
isInsightSuggestionEnabled: Bool = true,
isSmartStatusBarModeEnabled: Bool = false,
showsSmartAnomalyMarker: Bool = true,
showsSmartTopApplication: Bool = true,
historyRetentionDays: Int = 30,
isApplicationHistoryRankingEnabled: Bool = true
```

Inside the initializer body, assign the appended values:

```swift
self.isInsightStreamEnabled = isInsightStreamEnabled
self.insightRetentionLimit = insightRetentionLimit
self.isInsightSuggestionEnabled = isInsightSuggestionEnabled
self.isSmartStatusBarModeEnabled = isSmartStatusBarModeEnabled
self.showsSmartAnomalyMarker = showsSmartAnomalyMarker
self.showsSmartTopApplication = showsSmartTopApplication
self.historyRetentionDays = historyRetentionDays
self.isApplicationHistoryRankingEnabled = isApplicationHistoryRankingEnabled
```

In `init(from:)`, decode each new field with defaults:

```swift
isInsightStreamEnabled = try container.decodeIfPresent(
    Bool.self,
    forKey: .isInsightStreamEnabled
) ?? defaultSettings.isInsightStreamEnabled
insightRetentionLimit = try container.decodeIfPresent(
    Int.self,
    forKey: .insightRetentionLimit
) ?? defaultSettings.insightRetentionLimit
isInsightSuggestionEnabled = try container.decodeIfPresent(
    Bool.self,
    forKey: .isInsightSuggestionEnabled
) ?? defaultSettings.isInsightSuggestionEnabled
isSmartStatusBarModeEnabled = try container.decodeIfPresent(
    Bool.self,
    forKey: .isSmartStatusBarModeEnabled
) ?? defaultSettings.isSmartStatusBarModeEnabled
showsSmartAnomalyMarker = try container.decodeIfPresent(
    Bool.self,
    forKey: .showsSmartAnomalyMarker
) ?? defaultSettings.showsSmartAnomalyMarker
showsSmartTopApplication = try container.decodeIfPresent(
    Bool.self,
    forKey: .showsSmartTopApplication
) ?? defaultSettings.showsSmartTopApplication
historyRetentionDays = try container.decodeIfPresent(
    Int.self,
    forKey: .historyRetentionDays
) ?? defaultSettings.historyRetentionDays
isApplicationHistoryRankingEnabled = try container.decodeIfPresent(
    Bool.self,
    forKey: .isApplicationHistoryRankingEnabled
) ?? defaultSettings.isApplicationHistoryRankingEnabled
```

In `encode(to:)`, encode each field:

```swift
try container.encode(isInsightStreamEnabled, forKey: .isInsightStreamEnabled)
try container.encode(insightRetentionLimit, forKey: .insightRetentionLimit)
try container.encode(isInsightSuggestionEnabled, forKey: .isInsightSuggestionEnabled)
try container.encode(isSmartStatusBarModeEnabled, forKey: .isSmartStatusBarModeEnabled)
try container.encode(showsSmartAnomalyMarker, forKey: .showsSmartAnomalyMarker)
try container.encode(showsSmartTopApplication, forKey: .showsSmartTopApplication)
try container.encode(historyRetentionDays, forKey: .historyRetentionDays)
try container.encode(isApplicationHistoryRankingEnabled, forKey: .isApplicationHistoryRankingEnabled)
```

Update `.default` with explicit values:

```swift
isHistoryTrackingEnabled: true,
isInsightStreamEnabled: true,
insightRetentionLimit: 20,
isInsightSuggestionEnabled: true,
isSmartStatusBarModeEnabled: false,
showsSmartAnomalyMarker: true,
showsSmartTopApplication: true,
historyRetentionDays: 30,
isApplicationHistoryRankingEnabled: true
```

Add coding keys:

```swift
case isInsightStreamEnabled
case insightRetentionLimit
case isInsightSuggestionEnabled
case isSmartStatusBarModeEnabled
case showsSmartAnomalyMarker
case showsSmartTopApplication
case historyRetentionDays
case isApplicationHistoryRankingEnabled
```

- [ ] **Step 4: Run settings tests and confirm pass**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkIntelligenceSettings
```

Expected: PASS for all `NetworkIntelligenceSettings` tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/NetworkIntelligenceModels.swift Sources/NetBar/AppPreferences.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add v0.39 intelligence settings"
```

---

### Task 2: 30-Day History Ledger and Presentation

**Files:**
- Create: `Sources/NetBar/NetworkHistoryPresentation.swift`
- Modify: `Sources/NetBar/NetworkHistoryStore.swift`
- Modify: `Sources/NetBar/NetworkMonitor.swift`
- Modify: `Sources/NetBar/NetworkIntelligenceModels.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing history tests**

Replace the existing `testNetworkHistoryStoreRollsOverAndRetainsSevenDays` with this 30-day version, and add the tracking-disabled test below it.

```swift
func testNetworkHistoryStoreRollsOverAndRetainsThirtyDays() throws {
    let root = try temporaryDirectory()
    let startDate = isoDate("2026-06-01T12:00:00Z")
    var currentDate = startDate
    let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

    for dayOffset in 0..<35 {
        currentDate = fixedCalendar().date(byAdding: .day, value: dayOffset, to: startDate)!
        store.record(snapshot: sampleSnapshot(
            download: 100,
            upload: 50,
            received: UInt64(dayOffset * 1_000 + 1_000),
            sent: UInt64(dayOffset * 1_000 + 2_000),
            timestamp: currentDate
        ))
    }

    XCTAssertEqual(store.summary.recentDays.count, 30)
    XCTAssertEqual(store.summary.today.dateKey, "2026-07-05")
    XCTAssertEqual(store.summary.recentDays.first?.dateKey, "2026-06-05")
    XCTAssertEqual(store.summary.recentDays.last?.dateKey, "2026-07-04")
}

func testNetworkHistoryStoreSkipsWritesWhenTrackingDisabled() throws {
    let root = try temporaryDirectory()
    let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
    store.configure(isTrackingEnabled: false, retentionDays: 30)

    store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000))
    store.record(appTraffic: ApplicationTrafficState(
        timestamp: Date(timeIntervalSince1970: 10),
        applications: [appRate("Safari", download: 2_000, upload: 500)],
        sampleCount: 1,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    ), interval: 1)

    XCTAssertEqual(store.summary.today.downloadBytes, 0)
    XCTAssertEqual(store.summary.today.uploadBytes, 0)
    XCTAssertTrue(store.summary.todayTopApplications.isEmpty)
}

func testNetworkHistoryStoreBacksUpUnreadableStorage() throws {
    let root = try temporaryDirectory()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let historyURL = root.appendingPathComponent("NetworkHistory.json")
    try Data("not-json".utf8).write(to: historyURL)

    let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })

    guard case .unreadableBackupCreated(let backupURL) = store.storageStatus else {
        return XCTFail("Expected unreadable backup status")
    }
    XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    XCTAssertEqual(store.summary.today.dateKey, "1970-01-01")
}
```

Add presentation tests near the history tests:

```swift
func testNetworkHistoryPresentationBuildsSevenAndThirtyDaySummaries() {
    let days = (1...30).map { day in
        NetworkDailySummary(
            dateKey: "2026-06-\(String(format: "%02d", day))",
            downloadBytes: UInt64(day * 1_000),
            uploadBytes: UInt64(day * 100),
            peakDownloadBytesPerSecond: Double(day * 10),
            peakUploadBytesPerSecond: Double(day * 5),
            sampleCount: day,
            activeSeconds: TimeInterval(day * 60),
            topApplications: []
        )
    }
    let summary = NetworkIntelligenceSummary(
        latestEvent: nil,
        today: .empty(dateKey: "2026-07-01"),
        recentDays: days,
        realtimeTopApplications: [],
        todayTopApplications: [],
        animationPlaybackCountsByCharacter: [:]
    )

    let presentation = NetworkHistoryPresentation.make(summary: summary, language: .english)

    XCTAssertEqual(presentation.sevenDay.totalBytes, UInt64((24...30).reduce(0) { $0 + $1 * 1_100 }))
    XCTAssertEqual(presentation.thirtyDay.totalBytes, UInt64((1...30).reduce(0) { $0 + $1 * 1_100 }))
    XCTAssertEqual(presentation.peakDownload?.dateKey, "2026-06-30")
}
```

- [ ] **Step 2: Run history tests and confirm failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStoreRollsOverAndRetainsThirtyDays
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryPresentationBuildsSevenAndThirtyDaySummaries
```

Expected: FAIL because retention is fixed at 7 days and `NetworkHistoryPresentation` does not exist.

- [ ] **Step 3: Add history storage configuration**

In `Sources/NetBar/NetworkHistoryStore.swift`, add:

```swift
enum NetworkHistoryStorageStatus: Equatable {
    case available
    case unreadableBackupCreated(URL)
    case writeFailed(String)
}
```

Add properties:

```swift
@Published private(set) var storageStatus: NetworkHistoryStorageStatus = .available
private var isTrackingEnabled = true
private var retentionDays: Int
```

Update the initializer signature:

```swift
init(
    rootDirectory: URL? = nil,
    calendar: Calendar = .current,
    retentionDays: Int = 30,
    now: @escaping () -> Date = Date.init
)
```

Assign:

```swift
self.retentionDays = max(retentionDays, 1)
```

Replace the initializer's existing decode block with explicit unreadable-file handling:

```swift
let shouldSaveLoadedState: Bool
if let data = try? Data(contentsOf: fileURL) {
    do {
        let decoded = try decoder.decode(PersistedNetworkHistory.self, from: data)
        self.state = Self.normalizedState(decoded, todayKey: currentDateKey, retentionDays: self.retentionDays)
        shouldSaveLoadedState = true
    } catch {
        let backupURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(now().timeIntervalSince1970)).json")
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.moveItem(at: fileURL, to: backupURL)
        self.storageStatus = .unreadableBackupCreated(backupURL)
        self.state = PersistedNetworkHistory(
            today: .empty(dateKey: currentDateKey),
            recentDays: [],
            animationPlaybackCountsByCharacter: [:]
        )
        shouldSaveLoadedState = false
    }
} else {
    self.state = PersistedNetworkHistory(
        today: .empty(dateKey: currentDateKey),
        recentDays: [],
        animationPlaybackCountsByCharacter: [:]
    )
    shouldSaveLoadedState = false
}
```

Add configuration:

```swift
func configure(isTrackingEnabled: Bool, retentionDays: Int) {
    self.isTrackingEnabled = isTrackingEnabled
    self.retentionDays = max(retentionDays, 1)
    state.recentDays = Array(state.recentDays.suffix(self.retentionDays))
    publishAndSave(realtimeTopApplications: summary.realtimeTopApplications)
}
```

At the start of `record(snapshot:)`, `record(appTraffic:interval:)`, and `recordAnimationPlayback(count:characterID:at:)`, add:

```swift
guard isTrackingEnabled else { return }
```

Replace every `suffix(7)` in `NetworkHistoryStore` with:

```swift
suffix(retentionDays)
```

For the static `normalizedState`, add a `retentionDays` parameter and call it from init:

```swift
self.state = Self.normalizedState(decoded, todayKey: currentDateKey, retentionDays: self.retentionDays)
```

Update the static implementation:

```swift
private static func normalizedState(
    _ state: PersistedNetworkHistory,
    todayKey: String,
    retentionDays: Int
) -> PersistedNetworkHistory {
    var today = normalizedDay(state.today)
    var recentDays = state.recentDays.map(normalizedDay)

    if today.dateKey != todayKey {
        recentDays.append(today)
        today = .empty(dateKey: todayKey)
    }

    var normalizedState = PersistedNetworkHistory(
        today: today,
        recentDays: Array(recentDays.suffix(max(retentionDays, 1))),
        animationPlaybackCountsByCharacter: state.animationPlaybackCountsByCharacter
    )
    if normalizedState.animationPlaybackCountsByCharacter.isEmpty {
        normalizedState.animationPlaybackCountsByCharacter = mergedAnimationPlaybackCounts(
            today: normalizedState.today,
            recentDays: normalizedState.recentDays
        )
    }
    return normalizedState
}
```

Update `save()` so diagnostics can report write failures:

```swift
private func save() {
    do {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
        storageStatus = .available
    } catch {
        storageStatus = .writeFailed(error.localizedDescription)
    }
}
```

- [ ] **Step 4: Add history presentation model**

Create `Sources/NetBar/NetworkHistoryPresentation.swift`:

```swift
import Foundation

struct NetworkHistoryRangeSummary: Equatable {
    let id: String
    let title: String
    let days: [NetworkDailySummary]

    var downloadBytes: UInt64 { days.reduce(0) { $0 + $1.downloadBytes } }
    var uploadBytes: UInt64 { days.reduce(0) { $0 + $1.uploadBytes } }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }
    var activeSeconds: TimeInterval { days.reduce(0) { $0 + $1.activeSeconds } }
}

struct NetworkHistoryPeak: Equatable {
    let dateKey: String
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

struct NetworkHistoryPresentationModel: Equatable {
    let today: NetworkDailySummary
    let sevenDay: NetworkHistoryRangeSummary
    let thirtyDay: NetworkHistoryRangeSummary
    let peakDownload: NetworkHistoryPeak?
    let peakUpload: NetworkHistoryPeak?
    let applicationRanking: [ApplicationDailyUsage]
    let estimateNotice: String
}

enum NetworkHistoryPresentation {
    static func make(
        summary: NetworkIntelligenceSummary,
        language: AppLanguage,
        applicationLimit: Int = 10
    ) -> NetworkHistoryPresentationModel {
        let recent = summary.recentDays
        let sevenDays = Array(recent.suffix(7))
        let thirtyDays = Array(recent.suffix(30))
        let rankedApplications = mergedApplications(from: [summary.today] + thirtyDays)
            .sorted {
                if $0.totalBytes != $1.totalBytes { return $0.totalBytes > $1.totalBytes }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }

        return NetworkHistoryPresentationModel(
            today: summary.today,
            sevenDay: NetworkHistoryRangeSummary(
                id: "sevenDay",
                title: language.text("最近 7 天", "Last 7 Days"),
                days: sevenDays
            ),
            thirtyDay: NetworkHistoryRangeSummary(
                id: "thirtyDay",
                title: language.text("最近 30 天", "Last 30 Days"),
                days: thirtyDays
            ),
            peakDownload: peak(in: thirtyDays, useDownload: true),
            peakUpload: peak(in: thirtyDays, useDownload: false),
            applicationRanking: Array(rankedApplications.prefix(applicationLimit)),
            estimateNotice: language.text(
                "历史统计为本地估算值，用于趋势判断，不等同于运营商计费。",
                "History values are local estimates for trend awareness and are not billing-grade measurements."
            )
        )
    }

    private static func peak(in days: [NetworkDailySummary], useDownload: Bool) -> NetworkHistoryPeak? {
        let best = days.max {
            let lhs = useDownload ? $0.peakDownloadBytesPerSecond : $0.peakUploadBytesPerSecond
            let rhs = useDownload ? $1.peakDownloadBytesPerSecond : $1.peakUploadBytesPerSecond
            return lhs < rhs
        }
        guard let best else { return nil }
        return NetworkHistoryPeak(
            dateKey: best.dateKey,
            downloadBytesPerSecond: best.peakDownloadBytesPerSecond,
            uploadBytesPerSecond: best.peakUploadBytesPerSecond
        )
    }

    private static func mergedApplications(from days: [NetworkDailySummary]) -> [ApplicationDailyUsage] {
        var merged: [String: ApplicationDailyUsage] = [:]
        for day in days {
            for app in day.topApplications {
                var current = merged[app.applicationID] ?? app
                if merged[app.applicationID] != nil {
                    current.downloadBytes += app.downloadBytes
                    current.uploadBytes += app.uploadBytes
                    current.lastSeenAt = max(current.lastSeenAt, app.lastSeenAt)
                    current.processNames = Array(Set(current.processNames + app.processNames)).sorted()
                }
                merged[app.applicationID] = current
            }
        }
        return Array(merged.values)
    }
}
```

- [ ] **Step 5: Wire history settings into monitor**

In `Sources/NetBar/NetworkMonitor.swift`, add:

```swift
func configureHistory(settings: NetworkIntelligenceSettings) {
    historyStore.configure(
        isTrackingEnabled: settings.isHistoryTrackingEnabled,
        retentionDays: settings.historyRetentionDays
    )
    syncIntelligenceSummaryFromHistory()
}
```

In `Sources/NetBar/StatusBarController.swift`, call it from `handleNetworkIntelligenceUpdate()` before detecting anomalies:

```swift
monitor.configureHistory(settings: settings)
```

Add a sink in `configureObservers()` so preference changes take effect without waiting for new traffic:

```swift
appPreferences.$networkIntelligenceSettings
    .sink { [weak self] settings in
        self?.monitor.configureHistory(settings: settings)
        self?.requestRender()
    }
    .store(in: &cancellables)
```

- [ ] **Step 6: Run history tests and monitor tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistory
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryPresentation
swift test --filter SystemResourceTests/testNetworkMonitorUpdatesNetworkIntelligenceSummary
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/NetworkHistoryPresentation.swift Sources/NetBar/NetworkHistoryStore.swift Sources/NetBar/NetworkMonitor.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/NetworkIntelligenceModels.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: extend network history ledger"
```

---

### Task 3: Network Insight Stream

**Files:**
- Create: `Sources/NetBar/NetworkInsightCenter.swift`
- Modify: `Sources/NetBar/NetworkIntelligenceModels.swift`
- Modify: `Sources/NetBar/NetworkMonitor.swift`
- Modify: `Sources/NetBar/NetworkIntelligenceCoordinator.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing insight tests**

Add these tests after the anomaly detector tests.

```swift
func testNetworkInsightCenterCreatesReadableCardForHighTraffic() {
    var center = NetworkInsightCenter()
    let event = NetworkAnomalyEvent(
        kind: .highTraffic,
        severity: .warning,
        title: "High traffic",
        message: "Current total speed is about 11.0 MB/s.",
        timestamp: Date(timeIntervalSince1970: 100),
        applicationName: "Arc",
        bytesPerSecond: 11_000_000,
        cooldownKey: "highTraffic"
    )

    let cards = center.ingest(
        events: [event],
        settings: .default,
        language: .english
    )

    XCTAssertEqual(cards.count, 1)
    XCTAssertEqual(cards.first?.kind, .highTraffic)
    XCTAssertEqual(cards.first?.applicationName, "Arc")
    XCTAssertTrue(cards.first?.suggestion.contains("Activity Monitor") == true)
}

func testNetworkInsightCenterSuppressesDuplicateCooldownCards() {
    var center = NetworkInsightCenter()
    let first = NetworkAnomalyEvent(
        kind: .networkDrop,
        severity: .critical,
        title: "Network drop",
        message: "Network activity dropped.",
        timestamp: Date(timeIntervalSince1970: 100),
        cooldownKey: "networkDrop"
    )
    let second = NetworkAnomalyEvent(
        kind: .networkDrop,
        severity: .critical,
        title: "Network drop",
        message: "Network activity dropped again.",
        timestamp: Date(timeIntervalSince1970: 120),
        cooldownKey: "networkDrop"
    )

    _ = center.ingest(events: [first], settings: .default, language: .english)
    let cards = center.ingest(events: [second], settings: .default, language: .english)

    XCTAssertEqual(cards.count, 1)
    XCTAssertEqual(cards.first?.message, "Network activity dropped.")
}

func testNetworkInsightCenterRespectsDisabledStream() {
    var center = NetworkInsightCenter()
    var settings = NetworkIntelligenceSettings.default
    settings.isInsightStreamEnabled = false
    let event = NetworkAnomalyEvent(
        kind: .proxyAttributionGap,
        severity: .info,
        title: "Proxy attribution gap",
        message: "Traffic may be concentrated in a proxy process.",
        timestamp: Date(timeIntervalSince1970: 100),
        cooldownKey: "proxyAttributionGap"
    )

    let cards = center.ingest(events: [event], settings: settings, language: .english)

    XCTAssertTrue(cards.isEmpty)
}
```

- [ ] **Step 2: Run insight tests and confirm failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkInsightCenter
```

Expected: FAIL because `NetworkInsightCenter` and `NetworkInsightCard` do not exist.

- [ ] **Step 3: Add insight card model**

In `Sources/NetBar/NetworkIntelligenceModels.swift`, add:

```swift
struct NetworkInsightCard: Equatable, Identifiable {
    let id: UUID
    let kind: NetworkAnomalyKind
    let severity: NetworkAnomalySeverity
    let title: String
    let message: String
    let suggestion: String
    let timestamp: Date
    let applicationName: String?
    let cooldownKey: String

    init(
        id: UUID = UUID(),
        kind: NetworkAnomalyKind,
        severity: NetworkAnomalySeverity,
        title: String,
        message: String,
        suggestion: String,
        timestamp: Date,
        applicationName: String?,
        cooldownKey: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.message = message
        self.suggestion = suggestion
        self.timestamp = timestamp
        self.applicationName = applicationName
        self.cooldownKey = cooldownKey
    }
}
```

Extend `NetworkIntelligenceSummary`:

```swift
var insightCards: [NetworkInsightCard]
```

Update every `NetworkIntelligenceSummary(...)` construction by adding:

```swift
insightCards: []
```

When syncing history into the monitor later in this task, preserve existing cards.

- [ ] **Step 4: Create insight center**

Create `Sources/NetBar/NetworkInsightCenter.swift`:

```swift
import Foundation

struct NetworkInsightCenter {
    private var cards: [NetworkInsightCard] = []
    private var lastCardAtByCooldownKey: [String: Date] = [:]
    private let duplicateWindow: TimeInterval = 3 * 60

    mutating func ingest(
        events: [NetworkAnomalyEvent],
        settings: NetworkIntelligenceSettings,
        language: AppLanguage
    ) -> [NetworkInsightCard] {
        guard settings.isInsightStreamEnabled else {
            cards.removeAll()
            lastCardAtByCooldownKey.removeAll()
            return []
        }

        for event in events {
            if let last = lastCardAtByCooldownKey[event.cooldownKey],
               event.timestamp.timeIntervalSince(last) < duplicateWindow {
                continue
            }
            lastCardAtByCooldownKey[event.cooldownKey] = event.timestamp
            cards.insert(card(for: event, settings: settings, language: language), at: 0)
        }

        let limit = max(settings.insightRetentionLimit, 1)
        cards = Array(cards.prefix(limit))
        return cards
    }

    private func card(
        for event: NetworkAnomalyEvent,
        settings: NetworkIntelligenceSettings,
        language: AppLanguage
    ) -> NetworkInsightCard {
        NetworkInsightCard(
            kind: event.kind,
            severity: event.severity,
            title: event.title,
            message: event.message,
            suggestion: settings.isInsightSuggestionEnabled ? suggestion(for: event, language: language) : "",
            timestamp: event.timestamp,
            applicationName: event.applicationName,
            cooldownKey: event.cooldownKey
        )
    }

    private func suggestion(for event: NetworkAnomalyEvent, language: AppLanguage) -> String {
        switch event.kind {
        case .highTraffic:
            return language.text(
                "可以打开活动监视器或 NetBar 应用排行确认是否为预期下载、同步或视频流量。",
                "Open Activity Monitor or NetBar app ranking to confirm whether this is expected download, sync, or streaming traffic."
            )
        case .applicationSpike:
            let app = event.applicationName ?? language.text("该应用", "that app")
            return language.text(
                "如果不是预期行为，可以检查 \(app) 是否正在同步、更新或后台下载。",
                "If this is unexpected, check whether \(app) is syncing, updating, or downloading in the background."
            )
        case .networkDrop:
            return language.text(
                "可以检查 Wi-Fi、代理/VPN、路由器或系统网络设置。",
                "Check Wi-Fi, proxy/VPN, router, or macOS network settings."
            )
        case .networkRecovered:
            return language.text(
                "网络活动已恢复，可以继续观察是否再次波动。",
                "Network activity recovered. Keep watching for repeated drops."
            )
        case .proxyAttributionGap:
            return language.text(
                "应用流量可能集中在代理、VPN 或网络扩展进程中。",
                "Traffic may be concentrated in a proxy, VPN, or network extension process."
            )
        }
    }
}
```

- [ ] **Step 5: Integrate insight cards in monitor**

In `Sources/NetBar/NetworkMonitor.swift`, add:

```swift
private var insightCenter = NetworkInsightCenter()
```

Update `refreshIntelligence(settings:language:)`:

```swift
let cards = insightCenter.ingest(
    events: events,
    settings: settings,
    language: language
)
if let latest = events.last {
    intelligenceSummary.latestEvent = latest
}
intelligenceSummary.insightCards = cards
return events
```

Update `syncIntelligenceSummaryFromHistory()` to preserve insights:

```swift
private func syncIntelligenceSummaryFromHistory() {
    var summary = historyStore.summary
    summary.latestEvent = intelligenceSummary.latestEvent
    summary.insightCards = intelligenceSummary.insightCards
    intelligenceSummary = summary
}
```

- [ ] **Step 6: Run insight and monitor tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkInsightCenter
swift test --filter SystemResourceTests/testNetworkMonitorRefreshIntelligenceStoresLatestEvent
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/NetworkInsightCenter.swift Sources/NetBar/NetworkIntelligenceModels.swift Sources/NetBar/NetworkMonitor.swift Sources/NetBar/NetworkIntelligenceCoordinator.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: add network insight stream"
```

---

### Task 4: Smart Menu Bar Evaluator and Rendering Hook

**Files:**
- Create: `Sources/NetBar/StatusBarContextEvaluator.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Modify: `Sources/NetBar/StatusBarStyle.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing smart menu bar tests**

Add these tests near the existing status bar tests.

```swift
func testStatusBarContextEvaluatorFallsBackToManualWhenDisabled() {
    var settings = NetworkIntelligenceSettings.default
    settings.isSmartStatusBarModeEnabled = false
    let context = StatusBarContextEvaluator.evaluate(
        snapshot: sampleSnapshot(download: 20_000_000, upload: 1_000_000),
        appTraffic: .empty,
        intelligenceSummary: .empty,
        settings: settings,
        language: .english
    )

    XCTAssertEqual(context.emphasis, .manual)
    XCTAssertNil(context.trafficDisplayModeOverride)
}

func testStatusBarContextEvaluatorPrioritizesAnomaly() {
    var settings = NetworkIntelligenceSettings.default
    settings.isSmartStatusBarModeEnabled = true
    let event = NetworkAnomalyEvent(
        kind: .networkDrop,
        severity: .critical,
        title: "Network drop",
        message: "Network activity dropped.",
        timestamp: Date(timeIntervalSince1970: 10),
        cooldownKey: "networkDrop"
    )
    let summary = NetworkIntelligenceSummary(
        latestEvent: event,
        today: .empty(dateKey: "2026-06-12"),
        recentDays: [],
        realtimeTopApplications: [],
        todayTopApplications: [],
        animationPlaybackCountsByCharacter: [:],
        insightCards: []
    )

    let context = StatusBarContextEvaluator.evaluate(
        snapshot: sampleSnapshot(download: 0, upload: 0),
        appTraffic: .empty,
        intelligenceSummary: summary,
        settings: settings,
        language: .english
    )

    XCTAssertEqual(context.emphasis, .anomaly(.networkDrop))
    XCTAssertEqual(context.overrideLine, "! Network drop")
}

func testStatusBarContextEvaluatorShortensTopApplicationName() {
    var settings = NetworkIntelligenceSettings.default
    settings.isSmartStatusBarModeEnabled = true
    let appTraffic = ApplicationTrafficState(
        timestamp: Date(timeIntervalSince1970: 10),
        applications: [appRate("VeryLongApplicationNameThatWouldOverflow", download: 8_000_000, upload: 500_000)],
        sampleCount: 1,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    )

    let context = StatusBarContextEvaluator.evaluate(
        snapshot: sampleSnapshot(download: 8_000_000, upload: 500_000),
        appTraffic: appTraffic,
        intelligenceSummary: .empty,
        settings: settings,
        language: .english
    )

    XCTAssertEqual(context.emphasis, .topApplication("VeryLongA..."))
    XCTAssertEqual(context.overrideLine, "VeryLongA...")
}
```

- [ ] **Step 2: Run smart menu bar tests and confirm failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarContextEvaluator
```

Expected: FAIL because evaluator types do not exist.

- [ ] **Step 3: Add evaluator**

Create `Sources/NetBar/StatusBarContextEvaluator.swift`:

```swift
import Foundation

enum SmartStatusBarEmphasis: Equatable {
    case manual
    case anomaly(NetworkAnomalyKind)
    case upload
    case totalTraffic
    case topApplication(String)
}

struct SmartStatusBarContext: Equatable {
    let emphasis: SmartStatusBarEmphasis
    let trafficDisplayModeOverride: StatusBarTrafficDisplayMode?
    let overrideLine: String?

    static let manual = SmartStatusBarContext(
        emphasis: .manual,
        trafficDisplayModeOverride: nil,
        overrideLine: nil
    )
}

enum StatusBarContextEvaluator {
    static func evaluate(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        intelligenceSummary: NetworkIntelligenceSummary,
        settings: NetworkIntelligenceSettings,
        language: AppLanguage
    ) -> SmartStatusBarContext {
        guard settings.isSmartStatusBarModeEnabled else { return .manual }

        if settings.showsSmartAnomalyMarker,
           let event = intelligenceSummary.latestEvent,
           event.severity != .info {
            return SmartStatusBarContext(
                emphasis: .anomaly(event.kind),
                trafficDisplayModeOverride: nil,
                overrideLine: "! \(event.kind.title(language: language))"
            )
        }

        if settings.showsSmartTopApplication,
           let app = topApplication(from: appTraffic),
           app.downloadBytesPerSecond + app.uploadBytesPerSecond >= 5_242_880 {
            let label = shortened(app.displayName)
            return SmartStatusBarContext(
                emphasis: .topApplication(label),
                trafficDisplayModeOverride: nil,
                overrideLine: label
            )
        }

        if snapshot.uploadBytesPerSecond >= max(snapshot.downloadBytesPerSecond * 1.5, 1_048_576) {
            return SmartStatusBarContext(
                emphasis: .upload,
                trafficDisplayModeOverride: .uploadOnly,
                overrideLine: nil
            )
        }

        if snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond >= 10_485_760 {
            return SmartStatusBarContext(
                emphasis: .totalTraffic,
                trafficDisplayModeOverride: .total,
                overrideLine: nil
            )
        }

        return .manual
    }

    private static func topApplication(from appTraffic: ApplicationTrafficState) -> ApplicationTrafficRate? {
        ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        ).first
    }

    private static func shortened(_ name: String) -> String {
        guard name.count > 12 else { return name }
        return "\(name.prefix(9))..."
    }
}
```

- [ ] **Step 4: Add renderer smart context parameters**

In `Sources/NetBar/StatusBarStyle.swift`, add to `StatusBarRenderSignature`:

```swift
let smartContext: SmartStatusBarContext
```

Update `presentation`, `signature`, `image`, `width`, and private `layout` signatures to accept:

```swift
smartContext: SmartStatusBarContext = .manual
```

Pass `smartContext` through each call chain. In `signature`, set:

```swift
smartContext: smartContext,
```

In private `layout`, replace the current `lines` block with:

```swift
let displayMode = smartContext.trafficDisplayModeOverride ?? settings.trafficDisplayMode
let lines: [String] = {
    if let overrideLine = smartContext.overrideLine {
        return [overrideLine]
    }
    switch displayMode {
    case .upDown:
        return settings.order == .uploadFirst ? [upload, download] : [download, upload]
    case .downloadOnly:
        return [download]
    case .uploadOnly:
        return [upload]
    case .total:
        return [total]
    }
}()
```

In `stableWidthTemplates(settings:)`, keep using `settings.trafficDisplayMode`; smart mode is allowed to use measured width because the override line is shortened by the evaluator.

- [ ] **Step 5: Pass context from status bar controller**

In `Sources/NetBar/StatusBarController.swift`, inside `updateStatusItem()` before computing the signature, add:

```swift
let smartContext = StatusBarContextEvaluator.evaluate(
    snapshot: monitor.snapshot,
    appTraffic: monitor.appTraffic,
    intelligenceSummary: monitor.intelligenceSummary,
    settings: appPreferences.networkIntelligenceSettings,
    language: appPreferences.resolvedLanguage
)
```

Pass `smartContext` into `StatusBarDisplayRenderer.signature(...)` and `StatusBarDisplayRenderer.image(...)`.

- [ ] **Step 6: Run status bar tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarContextEvaluator
swift test --filter PreferencesAndPresentationTests/testStatusBarTrafficDisplayModeControlsRenderedLines
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/StatusBarContextEvaluator.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/StatusBarStyle.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add smart menu bar context"
```

---

### Task 5: Diagnostics Center

**Files:**
- Create: `Sources/NetBar/DiagnosticsCenter.swift`
- Modify: `Sources/NetBar/AppUpdater.swift`
- Modify: `Sources/NetBar/NetworkMonitor.swift`
- Modify: `Sources/NetBar/NetworkHistoryStore.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing diagnostics tests**

Add to `Tests/NetBarTests/PreferencesAndPresentationTests.swift`:

```swift
func testDiagnosticsCenterBuildsPrivacySafeSummaryText() {
    let snapshot = DiagnosticsSnapshot(
        appVersion: "v0.39.0",
        bundleIdentifier: "local.codex.NetBar",
        updateStatus: "检查更新失败：network offline",
        lastCheckedAt: Date(timeIntervalSince1970: 100),
        sampling: NetworkSamplingDiagnostics(
            isRunning: true,
            isApplicationTrafficVisible: false,
            isApplicationTrafficSamplingEnabled: false,
            isPowerSaveModeEnabled: true
        ),
        notificationAuthorization: "authorized",
        historyStatus: "available",
        historyPath: "/Users/example/Library/Application Support/NetBar/NetworkHistory.json"
    )

    let text = DiagnosticsCenter.copyText(for: snapshot, language: .english)

    XCTAssertTrue(text.contains("NetBar Diagnostics"))
    XCTAssertTrue(text.contains("v0.39.0"))
    XCTAssertTrue(text.contains("powerSave=true"))
    XCTAssertFalse(text.contains("https://"))
    XCTAssertFalse(text.contains("example.com"))
}
```

Add to `Tests/NetBarTests/SystemResourceTests.swift`:

```swift
func testNetworkMonitorExposesSamplingDiagnostics() {
    let monitor = NetworkMonitor(
        reader: SequenceNetworkStatsReader(samples: [[]]),
        appTrafficReader: EmptyApplicationTrafficReader(),
        systemResourceReader: MockSystemResourceReader(
            memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUTickSample(total: 0, user: 0, system: 0, idle: 0),
            thermal: ThermalInfo(state: .nominal)
        ),
        resourceReader: MockApplicationResourceReader(processes: [])
    )

    monitor.setPowerSaveMode(true)
    let diagnostics = monitor.samplingDiagnostics

    XCTAssertFalse(diagnostics.isRunning)
    XCTAssertFalse(diagnostics.isApplicationTrafficSamplingEnabled)
    XCTAssertTrue(diagnostics.isPowerSaveModeEnabled)
}
```

- [ ] **Step 2: Run diagnostics tests and confirm failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testDiagnosticsCenterBuildsPrivacySafeSummaryText
swift test --filter SystemResourceTests/testNetworkMonitorExposesSamplingDiagnostics
```

Expected: FAIL because diagnostics types do not exist.

- [ ] **Step 3: Add diagnostics models and formatter**

Create `Sources/NetBar/DiagnosticsCenter.swift`:

```swift
import Foundation

struct NetworkSamplingDiagnostics: Equatable {
    let isRunning: Bool
    let isApplicationTrafficVisible: Bool
    let isApplicationTrafficSamplingEnabled: Bool
    let isPowerSaveModeEnabled: Bool
}

struct DiagnosticsSnapshot: Equatable {
    let appVersion: String
    let bundleIdentifier: String
    let updateStatus: String
    let lastCheckedAt: Date?
    let sampling: NetworkSamplingDiagnostics
    let notificationAuthorization: String
    let historyStatus: String
    let historyPath: String
}

enum DiagnosticsCenter {
    static func makeSnapshot(
        appVersion: String,
        bundleIdentifier: String,
        updateStatus: String,
        lastCheckedAt: Date?,
        sampling: NetworkSamplingDiagnostics,
        notificationAuthorization: String,
        historyStatus: String,
        historyPath: String
    ) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            appVersion: appVersion,
            bundleIdentifier: bundleIdentifier,
            updateStatus: updateStatus,
            lastCheckedAt: lastCheckedAt,
            sampling: sampling,
            notificationAuthorization: notificationAuthorization,
            historyStatus: historyStatus,
            historyPath: historyPath
        )
    }

    static func copyText(for snapshot: DiagnosticsSnapshot, language: AppLanguage) -> String {
        let checkedAt = snapshot.lastCheckedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "never"
        return """
        NetBar Diagnostics
        version=\(snapshot.appVersion)
        bundleIdentifier=\(snapshot.bundleIdentifier)
        updateStatus=\(snapshot.updateStatus)
        lastCheckedAt=\(checkedAt)
        isRunning=\(snapshot.sampling.isRunning)
        appTrafficVisible=\(snapshot.sampling.isApplicationTrafficVisible)
        appTrafficSampling=\(snapshot.sampling.isApplicationTrafficSamplingEnabled)
        powerSave=\(snapshot.sampling.isPowerSaveModeEnabled)
        notificationAuthorization=\(snapshot.notificationAuthorization)
        historyStatus=\(snapshot.historyStatus)
        historyPath=\(snapshot.historyPath)
        privacy=No packet contents, URLs, domains, chat contents, file contents, or payload data are included.
        """
    }
}
```

- [ ] **Step 4: Expose diagnostics from updater, monitor, and history**

In `Sources/NetBar/NetworkMonitor.swift`, add:

```swift
var samplingDiagnostics: NetworkSamplingDiagnostics {
    NetworkSamplingDiagnostics(
        isRunning: isRunning,
        isApplicationTrafficVisible: isApplicationTrafficVisible,
        isApplicationTrafficSamplingEnabled: shouldSampleApplicationTraffic,
        isPowerSaveModeEnabled: powerSaveMode
    )
}
```

In `Sources/NetBar/NetworkHistoryStore.swift`, expose:

```swift
var diagnosticsStatusText: String {
    switch storageStatus {
    case .available:
        return "available"
    case .unreadableBackupCreated(let url):
        return "unreadableBackupCreated:\(url.lastPathComponent)"
    case .writeFailed(let message):
        return "writeFailed:\(message)"
    }
}

var diagnosticsPath: String {
    fileURL.path
}
```

In `Sources/NetBar/AppUpdater.swift`, expose:

```swift
var diagnosticsStatusText: String {
    statusMessage
}

var diagnosticsBundleIdentifier: String {
    currentBundleIdentifier
}
```

- [ ] **Step 5: Run diagnostics tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testDiagnosticsCenterBuildsPrivacySafeSummaryText
swift test --filter SystemResourceTests/testNetworkMonitorExposesSamplingDiagnostics
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/DiagnosticsCenter.swift Sources/NetBar/AppUpdater.swift Sources/NetBar/NetworkMonitor.swift Sources/NetBar/NetworkHistoryStore.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: add diagnostics center"
```

---

### Task 6: Preferences and Details UI Integration

**Files:**
- Create: `Sources/NetBar/Preferences/DiagnosticsPreferencesView.swift`
- Modify: `Sources/NetBar/NetworkPopoverView.swift`
- Modify: `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`
- Modify: `Sources/NetBar/Preferences/MenuBarPreferencesView.swift`
- Modify: `Sources/NetBar/Preferences/AboutPreferencesView.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesWindowController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing presentation tests**

Add:

```swift
func testNetworkHistoryPresentationEstimateNoticeIsLocalized() {
    let presentation = NetworkHistoryPresentation.make(summary: .empty, language: .simplifiedChinese)

    XCTAssertTrue(presentation.estimateNotice.contains("本地估算值"))
}

func testNetworkInsightCardDisplayDataKeepsApplicationOptional() {
    let card = NetworkInsightCard(
        kind: .networkDrop,
        severity: .critical,
        title: "Network drop",
        message: "Network activity dropped.",
        suggestion: "Check Wi-Fi.",
        timestamp: Date(timeIntervalSince1970: 10),
        applicationName: nil,
        cooldownKey: "networkDrop"
    )

    XCTAssertNil(card.applicationName)
    XCTAssertEqual(card.title, "Network drop")
}
```

- [ ] **Step 2: Run presentation tests and confirm failure only where prior tasks are missing**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryPresentationEstimateNoticeIsLocalized
swift test --filter PreferencesAndPresentationTests/testNetworkInsightCardDisplayDataKeepsApplicationOptional
```

Expected: PASS.

- [ ] **Step 3: Add diagnostics preferences view**

Create `Sources/NetBar/Preferences/DiagnosticsPreferencesView.swift`:

```swift
import AppKit
import SwiftUI

struct DiagnosticsPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    let snapshot: DiagnosticsSnapshot

    var body: some View {
        PreferenceSection(
            title: appPreferences.text("诊断与健康", "Diagnostics & Health"),
            systemImage: "stethoscope"
        ) {
            diagnosticsRow(appPreferences.text("版本", "Version"), snapshot.appVersion)
            diagnosticsRow(appPreferences.text("Bundle ID", "Bundle ID"), snapshot.bundleIdentifier)
            diagnosticsRow(appPreferences.text("更新状态", "Update status"), snapshot.updateStatus)
            diagnosticsRow(appPreferences.text("采样状态", "Sampling"), snapshot.sampling.isRunning ? "running" : "stopped")
            diagnosticsRow(appPreferences.text("应用采样", "App sampling"), snapshot.sampling.isApplicationTrafficSamplingEnabled ? "enabled" : "paused")
            diagnosticsRow(appPreferences.text("通知权限", "Notifications"), snapshot.notificationAuthorization)
            diagnosticsRow(appPreferences.text("历史文件", "History"), snapshot.historyStatus)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    DiagnosticsCenter.copyText(for: snapshot, language: appPreferences.resolvedLanguage),
                    forType: .string
                )
            } label: {
                Label(appPreferences.text("复制诊断摘要", "Copy Diagnostics"), systemImage: "doc.on.doc")
            }

            Text(appPreferences.text(
                "诊断摘要不包含网络内容、URL、域名、聊天内容或文件内容。",
                "Diagnostics do not include network contents, URLs, domains, chat contents, or file contents."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func diagnosticsRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
```

- [ ] **Step 4: Add preference controls**

In `IntelligencePreferencesView`, extend `historySection` with:

```swift
Stepper(
    value: settingsBinding(\.historyRetentionDays),
    in: 7...30,
    step: 1
) {
    Text(appPreferences.text("历史保留 \(appPreferences.networkIntelligenceSettings.historyRetentionDays) 天", "Keep \(appPreferences.networkIntelligenceSettings.historyRetentionDays) days"))
}

Toggle(
    appPreferences.text("洞察事件流", "Insight stream"),
    isOn: settingsBinding(\.isInsightStreamEnabled)
)

Toggle(
    appPreferences.text("洞察建议", "Insight suggestions"),
    isOn: settingsBinding(\.isInsightSuggestionEnabled)
)

Toggle(
    appPreferences.text("应用累计排行", "Application ranking"),
    isOn: settingsBinding(\.isApplicationHistoryRankingEnabled)
)
```

In `MenuBarPreferencesView`, add a small section after Presets:

```swift
PreferenceSection(
    title: appPreferences.text("智能菜单栏", "Smart Menu Bar"),
    systemImage: "bolt.badge.automatic"
) {
    Toggle(
        appPreferences.text("启用智能菜单栏模式", "Enable smart menu bar mode"),
        isOn: intelligenceBinding(\.isSmartStatusBarModeEnabled)
    )
    Toggle(
        appPreferences.text("异常状态标识", "Anomaly marker"),
        isOn: intelligenceBinding(\.showsSmartAnomalyMarker)
    )
    Toggle(
        appPreferences.text("Top 应用提示", "Top app hint"),
        isOn: intelligenceBinding(\.showsSmartTopApplication)
    )
}
```

Add this helper to `MenuBarPreferencesView`:

```swift
private func intelligenceBinding<Value>(
    _ keyPath: WritableKeyPath<NetworkIntelligenceSettings, Value>
) -> Binding<Value> {
    Binding(
        get: { appPreferences.networkIntelligenceSettings[keyPath: keyPath] },
        set: { newValue in
            var copy = appPreferences.networkIntelligenceSettings
            copy[keyPath: keyPath] = newValue
            appPreferences.networkIntelligenceSettings = copy
        }
    )
}
```

- [ ] **Step 5: Add details sections**

In `NetworkPopoverView`, add a compact section near the existing intelligence cards:

```swift
private var insightStreamSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(preferences.text("洞察事件", "Insights"))
            .font(.system(size: 13, weight: .bold))

        if monitor.intelligenceSummary.insightCards.isEmpty {
            Text(preferences.text("暂无新的洞察事件。", "No new insights."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else {
            ForEach(monitor.intelligenceSummary.insightCards.prefix(5)) { card in
                VStack(alignment: .leading, spacing: 3) {
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
                .padding(8)
                .netBarCard(cornerRadius: 8, padding: 0)
            }
        }
    }
}
```

Add a history ledger section using `NetworkHistoryPresentation.make(summary:language:)` and `ByteFormat.bytes`.

```swift
private var historyLedgerSection: some View {
    let presentation = NetworkHistoryPresentation.make(
        summary: monitor.intelligenceSummary,
        language: preferences.resolvedLanguage
    )

    return VStack(alignment: .leading, spacing: 8) {
        Text(preferences.text("历史账本", "Traffic Ledger"))
            .font(.system(size: 13, weight: .bold))

        HStack(spacing: 8) {
            historyMetricCard(
                title: preferences.text("今日", "Today"),
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
            Text("\(preferences.text("峰值下载", "Peak download")) \(peak.dateKey): \(ByteFormat.speed(peak.downloadBytesPerSecond))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }

        if presentation.applicationRanking.isEmpty {
            Text(preferences.text("暂无应用累计排行。", "No application ranking yet."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            ForEach(presentation.applicationRanking.prefix(5)) { app in
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

        Text(presentation.estimateNotice)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
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
    .padding(8)
    .netBarCard(cornerRadius: 8, padding: 0)
}
```

- [ ] **Step 6: Add diagnostics to About preferences**

Update `AboutPreferencesView` to accept a `DiagnosticsSnapshot`:

```swift
let diagnosticsSnapshot: DiagnosticsSnapshot
```

Render after `softwareUpdateSection`:

```swift
DiagnosticsPreferencesView(
    appPreferences: appPreferences,
    snapshot: diagnosticsSnapshot
)
```

Update `PreferencesWindowController` to receive a diagnostics snapshot provider:

```swift
private let diagnosticsSnapshot: () -> DiagnosticsSnapshot
```

Add this initializer parameter:

```swift
diagnosticsSnapshot: @escaping () -> DiagnosticsSnapshot
```

Assign it:

```swift
self.diagnosticsSnapshot = diagnosticsSnapshot
```

Pass the closure into `PreferencesView`:

```swift
PreferencesView(
    settings: settings,
    appPreferences: appPreferences,
    customCharacterStore: customCharacterStore,
    historyStore: historyStore,
    updater: updater,
    notificationController: notificationController,
    diagnosticsSnapshot: diagnosticsSnapshot,
    clearNetworkHistory: clearNetworkHistory
)
```

Add the same stored property to `PreferencesView`:

```swift
let diagnosticsSnapshot: () -> DiagnosticsSnapshot
```

Update the About tab:

```swift
AboutPreferencesView(
    appPreferences: appPreferences,
    updater: updater,
    diagnosticsSnapshot: diagnosticsSnapshot()
)
```

Update `AppDelegate.preferencesWindowController` to inject the provider:

```swift
diagnosticsSnapshot: { [weak self] in
    guard let self else {
        return DiagnosticsCenter.makeSnapshot(
            appVersion: "v0.0.0",
            bundleIdentifier: "local.codex.NetBar",
            updateStatus: "unavailable",
            lastCheckedAt: nil,
            sampling: NetworkSamplingDiagnostics(
                isRunning: false,
                isApplicationTrafficVisible: false,
                isApplicationTrafficSamplingEnabled: false,
                isPowerSaveModeEnabled: false
            ),
            notificationAuthorization: "unknown",
            historyStatus: "unknown",
            historyPath: ""
        )
    }
    return DiagnosticsCenter.makeSnapshot(
        appVersion: self.updater.currentVersionText,
        bundleIdentifier: self.updater.diagnosticsBundleIdentifier,
        updateStatus: self.updater.diagnosticsStatusText,
        lastCheckedAt: self.updater.lastCheckedAt,
        sampling: self.statusBarController?.samplingDiagnostics ?? NetworkSamplingDiagnostics(
            isRunning: false,
            isApplicationTrafficVisible: false,
            isApplicationTrafficSamplingEnabled: false,
            isPowerSaveModeEnabled: false
        ),
        notificationAuthorization: self.notificationController.authorizationStatus.title(language: self.appPreferences.resolvedLanguage),
        historyStatus: self.networkHistoryStore.diagnosticsStatusText,
        historyPath: self.networkHistoryStore.diagnosticsPath
    )
}
```

Expose the sampling diagnostics through `StatusBarController`:

```swift
var samplingDiagnostics: NetworkSamplingDiagnostics {
    monitor.samplingDiagnostics
}
```

- [ ] **Step 7: Run UI compile checks**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryPresentationEstimateNoticeIsLocalized
swift test --filter PreferencesAndPresentationTests/testNetworkInsightCardDisplayDataKeepsApplicationOptional
```

Expected: PASS and the target compiles.

- [ ] **Step 8: Commit**

```bash
git add Sources/NetBar/Preferences/DiagnosticsPreferencesView.swift Sources/NetBar/NetworkPopoverView.swift Sources/NetBar/Preferences/IntelligencePreferencesView.swift Sources/NetBar/Preferences/MenuBarPreferencesView.swift Sources/NetBar/Preferences/AboutPreferencesView.swift Sources/NetBar/Preferences/PreferencesWindowController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: surface v0.39 product controls"
```

---

### Task 7: Pet Activity Level and Feedback Controls

**Files:**
- Modify: `Sources/NetBar/PetState.swift`
- Modify: `Sources/NetBar/PetController.swift`
- Modify: `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing pet tests**

Add near existing pet tests:

```swift
func testPetStateDefaultsIncludeActivityLevel() {
    let state = PetState.default(now: Date(timeIntervalSince1970: 10))

    XCTAssertEqual(state.activityLevel, .idle)
}

func testPetControllerUpdatesActivityLevelFromDailySummary() {
    let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
    controller.updateSettings {
        $0.isEnabled = true
        $0.isPetActivityLevelEnabled = true
    }
    let summary = NetworkDailySummary(
        dateKey: "2026-06-12",
        downloadBytes: 30_000_000_000,
        uploadBytes: 5_000_000_000,
        peakDownloadBytesPerSecond: 20_000_000,
        peakUploadBytesPerSecond: 2_000_000,
        sampleCount: 100,
        activeSeconds: 3_600,
        topApplications: []
    )

    controller.observe(todaySummary: summary)

    XCTAssertEqual(controller.state.activityLevel, .heavy)
}

func testPetControllerCanDisableMoodFeedbackForAnomalies() {
    let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
    controller.updateSettings {
        $0.isEnabled = true
        $0.isPetMoodFeedbackEnabled = false
    }
    let event = NetworkAnomalyEvent(
        kind: .networkDrop,
        severity: .critical,
        title: "Network drop",
        message: "Network activity dropped.",
        timestamp: Date(timeIntervalSince1970: 100),
        cooldownKey: "networkDrop"
    )

    controller.observe(anomaly: event)

    XCTAssertNil(controller.latestCue)
    XCTAssertEqual(controller.state.mood, .happy)
}
```

- [ ] **Step 2: Run pet tests and confirm failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetStateDefaultsIncludeActivityLevel
swift test --filter PreferencesAndPresentationTests/testPetControllerUpdatesActivityLevelFromDailySummary
swift test --filter PreferencesAndPresentationTests/testPetControllerCanDisableMoodFeedbackForAnomalies
```

Expected: FAIL because activity level and feedback settings do not exist.

- [ ] **Step 3: Extend pet models**

In `Sources/NetBar/PetState.swift`, add:

```swift
enum PetActivityLevel: String, Codable, CaseIterable, Identifiable {
    case idle
    case light
    case active
    case heavy

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .idle:
            return language.text("空闲", "Idle")
        case .light:
            return language.text("轻度", "Light")
        case .active:
            return language.text("活跃", "Active")
        case .heavy:
            return language.text("高活跃", "Heavy")
        }
    }
}
```

Extend `PetSettings`:

```swift
var isPetMoodFeedbackEnabled: Bool
var isPetActivityLevelEnabled: Bool
```

Update `.default`:

```swift
isPetMoodFeedbackEnabled: true,
isPetActivityLevelEnabled: true
```

Extend `PetState`:

```swift
var activityLevel: PetActivityLevel
```

Add it to `PetState.init(...)`, `.default(now:)`, `CodingKeys`, decoder fallback, and encoder through the existing Codable extension.

- [ ] **Step 4: Respect feedback settings in controller**

In `PetController.observe(anomaly:)`, replace the start of the method with:

```swift
guard settings.isEnabled, settings.isPetMoodFeedbackEnabled else { return }
```

In `PetController.observe(todaySummary:)`, add activity mapping:

```swift
if settings.isPetActivityLevelEnabled {
    state.activityLevel = activityLevel(for: summary)
}
```

Add helper:

```swift
private func activityLevel(for summary: NetworkDailySummary) -> PetActivityLevel {
    if summary.totalBytes >= 30_000_000_000 || summary.activeSeconds >= 3_600 {
        return .heavy
    }
    if summary.totalBytes >= 5_000_000_000 || summary.activeSeconds >= 900 {
        return .active
    }
    if summary.totalBytes > 0 || summary.activeSeconds > 0 {
        return .light
    }
    return .idle
}
```

- [ ] **Step 5: Add preference toggles**

In `IntelligencePreferencesView`, add a pet section:

```swift
PreferenceSection(
    title: appPreferences.text("宠物反馈", "Pet Feedback"),
    systemImage: "face.smiling"
) {
    Toggle(
        appPreferences.text("心情反馈", "Mood feedback"),
        isOn: petSettingBinding(\.isPetMoodFeedbackEnabled)
    )
    Toggle(
        appPreferences.text("活跃等级", "Activity level"),
        isOn: petSettingBinding(\.isPetActivityLevelEnabled)
    )
}
```

Pass `PetController` into preferences explicitly.

In `PreferencesWindowController`, add:

```swift
private let petController: PetController
```

Add this initializer parameter and assignment:

```swift
petController: PetController
self.petController = petController
```

Pass it into `PreferencesView`, then into `IntelligencePreferencesView`:

```swift
IntelligencePreferencesView(
    appPreferences: appPreferences,
    notificationController: notificationController,
    petController: petController,
    clearHistory: clearNetworkHistory
)
```

In `IntelligencePreferencesView`, add:

```swift
@ObservedObject var petController: PetController
```

Add a pet settings binding helper:

```swift
private func petSettingBinding<Value>(
    _ keyPath: WritableKeyPath<PetSettings, Value>
) -> Binding<Value> {
    Binding(
        get: { petController.settings[keyPath: keyPath] },
        set: { newValue in
            petController.updateSettings { settings in
                settings[keyPath: keyPath] = newValue
            }
        }
    )
}
```

Update `AppDelegate.preferencesWindowController` to pass:

```swift
petController: petController,
```

- [ ] **Step 6: Run pet tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPet
```

Expected: PASS for all pet tests.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/PetState.swift Sources/NetBar/PetController.swift Sources/NetBar/Preferences/IntelligencePreferencesView.swift Sources/NetBar/Preferences/PreferencesWindowController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet activity feedback"
```

---

### Task 8: Final Integration, Changelog, and Verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: any files touched by compile fixes from Tasks 1-7

- [ ] **Step 1: Run focused test groups**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkInsightCenter
swift test --filter PreferencesAndPresentationTests/testStatusBarContextEvaluator
swift test --filter PreferencesAndPresentationTests/testNetworkHistory
swift test --filter PreferencesAndPresentationTests/testDiagnosticsCenter
swift test --filter PreferencesAndPresentationTests/testPet
swift test --filter SystemResourceTests/testNetworkMonitor
```

Expected: PASS.

- [ ] **Step 2: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 3: Build app bundle**

Run:

```bash
./Scripts/build-app.sh
```

Expected: exits 0 and creates `build/NetBar.app`.

- [ ] **Step 4: Update changelog**

Add this entry at the top of `CHANGELOG.md`:

```markdown
## v0.39.0 (2026-06-12)

### Enhancement — 产品全能增强

- 新增洞察事件流，用可读文案解释高流量、应用突增、断流/恢复和代理/VPN 归因差异
- 新增智能菜单栏模式，可按当前网络状态突出异常、上传、总流量或 Top 应用
- 历史统计扩展为最近 30 天本地估算账本，包含峰值和应用累计排行
- 新增诊断与健康摘要，便于排查更新、采样、通知权限和历史文件状态
- 宠物系统新增活跃等级和可配置的网络状态反馈
```

- [ ] **Step 5: Run final verification after changelog**

Run:

```bash
swift test
./Scripts/build-app.sh
```

Expected: both commands PASS.

- [ ] **Step 6: Inspect git diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only v0.39 implementation files and `CHANGELOG.md` are modified.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar Tests/NetBarTests CHANGELOG.md
git commit -m "feat: deliver v0.39 product enhancements"
```
