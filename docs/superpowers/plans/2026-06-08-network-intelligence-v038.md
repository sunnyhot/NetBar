# Network Intelligence v0.38 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build NetBar v0.38.0 as a single Network Intelligence release with anomaly detection, today/7-day history, realtime and today app Top, notification onboarding, built-in menu bar presets, and lightweight pet intelligence.

**Architecture:** Keep sampling in `NetworkMonitor`, move intelligence into focused model/controller files, and feed a UI-ready `NetworkIntelligenceSummary` into existing SwiftUI views. Persist larger history data as JSON, keep small preferences in `UserDefaults`, and keep notification and pet side effects outside the detector.

**Tech Stack:** Swift 5 mode, AppKit, SwiftUI, Combine, UserNotifications, Foundation JSON persistence, XCTest, SPM.

---

## Source Spec

Design reference:

- `docs/superpowers/specs/2026-06-08-network-intelligence-v038-design.md`

Current branch note:

- The design spec is committed locally at `8db5c00`.
- Local `main` is ahead of `origin/main` by the design-spec commit when this plan starts. Do not rewrite or discard that commit.

## File Structure

Create focused files:

- `Sources/NetBar/NetworkIntelligenceModels.swift`
  - `NetworkDailySummary`, `ApplicationDailyUsage`, `NetworkAnomalyEvent`, `NetworkAnomalyKind`, `NetworkAnomalySeverity`, `NetworkIntelligenceSettings`, `NetworkIntelligenceSummary`, and small helper enums.
- `Sources/NetBar/NetworkHistoryStore.swift`
  - JSON persistence, date rollover, daily interface totals, app daily usage, 7-day retention.
- `Sources/NetBar/NetworkAnomalyDetector.swift`
  - Stateless input/output API with internal sustained-state and cooldown tracking.
- `Sources/NetBar/NetworkNotificationController.swift`
  - UserNotifications authorization, notification status, cooldown checks, send method.
- `Sources/NetBar/NetworkIntelligenceCoordinator.swift`
  - Small app-level side-effect coordinator that forwards anomaly events to notifications and pet cues.
- `Sources/NetBar/MenuBarPreset.swift`
  - Built-in presets and `StatusBarSettings` matching/apply helpers.
- `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`
  - Intelligence preferences tab sections.

Modify existing files:

- `Sources/NetBar/AppPreferences.swift`
  - Add intelligence preferences and persistence keys.
- `Sources/NetBar/ApplicationTrafficPresentation.swift`
  - Make `ApplicationAttributionRole` `Codable` so persisted app daily usage can store attribution roles safely.
- `Sources/NetBar/NetworkMonitor.swift`
  - Own history store, anomaly detector, and published intelligence summary.
- `Sources/NetBar/NetworkPopoverView.swift`
  - Add anomaly card, today summary, app Top, and 7-day collapsible summary.
- `Sources/NetBar/Preferences/PreferencesWindowController.swift`
  - Add Intelligence tab.
- `Sources/NetBar/Preferences/MenuBarPreferencesView.swift`
  - Add menu bar preset picker near the top of the menu bar preferences.
- `Sources/NetBar/PetController.swift`
  - Add anomaly cue handling and daily activity mood helper.
- `Sources/NetBar/PetState.swift`
  - Add anomaly cue kind or reuse existing cue kind with network-specific messages.
- `Sources/NetBar/AppDelegate.swift`
  - Own `NetworkNotificationController` and `PetController`, then pass them into `StatusBarController` and preferences.
- `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
  - Add model, detector, history, menu preset, UI presentation helper, and pet tests.
- `Tests/NetBarTests/SystemResourceTests.swift`
  - Add `NetworkMonitor` integration tests and `NetworkIntelligenceCoordinator` tests.
- `Resources/Info.plist`
  - Update version to `0.38.0` at release time.
- `CHANGELOG.md`
  - Add `v0.38.0` notes at release time.
- `README.md`
  - Document intelligent alerts, estimates, and notification permissions at release time.

## Task 1: Intelligence Models And Preferences

**Files:**
- Create: `Sources/NetBar/NetworkIntelligenceModels.swift`
- Modify: `Sources/NetBar/AppPreferences.swift`
- Modify: `Sources/NetBar/ApplicationTrafficPresentation.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing model and preference tests**

Add these tests to `PreferencesAndPresentationTests` near the existing preference model tests:

```swift
func testNetworkIntelligenceSettingsDefaultsAreConservative() {
    let settings = NetworkIntelligenceSettings.default

    XCTAssertTrue(settings.isAnomalyDetectionEnabled)
    XCTAssertFalse(settings.isSystemNotificationEnabled)
    XCTAssertEqual(settings.highTrafficThreshold, .mbps10)
    XCTAssertTrue(settings.isApplicationSpikeAlertEnabled)
    XCTAssertTrue(settings.isNetworkDropAlertEnabled)
    XCTAssertTrue(settings.isProxyAttributionAlertEnabled)
    XCTAssertTrue(settings.isHistoryTrackingEnabled)
}

func testAppPreferencesPersistNetworkIntelligenceSettings() {
    let defaults = isolatedDefaults()
    let preferences = AppPreferences(defaults: defaults, loginItemManager: FakeLoginItemManager())

    preferences.networkIntelligenceSettings = NetworkIntelligenceSettings(
        hasSeenNotificationOnboarding: true,
        isAnomalyDetectionEnabled: false,
        isSystemNotificationEnabled: true,
        highTrafficThreshold: .mbps25,
        isApplicationSpikeAlertEnabled: false,
        isNetworkDropAlertEnabled: true,
        isProxyAttributionAlertEnabled: false,
        isHistoryTrackingEnabled: true
    )

    let reloaded = AppPreferences(defaults: defaults, loginItemManager: FakeLoginItemManager())

    XCTAssertEqual(reloaded.networkIntelligenceSettings.highTrafficThreshold, .mbps25)
    XCTAssertTrue(reloaded.networkIntelligenceSettings.hasSeenNotificationOnboarding)
    XCTAssertFalse(reloaded.networkIntelligenceSettings.isAnomalyDetectionEnabled)
    XCTAssertTrue(reloaded.networkIntelligenceSettings.isSystemNotificationEnabled)
    XCTAssertFalse(reloaded.networkIntelligenceSettings.isApplicationSpikeAlertEnabled)
    XCTAssertTrue(reloaded.networkIntelligenceSettings.isNetworkDropAlertEnabled)
    XCTAssertFalse(reloaded.networkIntelligenceSettings.isProxyAttributionAlertEnabled)
    XCTAssertTrue(reloaded.networkIntelligenceSettings.isHistoryTrackingEnabled)
}

func testNetworkAnomalyEventLocalizedTitles() {
    XCTAssertEqual(NetworkAnomalyKind.highTraffic.title(language: .simplifiedChinese), "高流量")
    XCTAssertEqual(NetworkAnomalyKind.applicationSpike.title(language: .english), "Application spike")
    XCTAssertEqual(NetworkAnomalyKind.networkDrop.title(language: .simplifiedChinese), "网络断流")
    XCTAssertEqual(NetworkAnomalyKind.networkRecovered.title(language: .english), "Network recovered")
    XCTAssertEqual(NetworkAnomalyKind.proxyAttributionGap.title(language: .simplifiedChinese), "代理归因差异")
}

func testApplicationDailyUsageCodablePreservesRole() throws {
    let usage = ApplicationDailyUsage(
        applicationID: "com.example.proxy",
        displayName: "Example Proxy",
        processNames: ["Example Proxy", "proxy-helper"],
        downloadBytes: 4_096,
        uploadBytes: 2_048,
        lastSeenAt: Date(timeIntervalSince1970: 1_717_200_000),
        role: .proxyOrVPN
    )

    let data = try JSONEncoder().encode(usage)
    let decoded = try JSONDecoder().decode(ApplicationDailyUsage.self, from: data)

    XCTAssertEqual(decoded, usage)
    XCTAssertEqual(decoded.role, .proxyOrVPN)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkIntelligenceSettingsDefaultsAreConservative
```

Expected: compile failure because `NetworkIntelligenceSettings` does not exist.

- [ ] **Step 3: Add intelligence model types**

Create `Sources/NetBar/NetworkIntelligenceModels.swift`:

```swift
import Foundation

enum HighTrafficThreshold: Double, Codable, CaseIterable, Identifiable {
    case mbps5 = 5_242_880
    case mbps10 = 10_485_760
    case mbps25 = 26_214_400
    case mbps50 = 52_428_800

    var id: Double { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .mbps5: return language.text("5 MB/s", "5 MB/s")
        case .mbps10: return language.text("10 MB/s", "10 MB/s")
        case .mbps25: return language.text("25 MB/s", "25 MB/s")
        case .mbps50: return language.text("50 MB/s", "50 MB/s")
        }
    }
}

struct NetworkIntelligenceSettings: Codable, Equatable {
    var hasSeenNotificationOnboarding: Bool
    var isAnomalyDetectionEnabled: Bool
    var isSystemNotificationEnabled: Bool
    var highTrafficThreshold: HighTrafficThreshold
    var isApplicationSpikeAlertEnabled: Bool
    var isNetworkDropAlertEnabled: Bool
    var isProxyAttributionAlertEnabled: Bool
    var isHistoryTrackingEnabled: Bool

    static let `default` = NetworkIntelligenceSettings(
        hasSeenNotificationOnboarding: false,
        isAnomalyDetectionEnabled: true,
        isSystemNotificationEnabled: false,
        highTrafficThreshold: .mbps10,
        isApplicationSpikeAlertEnabled: true,
        isNetworkDropAlertEnabled: true,
        isProxyAttributionAlertEnabled: true,
        isHistoryTrackingEnabled: true
    )
}

enum NetworkAnomalySeverity: String, Codable, Equatable {
    case info
    case warning
    case critical
}

enum NetworkAnomalyKind: String, Codable, CaseIterable, Identifiable {
    case highTraffic
    case applicationSpike
    case networkDrop
    case networkRecovered
    case proxyAttributionGap

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text("高流量", "High traffic")
        case .applicationSpike:
            return language.text("应用突增", "Application spike")
        case .networkDrop:
            return language.text("网络断流", "Network drop")
        case .networkRecovered:
            return language.text("网络恢复", "Network recovered")
        case .proxyAttributionGap:
            return language.text("代理归因差异", "Proxy attribution gap")
        }
    }
}

struct NetworkAnomalyEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: NetworkAnomalyKind
    let severity: NetworkAnomalySeverity
    let title: String
    let message: String
    let timestamp: Date
    let applicationName: String?
    let bytesPerSecond: Double?
    let cooldownKey: String

    init(
        id: UUID = UUID(),
        kind: NetworkAnomalyKind,
        severity: NetworkAnomalySeverity,
        title: String,
        message: String,
        timestamp: Date,
        applicationName: String? = nil,
        bytesPerSecond: Double? = nil,
        cooldownKey: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.applicationName = applicationName
        self.bytesPerSecond = bytesPerSecond
        self.cooldownKey = cooldownKey
    }
}

struct ApplicationDailyUsage: Codable, Equatable, Identifiable {
    let applicationID: String
    var displayName: String
    var processNames: [String]
    var downloadBytes: UInt64
    var uploadBytes: UInt64
    var lastSeenAt: Date
    var role: ApplicationAttributionRole

    var id: String { applicationID }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }
}

struct NetworkDailySummary: Codable, Equatable, Identifiable {
    let dateKey: String
    var downloadBytes: UInt64
    var uploadBytes: UInt64
    var peakDownloadBytesPerSecond: Double
    var peakUploadBytesPerSecond: Double
    var sampleCount: Int
    var activeSeconds: TimeInterval
    var topApplications: [ApplicationDailyUsage]

    var id: String { dateKey }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }

    static func empty(dateKey: String) -> NetworkDailySummary {
        NetworkDailySummary(
            dateKey: dateKey,
            downloadBytes: 0,
            uploadBytes: 0,
            peakDownloadBytesPerSecond: 0,
            peakUploadBytesPerSecond: 0,
            sampleCount: 0,
            activeSeconds: 0,
            topApplications: []
        )
    }
}

struct NetworkIntelligenceSummary: Equatable {
    var latestEvent: NetworkAnomalyEvent?
    var today: NetworkDailySummary
    var recentDays: [NetworkDailySummary]
    var realtimeTopApplications: [ApplicationTrafficRate]
    var todayTopApplications: [ApplicationDailyUsage]

    static let empty = NetworkIntelligenceSummary(
        latestEvent: nil,
        today: .empty(dateKey: "1970-01-01"),
        recentDays: [],
        realtimeTopApplications: [],
        todayTopApplications: []
    )
}
```

- [ ] **Step 4: Make application attribution roles codable**

Modify `Sources/NetBar/ApplicationTrafficPresentation.swift`:

```swift
enum ApplicationAttributionRole: String, Codable, Equatable {
    case application
    case proxyOrVPN
    case helper
    case systemService

    func title(language: AppLanguage) -> String {
        switch self {
        case .application:
            return language.text("应用", "App")
        case .proxyOrVPN:
            return language.text("代理", "Proxy")
        case .helper:
            return language.text("子进程", "Helper")
        case .systemService:
            return language.text("系统", "System")
        }
    }
}
```

- [ ] **Step 5: Add `AppPreferences` persistence**

In `AppPreferences`, add:

```swift
@Published var networkIntelligenceSettings: NetworkIntelligenceSettings { didSet { save() } }
```

Initialize it in `init`:

```swift
if let data = defaults.data(forKey: Keys.networkIntelligenceSettings),
   let decoded = try? JSONDecoder().decode(NetworkIntelligenceSettings.self, from: data) {
    networkIntelligenceSettings = decoded
} else {
    networkIntelligenceSettings = Defaults.networkIntelligenceSettings
}
```

Add to `resetAppPreferences()`:

```swift
networkIntelligenceSettings = Defaults.networkIntelligenceSettings
```

Add to `save()`:

```swift
if let data = try? JSONEncoder().encode(networkIntelligenceSettings) {
    defaults.set(data, forKey: Keys.networkIntelligenceSettings)
}
```

Add keys/defaults:

```swift
static let networkIntelligenceSettings = NetworkIntelligenceSettings.default
static let networkIntelligenceSettings = "app.networkIntelligenceSettings"
```

- [ ] **Step 6: Run model tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkIntelligence
```

Expected: all new intelligence model/preference tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/NetworkIntelligenceModels.swift Sources/NetBar/AppPreferences.swift Sources/NetBar/ApplicationTrafficPresentation.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add network intelligence settings"
```

## Task 2: History Store

**Files:**
- Create: `Sources/NetBar/NetworkHistoryStore.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing history tests**

Add these tests:

```swift
func testNetworkHistoryStoreAccumulatesInterfaceDeltasForToday() throws {
    let root = try temporaryDirectory()
    let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
    let first = sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000, timestamp: Date(timeIntervalSince1970: 0))
    let second = sampleSnapshot(download: 300, upload: 200, received: 1_500, sent: 2_700, timestamp: Date(timeIntervalSince1970: 1))

    store.record(snapshot: first)
    store.record(snapshot: second)

    XCTAssertEqual(store.summary.today.downloadBytes, 500)
    XCTAssertEqual(store.summary.today.uploadBytes, 700)
    XCTAssertEqual(store.summary.today.peakDownloadBytesPerSecond, 300)
    XCTAssertEqual(store.summary.today.peakUploadBytesPerSecond, 200)
}

func testNetworkHistoryStoreRollsOverAndRetainsSevenDays() throws {
    let root = try temporaryDirectory()
    var currentDate = isoDate("2026-06-01T12:00:00Z")
    let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

    for dayOffset in 0..<9 {
        currentDate = isoDate("2026-06-\(String(format: "%02d", dayOffset + 1))T12:00:00Z")
        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: UInt64(dayOffset * 1_000 + 1_000), sent: UInt64(dayOffset * 1_000 + 2_000), timestamp: currentDate))
    }

    XCTAssertEqual(store.summary.recentDays.count, 7)
    XCTAssertEqual(store.summary.today.dateKey, "2026-06-09")
    XCTAssertEqual(store.summary.recentDays.first?.dateKey, "2026-06-02")
    XCTAssertEqual(store.summary.recentDays.last?.dateKey, "2026-06-08")
}

func testNetworkHistoryStoreAccumulatesTodayTopApplications() throws {
    let root = try temporaryDirectory()
    let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 10) })
    let apps = ApplicationTrafficState(
        applications: [
            appRate("Safari", download: 1_000, upload: 200),
            appRate("Chrome", download: 3_000, upload: 500)
        ],
        timestamp: Date(timeIntervalSince1970: 10),
        sampleCount: 1,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    )

    store.record(appTraffic: apps, interval: 2.0)

    XCTAssertEqual(store.summary.todayTopApplications.map(\.displayName), ["Chrome", "Safari"])
    XCTAssertEqual(store.summary.todayTopApplications.first?.downloadBytes, 6_000)
    XCTAssertEqual(store.summary.todayTopApplications.first?.uploadBytes, 1_000)
}
```

Add test helpers near existing helpers:

```swift
private func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func isoDate(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
}

private func appRate(_ name: String, download: Double, upload: Double) -> ApplicationTrafficRate {
    ApplicationTrafficRate(
        id: name,
        displayName: name,
        processNames: [name],
        pids: [],
        downloadBytesPerSecond: download,
        uploadBytesPerSecond: upload,
        totalReceivedBytes: 0,
        totalSentBytes: 0,
        residentMemory: nil,
        cpuPercentage: nil
    )
}
```

Add this snapshot helper in the same test file:

```swift
private func sampleSnapshot(
    timestamp: Date = Date(timeIntervalSince1970: 10),
    received: UInt64,
    sent: UInt64,
    download: Double = 0,
    upload: Double = 0
) -> NetworkSnapshot {
    NetworkSnapshot(
        timestamp: timestamp,
        interfaces: [
            InterfaceRate(
                id: "en0",
                name: "en0",
                displayName: "Wi-Fi",
                downloadBytesPerSecond: download,
                uploadBytesPerSecond: upload,
                totalReceivedBytes: received,
                totalSentBytes: sent,
                receivedPackets: 0,
                sentPackets: 0,
                isPrimary: true
            )
        ],
        downloadBytesPerSecond: download,
        uploadBytesPerSecond: upload,
        totalReceivedBytes: received,
        totalSentBytes: sent,
        sampleCount: 1
    )
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStore
```

Expected: compile failure because `NetworkHistoryStore` does not exist.

- [ ] **Step 3: Implement `NetworkHistoryStore`**

Create `Sources/NetBar/NetworkHistoryStore.swift`:

```swift
import Foundation

@MainActor
final class NetworkHistoryStore: ObservableObject {
    @Published private(set) var summary: NetworkIntelligenceSummary

    private let fileURL: URL
    private let calendar: Calendar
    private let now: () -> Date
    private var state: PersistedNetworkHistory
    private var lastSnapshot: NetworkSnapshot?
    private var encoder = JSONEncoder()
    private var decoder = JSONDecoder()

    init(
        rootDirectory: URL? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.now = now
        let root = rootDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NetBar", isDirectory: true)
        self.fileURL = root.appendingPathComponent("NetworkHistory.json")
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(PersistedNetworkHistory.self, from: data) {
            self.state = decoded
        } else {
            self.state = PersistedNetworkHistory(today: .empty(dateKey: Self.dateKey(for: now(), calendar: calendar)), recentDays: [])
        }
        self.summary = NetworkIntelligenceSummary(
            latestEvent: nil,
            today: state.today,
            recentDays: state.recentDays,
            realtimeTopApplications: [],
            todayTopApplications: state.today.topApplications
        )
    }

    func record(snapshot: NetworkSnapshot) {
        rolloverIfNeeded(for: snapshot.timestamp)
        defer { lastSnapshot = snapshot }

        guard let previous = lastSnapshot else {
            state.today.peakDownloadBytesPerSecond = max(state.today.peakDownloadBytesPerSecond, snapshot.downloadBytesPerSecond)
            state.today.peakUploadBytesPerSecond = max(state.today.peakUploadBytesPerSecond, snapshot.uploadBytesPerSecond)
            state.today.sampleCount += 1
            publishAndSave(realtimeTopApplications: summary.realtimeTopApplications)
            return
        }

        let receivedDelta = Self.positiveDelta(snapshot.totalReceivedBytes, previous.totalReceivedBytes)
        let sentDelta = Self.positiveDelta(snapshot.totalSentBytes, previous.totalSentBytes)
        let interval = max(snapshot.timestamp.timeIntervalSince(previous.timestamp), 0)

        state.today.downloadBytes += receivedDelta
        state.today.uploadBytes += sentDelta
        state.today.peakDownloadBytesPerSecond = max(state.today.peakDownloadBytesPerSecond, snapshot.downloadBytesPerSecond)
        state.today.peakUploadBytesPerSecond = max(state.today.peakUploadBytesPerSecond, snapshot.uploadBytesPerSecond)
        state.today.sampleCount += 1
        if snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond > 1_024 {
            state.today.activeSeconds += interval
        }

        publishAndSave(realtimeTopApplications: summary.realtimeTopApplications)
    }

    func record(appTraffic: ApplicationTrafficState, interval: TimeInterval) {
        guard let timestamp = appTraffic.timestamp else { return }
        rolloverIfNeeded(for: timestamp)
        var usageByID = Dictionary(uniqueKeysWithValues: state.today.topApplications.map { ($0.applicationID, $0) })

        for application in appTraffic.applications {
            let role = ApplicationTrafficPresentation.attributionRole(for: application)
            var usage = usageByID[application.id] ?? ApplicationDailyUsage(
                applicationID: application.id,
                displayName: application.displayName,
                processNames: application.processNames,
                downloadBytes: 0,
                uploadBytes: 0,
                lastSeenAt: timestamp,
                role: role
            )
            usage.displayName = application.displayName
            usage.processNames = application.processNames
            usage.downloadBytes += UInt64(max(application.downloadBytesPerSecond * interval, 0).rounded())
            usage.uploadBytes += UInt64(max(application.uploadBytesPerSecond * interval, 0).rounded())
            usage.lastSeenAt = timestamp
            usage.role = role
            usageByID[application.id] = usage
        }

        state.today.topApplications = Array(usageByID.values)
            .sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            .prefix(20)
            .map { $0 }

        let realtimeTop = ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        )
        publishAndSave(realtimeTopApplications: Array(realtimeTop.prefix(5)))
    }

    func clear() {
        state = PersistedNetworkHistory(today: .empty(dateKey: Self.dateKey(for: now(), calendar: calendar)), recentDays: [])
        lastSnapshot = nil
        publishAndSave(realtimeTopApplications: [])
    }

    private func rolloverIfNeeded(for date: Date) {
        let key = Self.dateKey(for: date, calendar: calendar)
        guard state.today.dateKey != key else { return }
        state.recentDays.append(state.today)
        state.recentDays = Array(state.recentDays.suffix(7))
        state.today = .empty(dateKey: key)
        lastSnapshot = nil
    }

    private func publishAndSave(realtimeTopApplications: [ApplicationTrafficRate]) {
        summary = NetworkIntelligenceSummary(
            latestEvent: summary.latestEvent,
            today: state.today,
            recentDays: state.recentDays,
            realtimeTopApplications: realtimeTopApplications,
            todayTopApplications: Array(state.today.topApplications.prefix(5))
        )
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal: in-memory summaries continue for this session.
        }
    }

    private static func positiveDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }
}

private struct PersistedNetworkHistory: Codable, Equatable {
    var today: NetworkDailySummary
    var recentDays: [NetworkDailySummary]
}
```

- [ ] **Step 4: Run history tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStore
```

Expected: history store tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/NetworkHistoryStore.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add network history store"
```

## Task 3: Anomaly Detector

**Files:**
- Create: `Sources/NetBar/NetworkAnomalyDetector.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing detector tests**

Add tests:

```swift
func testNetworkAnomalyDetectorEmitsHighTrafficAfterSustainedThreshold() {
    var detector = NetworkAnomalyDetector()
    let settings = NetworkIntelligenceSettings.default
    let start = Date(timeIntervalSince1970: 100)

    XCTAssertTrue(detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start), appTraffic: .empty, settings: settings, now: start).isEmpty)

    let events = detector.detect(
        snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
        appTraffic: .empty,
        settings: settings,
        now: start.addingTimeInterval(11)
    )

    XCTAssertEqual(events.map(\.kind), [.highTraffic])
}

func testNetworkAnomalyDetectorEmitsApplicationSpikeForDominantApp() {
    var detector = NetworkAnomalyDetector()
    let settings = NetworkIntelligenceSettings.default
    let start = Date(timeIntervalSince1970: 100)
    let state = ApplicationTrafficState(
        applications: [
            appRate("VideoSync", download: 6_000_000, upload: 500_000),
            appRate("Mail", download: 300_000, upload: 20_000)
        ],
        timestamp: start,
        sampleCount: 1,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    )

    _ = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start), appTraffic: state, settings: settings, now: start)
    let events = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(6)), appTraffic: state, settings: settings, now: start.addingTimeInterval(6))

    XCTAssertEqual(events.first?.kind, .applicationSpike)
    XCTAssertEqual(events.first?.applicationName, "VideoSync")
}

func testNetworkAnomalyDetectorEmitsDropAndRecoveredEvents() {
    var detector = NetworkAnomalyDetector()
    let settings = NetworkIntelligenceSettings.default
    let start = Date(timeIntervalSince1970: 100)

    _ = detector.detect(snapshot: sampleSnapshot(download: 200_000, upload: 20_000, timestamp: start), appTraffic: .empty, settings: settings, now: start)
    _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(1)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(1))
    let drop = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(10)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(10))

    XCTAssertEqual(drop.map(\.kind), [.networkDrop])

    let recovered = detector.detect(snapshot: sampleSnapshot(download: 50_000, upload: 10_000, timestamp: start.addingTimeInterval(14)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(14))

    XCTAssertEqual(recovered.map(\.kind), [.networkRecovered])
}

func testNetworkAnomalyDetectorEmitsProxyAttributionGap() {
    var detector = NetworkAnomalyDetector()
    let settings = NetworkIntelligenceSettings.default
    let now = Date(timeIntervalSince1970: 100)
    let appTraffic = ApplicationTrafficState(
        applications: [appRate("ClashX", download: 100_000, upload: 20_000)],
        timestamp: now,
        sampleCount: 1,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    )

    let events = detector.detect(snapshot: sampleSnapshot(download: 2_000_000, upload: 500_000, timestamp: now), appTraffic: appTraffic, settings: settings, now: now)

    XCTAssertEqual(events.map(\.kind), [.proxyAttributionGap])
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkAnomalyDetector
```

Expected: compile failure because `NetworkAnomalyDetector` does not exist.

- [ ] **Step 3: Implement detector**

Create `Sources/NetBar/NetworkAnomalyDetector.swift`:

```swift
import Foundation

struct NetworkAnomalyDetector {
    private var highTrafficStartedAt: Date?
    private var appSpikeStartedAtByID: [String: Date] = [:]
    private var lowTrafficStartedAt: Date?
    private var droppedState = false
    private var recentActiveSamples: [(Date, Double)] = []
    private var lastEmittedAtByCooldownKey: [String: Date] = [:]

    mutating func detect(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        settings: NetworkIntelligenceSettings,
        now: Date
    ) -> [NetworkAnomalyEvent] {
        guard settings.isAnomalyDetectionEnabled else { return [] }
        let totalSpeed = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
        recentActiveSamples.append((now, totalSpeed))
        recentActiveSamples = recentActiveSamples.filter { now.timeIntervalSince($0.0) <= 30 }

        var events: [NetworkAnomalyEvent] = []
        if let event = highTrafficEvent(totalSpeed: totalSpeed, appTraffic: appTraffic, settings: settings, now: now) {
            events.append(event)
        }
        if settings.isApplicationSpikeAlertEnabled, let event = appSpikeEvent(appTraffic: appTraffic, now: now) {
            events.append(event)
        }
        if settings.isNetworkDropAlertEnabled, let event = dropOrRecoveryEvent(totalSpeed: totalSpeed, now: now) {
            events.append(event)
        }
        if settings.isProxyAttributionAlertEnabled, let event = proxyGapEvent(snapshot: snapshot, appTraffic: appTraffic, now: now) {
            events.append(event)
        }
        return events
    }

    private mutating func highTrafficEvent(
        totalSpeed: Double,
        appTraffic: ApplicationTrafficState,
        settings: NetworkIntelligenceSettings,
        now: Date
    ) -> NetworkAnomalyEvent? {
        guard totalSpeed >= settings.highTrafficThreshold.rawValue else {
            highTrafficStartedAt = nil
            return nil
        }
        if highTrafficStartedAt == nil { highTrafficStartedAt = now }
        guard let startedAt = highTrafficStartedAt, now.timeIntervalSince(startedAt) >= 10 else { return nil }
        let key = "highTraffic"
        guard canEmit(cooldownKey: key, now: now, cooldown: 10 * 60) else { return nil }
        let top = ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        ).first
        markEmitted(cooldownKey: key, now: now)
        return NetworkAnomalyEvent(
            kind: .highTraffic,
            severity: .warning,
            title: NetworkAnomalyKind.highTraffic.title(language: .simplifiedChinese),
            message: top.map { "\($0.displayName) 当前较活跃，总速率约 \(ByteFormat.speed(totalSpeed))。" } ?? "当前总速率约 \(ByteFormat.speed(totalSpeed))。",
            timestamp: now,
            applicationName: top?.displayName,
            bytesPerSecond: totalSpeed,
            cooldownKey: key
        )
    }

    private mutating func appSpikeEvent(appTraffic: ApplicationTrafficState, now: Date) -> NetworkAnomalyEvent? {
        let apps = ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity)
        let appTotal = apps.reduce(0) { $0 + $1.downloadBytesPerSecond + $1.uploadBytesPerSecond }
        guard appTotal > 0,
              let top = ApplicationTrafficPresentation.sorted(apps, by: .activity).first else { return nil }
        let topSpeed = top.downloadBytesPerSecond + top.uploadBytesPerSecond
        let share = topSpeed / appTotal
        guard topSpeed >= 5_242_880, share >= 0.60 else {
            appSpikeStartedAtByID[top.id] = nil
            return nil
        }
        if appSpikeStartedAtByID[top.id] == nil { appSpikeStartedAtByID[top.id] = now }
        guard let startedAt = appSpikeStartedAtByID[top.id], now.timeIntervalSince(startedAt) >= 5 else { return nil }
        let key = "applicationSpike.\(top.id)"
        guard canEmit(cooldownKey: key, now: now, cooldown: 10 * 60) else { return nil }
        markEmitted(cooldownKey: key, now: now)
        return NetworkAnomalyEvent(
            kind: .applicationSpike,
            severity: .warning,
            title: NetworkAnomalyKind.applicationSpike.title(language: .simplifiedChinese),
            message: "\(top.displayName) 占应用流量约 \(Int((share * 100).rounded()))%，当前 \(ByteFormat.speed(topSpeed))。",
            timestamp: now,
            applicationName: top.displayName,
            bytesPerSecond: topSpeed,
            cooldownKey: key
        )
    }

    private mutating func dropOrRecoveryEvent(totalSpeed: Double, now: Date) -> NetworkAnomalyEvent? {
        if droppedState {
            guard totalSpeed > 20_480 else { return nil }
            let key = "networkRecovered"
            guard canEmit(cooldownKey: key, now: now, cooldown: 3 * 60) else { return nil }
            droppedState = false
            lowTrafficStartedAt = nil
            markEmitted(cooldownKey: key, now: now)
            return NetworkAnomalyEvent(kind: .networkRecovered, severity: .info, title: NetworkAnomalyKind.networkRecovered.title(language: .simplifiedChinese), message: "网络活动已恢复。", timestamp: now, bytesPerSecond: totalSpeed, cooldownKey: key)
        }

        let priorAverage = recentActiveSamples.filter { now.timeIntervalSince($0.0) > 8 }.map(\.1)
        let average = priorAverage.isEmpty ? 0 : priorAverage.reduce(0, +) / Double(priorAverage.count)
        guard totalSpeed < 1_024, average > 102_400 else {
            lowTrafficStartedAt = nil
            return nil
        }
        if lowTrafficStartedAt == nil { lowTrafficStartedAt = now }
        guard let startedAt = lowTrafficStartedAt, now.timeIntervalSince(startedAt) >= 8 else { return nil }
        let key = "networkDrop"
        guard canEmit(cooldownKey: key, now: now, cooldown: 3 * 60) else { return nil }
        droppedState = true
        markEmitted(cooldownKey: key, now: now)
        return NetworkAnomalyEvent(kind: .networkDrop, severity: .critical, title: NetworkAnomalyKind.networkDrop.title(language: .simplifiedChinese), message: "网络活动从活跃状态降至接近空闲。", timestamp: now, bytesPerSecond: totalSpeed, cooldownKey: key)
    }

    private mutating func proxyGapEvent(snapshot: NetworkSnapshot, appTraffic: ApplicationTrafficState, now: Date) -> NetworkAnomalyEvent? {
        let summary = ApplicationTrafficPresentation.attributionSummary(snapshot: snapshot, applications: appTraffic.applications)
        guard summary.interfaceBytesPerSecond >= 1_048_576,
              let coverage = summary.coveragePercentage,
              coverage < 40,
              let proxy = summary.proxyCandidateNames.first else {
            return nil
        }
        let key = "proxyAttributionGap"
        guard canEmit(cooldownKey: key, now: now, cooldown: 15 * 60) else { return nil }
        markEmitted(cooldownKey: key, now: now)
        return NetworkAnomalyEvent(kind: .proxyAttributionGap, severity: .warning, title: NetworkAnomalyKind.proxyAttributionGap.title(language: .simplifiedChinese), message: "流量可能集中在代理/VPN 进程 \(proxy)。", timestamp: now, applicationName: proxy, bytesPerSecond: summary.interfaceBytesPerSecond, cooldownKey: key)
    }

    private func canEmit(cooldownKey: String, now: Date, cooldown: TimeInterval) -> Bool {
        guard let last = lastEmittedAtByCooldownKey[cooldownKey] else { return true }
        return now.timeIntervalSince(last) >= cooldown
    }

    private mutating func markEmitted(cooldownKey: String, now: Date) {
        lastEmittedAtByCooldownKey[cooldownKey] = now
    }
}
```

- [ ] **Step 4: Run detector tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkAnomalyDetector
```

Expected: detector tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/NetworkAnomalyDetector.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add network anomaly detector"
```

## Task 4: Notification Controller

**Files:**
- Create: `Sources/NetBar/NetworkNotificationController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing notification controller tests**

Add protocol-based tests so no real system notification is sent:

```swift
func testNetworkNotificationControllerSuppressesDuplicateCooldownEvents() {
    let center = FakeNetworkNotificationCenter(authorizationStatus: .authorized)
    let controller = NetworkNotificationController(center: center, now: { Date(timeIntervalSince1970: 100) })
    let settings = NetworkIntelligenceSettings.default.withSystemNotificationsEnabled()
    let event = NetworkAnomalyEvent(kind: .highTraffic, severity: .warning, title: "High", message: "Traffic", timestamp: Date(timeIntervalSince1970: 100), bytesPerSecond: 1_000, cooldownKey: "highTraffic")

    controller.handle(event, settings: settings)
    controller.handle(event, settings: settings)

    XCTAssertEqual(center.deliveredTitles, ["High"])
}

func testNetworkNotificationControllerDoesNotSendWhenAuthorizationDenied() {
    let center = FakeNetworkNotificationCenter(authorizationStatus: .denied)
    let controller = NetworkNotificationController(center: center, now: { Date(timeIntervalSince1970: 100) })
    let settings = NetworkIntelligenceSettings.default.withSystemNotificationsEnabled()
    let event = NetworkAnomalyEvent(kind: .networkDrop, severity: .critical, title: "Drop", message: "Quiet", timestamp: Date(timeIntervalSince1970: 100), cooldownKey: "networkDrop")

    controller.handle(event, settings: settings)

    XCTAssertTrue(center.deliveredTitles.isEmpty)
}
```

Add test-only helper:

```swift
private extension NetworkIntelligenceSettings {
    func withSystemNotificationsEnabled() -> NetworkIntelligenceSettings {
        var copy = self
        copy.isSystemNotificationEnabled = true
        return copy
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkNotificationController
```

Expected: compile failure because the controller and fake protocol do not exist.

- [ ] **Step 3: Implement notification protocol and controller**

Create `Sources/NetBar/NetworkNotificationController.swift`:

```swift
import Foundation
import UserNotifications

enum NetworkNotificationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
}

protocol NetworkNotificationCentering: AnyObject {
    func authorizationStatus() async -> NetworkNotificationAuthorizationStatus
    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus
    func deliver(title: String, body: String) async
}

final class UserNotificationCenterAdapter: NetworkNotificationCentering {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NetworkNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func deliver(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}

@MainActor
final class NetworkNotificationController: ObservableObject {
    @Published private(set) var authorizationStatus: NetworkNotificationAuthorizationStatus = .notDetermined

    private let center: NetworkNotificationCentering
    private let now: () -> Date
    private var lastDeliveredAtByKey: [String: Date] = [:]

    init(center: NetworkNotificationCentering = UserNotificationCenterAdapter(), now: @escaping () -> Date = Date.init) {
        self.center = center
        self.now = now
    }

    func refreshAuthorizationStatus() {
        Task { @MainActor in
            authorizationStatus = await center.authorizationStatus()
        }
    }

    func requestAuthorization() {
        Task { @MainActor in
            authorizationStatus = await center.requestAuthorization()
        }
    }

    func handle(_ event: NetworkAnomalyEvent, settings: NetworkIntelligenceSettings) {
        guard settings.isSystemNotificationEnabled else { return }
        guard settings.isEnabled(for: event.kind) else { return }
        guard authorizationStatus == .authorized else { return }
        let cooldown = cooldownSeconds(for: event.kind)
        if let last = lastDeliveredAtByKey[event.cooldownKey], now().timeIntervalSince(last) < cooldown {
            return
        }
        lastDeliveredAtByKey[event.cooldownKey] = now()
        Task { [center] in
            await center.deliver(title: event.title, body: event.message)
        }
    }

    private func cooldownSeconds(for kind: NetworkAnomalyKind) -> TimeInterval {
        switch kind {
        case .highTraffic, .applicationSpike:
            return 10 * 60
        case .networkDrop, .networkRecovered:
            return 3 * 60
        case .proxyAttributionGap:
            return 15 * 60
        }
    }
}

extension NetworkIntelligenceSettings {
    func isEnabled(for kind: NetworkAnomalyKind) -> Bool {
        guard isAnomalyDetectionEnabled else { return false }
        switch kind {
        case .highTraffic:
            return true
        case .applicationSpike:
            return isApplicationSpikeAlertEnabled
        case .networkDrop, .networkRecovered:
            return isNetworkDropAlertEnabled
        case .proxyAttributionGap:
            return isProxyAttributionAlertEnabled
        }
    }
}
```

Add `FakeNetworkNotificationCenter` to tests:

```swift
@MainActor
private final class FakeNetworkNotificationCenter: NetworkNotificationCentering {
    var status: NetworkNotificationAuthorizationStatus
    var deliveredTitles: [String] = []

    init(authorizationStatus: NetworkNotificationAuthorizationStatus) {
        self.status = authorizationStatus
    }

    func authorizationStatus() async -> NetworkNotificationAuthorizationStatus { status }
    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus { status }
    func deliver(title: String, body: String) async { deliveredTitles.append(title) }
}
```

- [ ] **Step 4: Run notification tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkNotificationController
```

Expected: notification controller tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/NetworkNotificationController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add network notification controller"
```

## Task 5: NetworkMonitor Integration

**Files:**
- Modify: `Sources/NetBar/NetworkMonitor.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing monitor integration test**

Add to `SystemResourceTests`:

```swift
@MainActor
func testNetworkMonitorUpdatesNetworkIntelligenceSummary() {
    var now = Date(timeIntervalSince1970: 100)
    let reader = MockNetworkStatsReader(sequence: [
        [InterfaceStats(name: "en0", displayName: "Wi-Fi", receivedBytes: 1_000, sentBytes: 2_000, receivedPackets: 1, sentPackets: 1, isPrimary: true)],
        [InterfaceStats(name: "en0", displayName: "Wi-Fi", receivedBytes: 3_000, sentBytes: 5_000, receivedPackets: 2, sentPackets: 2, isPrimary: true)]
    ])
    let root = temporaryDirectoryForSystemTests()
    let monitor = NetworkMonitor(
        reader: reader,
        appTrafficReader: MockApplicationTrafficReader(applications: []),
        systemResourceReader: MockSystemResourceReader(),
        resourceReader: MockApplicationResourceReader(),
        historyStore: NetworkHistoryStore(rootDirectory: root, now: { now }),
        now: { now }
    )

    monitor.refresh()
    waitForMainActorTasks()
    now = now.addingTimeInterval(1)
    monitor.refresh()
    waitForMainActorTasks()

    XCTAssertEqual(monitor.intelligenceSummary.today.downloadBytes, 2_000)
    XCTAssertEqual(monitor.intelligenceSummary.today.uploadBytes, 3_000)
}
```

Use the repository's existing mock reader pattern from the surrounding `NetworkMonitor` tests; the first sample is the baseline and the second sample must produce a positive delta in `intelligenceSummary.today`.

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
swift test --filter SystemResourceTests/testNetworkMonitorUpdatesNetworkIntelligenceSummary
```

Expected: compile failure because `NetworkMonitor` does not accept `historyStore` and does not publish `intelligenceSummary`.

- [ ] **Step 3: Add monitor dependencies**

Modify `NetworkMonitor` initializer:

```swift
@Published private(set) var intelligenceSummary = NetworkIntelligenceSummary.empty

private let historyStore: NetworkHistoryStore
private var anomalyDetector = NetworkAnomalyDetector()
private var lastApplicationTrafficDate: Date?

init(
    reader: NetworkStatsReading = SystemNetworkStatsReader(),
    appTrafficReader: ApplicationTrafficReading? = nil,
    systemResourceReader: SystemResourceReading = LiveSystemResourceReader(),
    resourceReader: ApplicationResourceReading? = nil,
    historyStore: NetworkHistoryStore? = nil,
    now: @escaping () -> Date = Date.init
) {
    self.reader = reader
    self.systemResourceReader = systemResourceReader
    self.now = now
    self.historyStore = historyStore ?? NetworkHistoryStore(now: now)
    ...
}
```

After `snapshot = NetworkSnapshot(...)` in `applyRefresh`, add:

```swift
historyStore.record(snapshot: snapshot)
intelligenceSummary = historyStore.summary
```

After app traffic state is updated in `refreshApplicationTraffic` apply path, compute interval and add:

```swift
let interval = lastApplicationTrafficDate.map { now.timeIntervalSince($0) } ?? applicationSampleInterval
historyStore.record(appTraffic: appTraffic, interval: max(interval, 0.2))
lastApplicationTrafficDate = now
intelligenceSummary = historyStore.summary
```

Keep `AppPreferences` out of `NetworkMonitor`. Expose anomaly detection through this method so `StatusBarController` can pass current settings in Task 10:

```swift
func refreshIntelligence(settings: NetworkIntelligenceSettings) -> [NetworkAnomalyEvent] {
    let events = anomalyDetector.detect(snapshot: snapshot, appTraffic: appTraffic, settings: settings, now: now())
    if let latest = events.last {
        intelligenceSummary.latestEvent = latest
    }
    return events
}
```

Use this method from `StatusBarController` in Task 10, where `AppPreferences` is already available.

- [ ] **Step 4: Run monitor integration test**

Run:

```bash
swift test --filter SystemResourceTests/testNetworkMonitorUpdatesNetworkIntelligenceSummary
```

Expected: monitor intelligence summary test passes.

- [ ] **Step 5: Run full monitor tests**

Run:

```bash
swift test --filter SystemResourceTests/testNetworkMonitor
```

Expected: existing network monitor tests still pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/NetworkMonitor.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: connect network intelligence summary"
```

## Task 6: Details Window Intelligence Sections

**Files:**
- Modify: `Sources/NetBar/NetworkPopoverView.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing presentation tests**

Add tests for pure presentation helpers:

```swift
func testNetworkIntelligenceStatusPresentationMapsSeverity() {
    let event = NetworkAnomalyEvent(kind: .networkDrop, severity: .critical, title: "网络断流", message: "网络活动下降。", timestamp: Date(timeIntervalSince1970: 10), cooldownKey: "networkDrop")

    let presentation = NetworkIntelligenceStatusPresentation(event: event, language: .simplifiedChinese)

    XCTAssertEqual(presentation.title, "网络断流")
    XCTAssertEqual(presentation.tone, .critical)
    XCTAssertEqual(presentation.symbolName, "exclamationmark.triangle.fill")
}

func testNetworkDailySummaryPresentationFormatsTodayEstimate() {
    let summary = NetworkDailySummary(
        dateKey: "2026-06-08",
        downloadBytes: 10_000_000,
        uploadBytes: 5_000_000,
        peakDownloadBytesPerSecond: 2_000_000,
        peakUploadBytesPerSecond: 1_000_000,
        sampleCount: 20,
        activeSeconds: 80,
        topApplications: []
    )

    let cards = NetworkDailySummaryPresentation.cards(for: summary, language: .english)

    XCTAssertEqual(cards.map(\.title), ["Today Down", "Today Up", "Peak", "Active"])
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkIntelligenceStatusPresentationMapsSeverity
```

Expected: compile failure because presentation helpers do not exist.

- [ ] **Step 3: Add presentation helpers in `NetworkPopoverView.swift`**

Add near the intelligence section:

```swift
private enum NetworkIntelligenceTone: Equatable {
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

struct NetworkDailySummaryCard: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
}

enum NetworkDailySummaryPresentation {
    static func cards(for summary: NetworkDailySummary, language: AppLanguage) -> [NetworkDailySummaryCard] {
        [
            NetworkDailySummaryCard(id: "down", title: language.text("今日下载", "Today Down"), value: ByteFormat.bytes(summary.downloadBytes)),
            NetworkDailySummaryCard(id: "up", title: language.text("今日上传", "Today Up"), value: ByteFormat.bytes(summary.uploadBytes)),
            NetworkDailySummaryCard(id: "peak", title: language.text("今日峰值", "Peak"), value: ByteFormat.speed(max(summary.peakDownloadBytesPerSecond, summary.peakUploadBytesPerSecond))),
            NetworkDailySummaryCard(id: "active", title: language.text("活跃时长", "Active"), value: Self.duration(summary.activeSeconds))
        ]
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
```

- [ ] **Step 4: Add SwiftUI sections**

In `NetworkPopoverView.body`, insert after the header divider:

```swift
NetworkIntelligenceStatusCard(
    presentation: NetworkIntelligenceStatusPresentation(
        event: monitor.intelligenceSummary.latestEvent,
        language: appPreferences.resolvedLanguage
    ),
    appPreferences: appPreferences,
    openPreferences: openPreferences
)
.padding(.top, 16)
```

Add `TodayNetworkSummary` before `SummaryGrid`:

```swift
TodayNetworkSummary(
    summary: monitor.intelligenceSummary.today,
    appPreferences: appPreferences
)
```

Add `ApplicationTopSection` before `ApplicationTrafficList`:

```swift
ApplicationTopSection(
    realtimeApplications: monitor.intelligenceSummary.realtimeTopApplications,
    todayApplications: monitor.intelligenceSummary.todayTopApplications,
    appPreferences: appPreferences
)
```

Add `SevenDaySummarySection` near the bottom before `InterfaceList`:

```swift
SevenDaySummarySection(
    summaries: monitor.intelligenceSummary.recentDays,
    appPreferences: appPreferences
)
```

Implement each as compact SwiftUI views using existing `netBarCard`, `NetBarSectionHeader`, `CompactMetric`, `ApplicationTrafficRow` patterns. Keep rows capped:

- realtime Top: 3 rows.
- today Top: 5 rows.
- 7-day expanded rows: 7 rows.

- [ ] **Step 5: Run presentation tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkIntelligenceStatusPresentationMapsSeverity --filter PreferencesAndPresentationTests/testNetworkDailySummaryPresentationFormatsTodayEstimate
```

Expected: tests pass.

- [ ] **Step 6: Build**

Run:

```bash
./Scripts/build-app.sh
```

Expected: build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/NetworkPopoverView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: show network intelligence details"
```

## Task 7: Intelligence Preferences Tab

**Files:**
- Create: `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesWindowController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing preference metadata tests**

Add tests:

```swift
func testHighTrafficThresholdTitlesAreLocalized() {
    XCTAssertEqual(HighTrafficThreshold.mbps5.title(language: .simplifiedChinese), "5 MB/s")
    XCTAssertEqual(HighTrafficThreshold.mbps50.title(language: .english), "50 MB/s")
}

func testNetworkNotificationAuthorizationStatusTitles() {
    XCTAssertEqual(NetworkNotificationAuthorizationStatus.authorized.title(language: .simplifiedChinese), "已授权")
    XCTAssertEqual(NetworkNotificationAuthorizationStatus.denied.title(language: .english), "Denied")
    XCTAssertEqual(NetworkNotificationAuthorizationStatus.notDetermined.title(language: .simplifiedChinese), "未设置")
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkNotificationAuthorizationStatusTitles
```

Expected: compile failure because title helper is not implemented.

- [ ] **Step 3: Add authorization title helper**

In `NetworkNotificationController.swift`, add:

```swift
extension NetworkNotificationAuthorizationStatus {
    func title(language: AppLanguage) -> String {
        switch self {
        case .notDetermined:
            return language.text("未设置", "Not set")
        case .denied:
            return language.text("已拒绝", "Denied")
        case .authorized:
            return language.text("已授权", "Authorized")
        }
    }
}
```

- [ ] **Step 4: Create Intelligence preferences view**

Create `Sources/NetBar/Preferences/IntelligencePreferencesView.swift`:

```swift
import SwiftUI

struct IntelligencePreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var notificationController: NetworkNotificationController
    let clearHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                onboardingSection
                anomalySection
                notificationSection
                historySection
            }
        }
    }

    private var onboardingSection: some View {
        Group {
            if !appPreferences.networkIntelligenceSettings.hasSeenNotificationOnboarding {
                PreferenceSection(title: appPreferences.text("异常通知", "Anomaly Notifications")) {
                    Text(appPreferences.text(
                        "NetBar 可以在高流量、应用突增、断流/恢复时提醒你。开启后会请求 macOS 通知权限。",
                        "NetBar can notify you about high traffic, application spikes, and network drops or recovery. macOS notification permission is requested only after you enable it."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button(appPreferences.text("开启异常通知", "Enable Notifications")) {
                            appPreferences.networkIntelligenceSettings.hasSeenNotificationOnboarding = true
                            appPreferences.networkIntelligenceSettings.isSystemNotificationEnabled = true
                            notificationController.requestAuthorization()
                        }
                        Button(appPreferences.text("暂不开启", "Not Now")) {
                            appPreferences.networkIntelligenceSettings.hasSeenNotificationOnboarding = true
                        }
                    }
                }
            }
        }
    }

    private var anomalySection: some View {
        PreferenceSection(title: appPreferences.text("智能检测", "Intelligence")) {
            Toggle(appPreferences.text("异常检测", "Anomaly detection"), isOn: $appPreferences.networkIntelligenceSettings.isAnomalyDetectionEnabled)
            Picker(appPreferences.text("高流量阈值", "High traffic threshold"), selection: $appPreferences.networkIntelligenceSettings.highTrafficThreshold) {
                ForEach(HighTrafficThreshold.allCases) { threshold in
                    Text(threshold.title(language: appPreferences.resolvedLanguage)).tag(threshold)
                }
            }
            .pickerStyle(.segmented)
            Toggle(appPreferences.text("应用突增提醒", "Application spike alerts"), isOn: $appPreferences.networkIntelligenceSettings.isApplicationSpikeAlertEnabled)
            Toggle(appPreferences.text("断流/恢复提醒", "Drop/recovery alerts"), isOn: $appPreferences.networkIntelligenceSettings.isNetworkDropAlertEnabled)
            Toggle(appPreferences.text("代理/VPN 归因提醒", "Proxy/VPN attribution alerts"), isOn: $appPreferences.networkIntelligenceSettings.isProxyAttributionAlertEnabled)
        }
    }

    private var notificationSection: some View {
        PreferenceSection(title: appPreferences.text("系统通知", "System Notifications")) {
            Toggle(appPreferences.text("发送系统通知", "Send system notifications"), isOn: $appPreferences.networkIntelligenceSettings.isSystemNotificationEnabled)
            HStack {
                Text(appPreferences.text("权限状态", "Authorization"))
                Spacer()
                Text(notificationController.authorizationStatus.title(language: appPreferences.resolvedLanguage))
                    .foregroundStyle(.secondary)
            }
            if notificationController.authorizationStatus == .notDetermined {
                Button(appPreferences.text("请求通知权限", "Request Permission")) {
                    notificationController.requestAuthorization()
                }
            }
        }
    }

    private var historySection: some View {
        PreferenceSection(title: appPreferences.text("历史统计", "History")) {
            Toggle(appPreferences.text("记录今日与最近 7 天", "Track today and recent 7 days"), isOn: $appPreferences.networkIntelligenceSettings.isHistoryTrackingEnabled)
            Button(appPreferences.text("清空历史数据", "Clear History"), role: .destructive) {
                clearHistory()
            }
            Text(appPreferences.text(
                "历史统计为本地估算值，用于趋势判断，不等同于运营商计费。",
                "History values are local estimates for trend awareness and are not billing-grade measurements."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

- [ ] **Step 5: Wire tab into PreferencesWindowController**

Add a notification controller and clear-history closure to the preferences controller initializer. Add a new tab:

```swift
IntelligencePreferencesView(
    appPreferences: appPreferences,
    notificationController: notificationController,
    clearHistory: clearNetworkHistory
)
.tabItem {
    Label(appPreferences.text("智能", "Intelligence"), systemImage: "sparkles")
}
```

The current preferences surface is `TabView` based. Add the Intelligence view beside General, Menu Bar, and About, then renumber tags so each tab has a stable unique integer.

- [ ] **Step 6: Run tests and build**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testHighTrafficThresholdTitlesAreLocalized --filter PreferencesAndPresentationTests/testNetworkNotificationAuthorizationStatusTitles
./Scripts/build-app.sh
```

Expected: tests and build pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/Preferences/IntelligencePreferencesView.swift Sources/NetBar/Preferences/PreferencesWindowController.swift Sources/NetBar/NetworkNotificationController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add intelligence preferences"
```

## Task 8: Menu Bar Presets

**Files:**
- Create: `Sources/NetBar/MenuBarPreset.swift`
- Modify: `Sources/NetBar/Preferences/MenuBarPreferencesView.swift`
- Modify: `Sources/NetBar/StatusBarStyle.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing preset tests**

Add tests:

```swift
func testMenuBarPresetAppliesTotalTrafficMode() {
    let defaults = isolatedDefaults()
    let settings = StatusBarSettings(defaults: defaults)

    MenuBarPreset.totalTraffic.apply(to: settings)

    XCTAssertEqual(settings.trafficDisplayMode, .total)
    XCTAssertFalse(settings.showsArrows)
}

func testMenuBarPresetDetectsCustomAfterManualEdit() {
    let settings = StatusBarSettings(defaults: isolatedDefaults())
    MenuBarPreset.upDown.apply(to: settings)
    XCTAssertEqual(MenuBarPreset.matching(settings: settings), .upDown)

    settings.fontSize = settings.fontSize + 1

    XCTAssertNil(MenuBarPreset.matching(settings: settings))
}

func testMenuBarPresetTitlesAreLocalized() {
    XCTAssertEqual(MenuBarPreset.minimal.title(language: .simplifiedChinese), "极简")
    XCTAssertEqual(MenuBarPreset.petMode.title(language: .english), "Pet Mode")
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testMenuBarPreset
```

Expected: compile failure because `MenuBarPreset` does not exist.

- [ ] **Step 3: Implement `MenuBarPreset`**

Create `Sources/NetBar/MenuBarPreset.swift`:

```swift
import Foundation

enum MenuBarPreset: String, CaseIterable, Identifiable {
    case minimal
    case upDown
    case totalTraffic
    case appFocus
    case petMode

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .minimal:
            return language.text("极简", "Minimal")
        case .upDown:
            return language.text("上下行", "Up/Down")
        case .totalTraffic:
            return language.text("总流量", "Total Traffic")
        case .appFocus:
            return language.text("应用关注", "App Focus")
        case .petMode:
            return language.text("宠物模式", "Pet Mode")
        }
    }

    func apply(to settings: StatusBarSettings) {
        switch self {
        case .minimal:
            settings.trafficDisplayMode = .downloadOnly
            settings.showsArrows = false
            settings.showsBackground = false
            settings.widthMode = .automatic
            settings.characterScale = 0.8
        case .upDown:
            settings.trafficDisplayMode = .upDown
            settings.showsArrows = true
            settings.widthMode = .automatic
            settings.characterScale = 1.0
        case .totalTraffic:
            settings.trafficDisplayMode = .total
            settings.showsArrows = false
            settings.widthMode = .automatic
            settings.characterScale = 0.9
        case .appFocus:
            settings.trafficDisplayMode = .upDown
            settings.showsArrows = true
            settings.showsBackground = false
            settings.characterScale = 0.75
        case .petMode:
            settings.trafficDisplayMode = .upDown
            settings.showsArrows = true
            settings.characterScale = 1.2
            settings.animationSpeedSource = .autoComposite
        }
    }

    static func matching(settings: StatusBarSettings) -> MenuBarPreset? {
        allCases.first { preset in
            let copy = StatusBarSettings(defaults: UserDefaults(suiteName: "MenuBarPreset.match.\(UUID().uuidString)")!)
            preset.apply(to: copy)
            return copy.trafficDisplayMode == settings.trafficDisplayMode
                && copy.showsArrows == settings.showsArrows
                && copy.showsBackground == settings.showsBackground
                && abs(copy.characterScale - settings.characterScale) < 0.001
                && copy.animationSpeedSource == settings.animationSpeedSource
        }
    }
}
```

Use the `StatusBarSettings` property names already present in `Sources/NetBar/StatusBarStyle.swift` when adding the preset apply and matching helpers.

- [ ] **Step 4: Add preset UI**

In `MenuBarPreferencesView`, add a compact picker near the top:

```swift
PreferenceSection(title: appPreferences.text("预设", "Presets")) {
    Picker(appPreferences.text("菜单栏预设", "Menu bar preset"), selection: Binding(
        get: { MenuBarPreset.matching(settings: settings) },
        set: { preset in preset?.apply(to: settings) }
    )) {
        Text(appPreferences.text("自定义", "Custom")).tag(Optional<MenuBarPreset>.none)
        ForEach(MenuBarPreset.allCases) { preset in
            Text(preset.title(language: appPreferences.resolvedLanguage)).tag(Optional(preset))
        }
    }
    .pickerStyle(.menu)
}
```

- [ ] **Step 5: Run preset tests and build**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testMenuBarPreset
./Scripts/build-app.sh
```

Expected: tests and build pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/MenuBarPreset.swift Sources/NetBar/Preferences/MenuBarPreferencesView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add menu bar presets"
```

## Task 9: Pet Intelligence

**Files:**
- Modify: `Sources/NetBar/PetController.swift`
- Modify: `Sources/NetBar/PetState.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing pet anomaly tests**

Add tests:

```swift
func testPetControllerEmitsCueForApplicationSpikeAnomaly() {
    let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
    controller.updateSettings { $0.isEnabled = true }
    let event = NetworkAnomalyEvent(kind: .applicationSpike, severity: .warning, title: "应用突增", message: "Chrome 当前较活跃。", timestamp: Date(timeIntervalSince1970: 100), applicationName: "Chrome", bytesPerSecond: 5_000_000, cooldownKey: "applicationSpike.Chrome")

    controller.observe(anomaly: event)

    XCTAssertEqual(controller.latestCue?.kind, .networkIntelligence)
    XCTAssertTrue(controller.latestCue?.message.contains("Chrome") == true)
}

func testPetControllerMoodReflectsDailyNetworkActivity() {
    let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
    controller.updateSettings { $0.isEnabled = true }

    controller.observe(todaySummary: NetworkDailySummary(
        dateKey: "2026-06-08",
        downloadBytes: 20_000_000_000,
        uploadBytes: 1_000_000_000,
        peakDownloadBytesPerSecond: 10_000_000,
        peakUploadBytesPerSecond: 1_000_000,
        sampleCount: 100,
        activeSeconds: 3_000,
        topApplications: []
    ))

    XCTAssertEqual(controller.state.mood, .excited)
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetControllerEmitsCueForApplicationSpikeAnomaly
```

Expected: compile failure because the pet anomaly methods or cue kind do not exist.

- [ ] **Step 3: Add pet cue kind**

In `PetState.swift`, extend `PetCueKind`:

```swift
case networkIntelligence
```

Update any `switch` statements over `PetCueKind` to handle `.networkIntelligence`.

- [ ] **Step 4: Add pet anomaly methods**

In `PetController.swift`, add:

```swift
func observe(anomaly event: NetworkAnomalyEvent) {
    guard settings.isEnabled else { return }
    clearExpiredActiveSkillIfNeeded(at: now())
    switch event.kind {
    case .highTraffic:
        state.mood = .excited
    case .applicationSpike, .proxyAttributionGap:
        state.mood = .focused
    case .networkDrop:
        state.mood = .worried
    case .networkRecovered:
        state.mood = .happy
    }
    emitCue(
        kind: .networkIntelligence,
        title: event.title,
        message: petMessage(for: event),
        animationHint: event.severity == .critical ? .worried : .focused
    )
    markStateUpdatedAndSaveImmediately(at: now())
}

func observe(todaySummary: NetworkDailySummary) {
    guard settings.isEnabled else { return }
    if todaySummary.totalBytes >= 10_000_000_000 {
        state.mood = .excited
    } else if todaySummary.activeSeconds < 60 {
        state.mood = .sleepy
    } else {
        state.mood = .happy
    }
    markStateUpdatedAndSave(at: now())
}

private func petMessage(for event: NetworkAnomalyEvent) -> String {
    switch event.kind {
    case .applicationSpike:
        return text(
            "\(event.applicationName ?? "某个应用") 当前网络活动明显升高。",
            "\(event.applicationName ?? "An app") is using noticeably more network traffic."
        )
    case .proxyAttributionGap:
        return text("流量可能集中在代理或 VPN 进程里。", "Traffic may be concentrated in a proxy or VPN process.")
    case .highTraffic:
        return event.bytesPerSecond.map { text("当前总速率约 \(ByteFormat.speed($0))。", "Current total speed is about \(ByteFormat.speed($0)).") }
            ?? text("当前网络流量较高。", "Network traffic is high right now.")
    case .networkDrop:
        return text("网络活动像是突然安静下来了。", "Network activity suddenly looks quiet.")
    case .networkRecovered:
        return text("网络活动恢复了。", "Network activity is back.")
    }
}
```

- [ ] **Step 5: Run pet tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetController
```

Expected: all existing and new pet tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/PetController.swift Sources/NetBar/PetState.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet network intelligence cues"
```

## Task 10: App-Level Coordination

**Files:**
- Create: `Sources/NetBar/NetworkIntelligenceCoordinator.swift`
- Modify: `Sources/NetBar/AppDelegate.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Modify: `Sources/NetBar/Preferences/PreferencesWindowController.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing coordinator test**

Add this test to `SystemResourceTests` near the existing `NetworkMonitor` integration tests:

```swift
func testNetworkIntelligenceCoordinatorForwardsEventsToNotificationAndPet() {
    var notified: [NetworkAnomalyEvent] = []
    var notificationSettings: [NetworkIntelligenceSettings] = []
    var cued: [NetworkAnomalyEvent] = []
    var todaySummaries: [NetworkDailySummary] = []
    let coordinator = NetworkIntelligenceCoordinator(
        notify: { event, settings in
            notified.append(event)
            notificationSettings.append(settings)
        },
        petCue: { event in
            cued.append(event)
        },
        petDailySummary: { summary in
            todaySummaries.append(summary)
        }
    )
    let event = NetworkAnomalyEvent(
        kind: .highTraffic,
        severity: .warning,
        title: "High",
        message: "Traffic",
        timestamp: Date(timeIntervalSince1970: 1_717_200_000),
        cooldownKey: "high"
    )
    let today = NetworkDailySummary.empty(dateKey: "2026-06-08")

    coordinator.handle(events: [event], todaySummary: today, settings: .default)

    XCTAssertEqual(notified, [event])
    XCTAssertEqual(notificationSettings, [.default])
    XCTAssertEqual(cued, [event])
    XCTAssertEqual(todaySummaries, [today])
}
```

- [ ] **Step 2: Add coordinator type**

Create `Sources/NetBar/NetworkIntelligenceCoordinator.swift`:

```swift
struct NetworkIntelligenceCoordinator {
    let notify: (NetworkAnomalyEvent, NetworkIntelligenceSettings) -> Void
    let petCue: (NetworkAnomalyEvent) -> Void
    let petDailySummary: (NetworkDailySummary) -> Void

    func handle(
        events: [NetworkAnomalyEvent],
        todaySummary: NetworkDailySummary,
        settings: NetworkIntelligenceSettings
    ) {
        for event in events {
            notify(event, settings)
            petCue(event)
        }
        petDailySummary(todaySummary)
    }
}
```

- [ ] **Step 3: Wire controllers**

In `AppDelegate`, create:

```swift
private let notificationController = NetworkNotificationController()
private let petController = PetController()
```

Pass both controllers into `StatusBarController`:

```swift
statusBarController = StatusBarController(
    monitor: NetworkMonitor(),
    settings: settings,
    appPreferences: appPreferences,
    customCharacterStore: customCharacterStore,
    powerObserver: powerObserver,
    notificationController: notificationController,
    petController: petController,
    openPreferences: { [weak self] in
        self?.showPreferences(nil)
    },
    showAbout: { [weak self] in
        self?.showAbout(nil)
    }
)
```

Pass `notificationController` and `clearNetworkHistory` into `PreferencesWindowController`:

```swift
private lazy var preferencesWindowController = PreferencesWindowController(
    settings: settings,
    appPreferences: appPreferences,
    customCharacterStore: customCharacterStore,
    updater: updater,
    notificationController: notificationController,
    clearNetworkHistory: { [weak self] in
        self?.statusBarController?.clearNetworkHistory()
    }
)
```

In `StatusBarController`, store the new dependencies:

```swift
private let notificationController: NetworkNotificationController
private let petController: PetController
private lazy var networkIntelligenceCoordinator = NetworkIntelligenceCoordinator(
    notify: { [weak self] event, settings in
        self?.notificationController.handle(event, settings: settings)
    },
    petCue: { [weak self] event in
        self?.petController.observe(anomaly: event)
    },
    petDailySummary: { [weak self] summary in
        self?.petController.observe(todaySummary: summary)
    }
)
```

Extend the existing `StatusBarController` initializer parameter list by inserting these parameters before `openPreferences`:

```swift
notificationController: NetworkNotificationController,
petController: PetController,
```

Add these assignments next to the existing dependency assignments:

```swift
self.notificationController = notificationController
self.petController = petController
```

In `StatusBarController`, when monitor data changes and preferences are available:

```swift
let events = monitor.refreshIntelligence(settings: appPreferences.networkIntelligenceSettings)
networkIntelligenceCoordinator.handle(
    events: events,
    todaySummary: monitor.intelligenceSummary.today,
    settings: appPreferences.networkIntelligenceSettings
)
```

Place this call in the existing Combine observer path that reacts to monitor data changes.

- [ ] **Step 4: Wire clear history**

Pass a closure to `PreferencesWindowController`:

```swift
clearNetworkHistory: { [weak statusBarController] in
    statusBarController?.clearNetworkHistory()
}
```

Expose from `StatusBarController`:

```swift
func clearNetworkHistory() {
    monitor.clearNetworkHistory()
}
```

Expose from `NetworkMonitor`:

```swift
func clearNetworkHistory() {
    historyStore.clear()
    intelligenceSummary = historyStore.summary
}
```

- [ ] **Step 5: Run coordination tests/build**

Run:

```bash
swift test --filter SystemResourceTests/testNetworkIntelligenceCoordinator
./Scripts/build-app.sh
```

Expected: the coordinator test and app build pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/NetworkIntelligenceCoordinator.swift Sources/NetBar/AppDelegate.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/Preferences/PreferencesWindowController.swift Sources/NetBar/NetworkMonitor.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: wire network intelligence events"
```

## Task 11: Release Documentation And Version

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `Resources/Info.plist`
- Test: none.

- [ ] **Step 1: Update `Info.plist` to 0.38.0**

Change:

```xml
<key>CFBundleShortVersionString</key>
<string>0.38.0</string>
<key>CFBundleVersion</key>
<string>0.38.0</string>
```

- [ ] **Step 2: Add changelog entry**

Add at top of `CHANGELOG.md`:

```markdown
## v0.38.0 (2026-06-08)

### Enhancement — 网络智能提醒与历史统计

- 新增异常检测：高流量、应用突增、断流/恢复、代理/VPN 归因差异
- 新增首次通知引导和可控的 macOS 系统通知
- 新增今日估算、最近 7 天汇总、实时 Top 和今日应用 Top
- 新增菜单栏内置预设：极简、上下行、总流量、应用关注、宠物模式
- 宠物会在网络异常时给出轻量解释，并根据今日网络活动调整状态
```

- [ ] **Step 3: Update README**

Add feature bullets:

```markdown
- 智能提醒：高流量、应用突增、断流/恢复和代理/VPN 归因差异
- 今日与最近 7 天本地估算统计
- 实时 Top 应用和今日累计 Top 应用
- 首次引导开启 macOS 通知权限，所有提醒都可在偏好设置中关闭
- 菜单栏内置预设，支持极简、总流量、应用关注和宠物模式
```

Add note:

```markdown
历史统计是基于本地采样的估算值，用于趋势判断，不等同于运营商或系统账单数据。
```

- [ ] **Step 4: Verify version references**

Run:

```bash
rg -n "0\\.37\\.1|0\\.38\\.0|v0\\.38\\.0" Resources CHANGELOG.md README.md Sources Tests
```

Expected: `Info.plist` uses `0.38.0`, changelog contains `v0.38.0`, and no stale app version remains in release metadata.

- [ ] **Step 5: Commit**

```bash
git add README.md CHANGELOG.md Resources/Info.plist
git commit -m "release: v0.38.0"
```

## Task 12: Full Verification And Release Package

**Files:**
- All changed source, tests, docs, and release files.

- [ ] **Step 1: Run full test suite**

Run:

```bash
swift test
```

Expected:

```text
Executed ... tests, with 0 failures
```

- [ ] **Step 2: Run release build**

Run:

```bash
./Scripts/build-app.sh
```

Expected: exits 0 and prints:

```text
/Users/xufan65/WorkSpace/code/ai/NetBar/build/NetBar.app
```

- [ ] **Step 3: Verify built app version**

Run:

```bash
plutil -p build/NetBar.app/Contents/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion"
```

Expected:

```text
"CFBundleShortVersionString" => "0.38.0"
"CFBundleVersion" => "0.38.0"
```

- [ ] **Step 4: Package release**

Run:

```bash
./Scripts/package-release.sh
```

Expected: exits 0 and produces:

```text
dist/NetBar.app.zip
dist/NetBar.app.zip.sha256
```

- [ ] **Step 5: Verify package checksum**

Run:

```bash
shasum -a 256 -c dist/NetBar.app.zip.sha256
```

Expected:

```text
dist/NetBar.app.zip: OK
```

- [ ] **Step 6: Inspect final git state**

Run:

```bash
git status --short --branch
git log --oneline --decorate -n 5
```

Expected: branch contains all v0.38 commits and only expected generated ignored build artifacts are present.

## Self-Review Checklist

- Spec coverage:
  - Anomaly detection: Tasks 1, 3, 5, 10.
  - Today and 7-day history: Tasks 1, 2, 5, 6.
  - Realtime and today app Top: Tasks 2, 5, 6.
  - Notification onboarding and controller: Tasks 4, 7, 10.
  - Built-in menu bar presets: Task 8.
  - Pet intelligence: Task 9 and Task 10.
  - Release docs and version: Task 11 and Task 12.
- Placeholder scan: no task depends on undefined future decisions.
- Type consistency: shared types are introduced before use in dependent tasks.
- Scope check: this is one public release, but tasks are ordered so each phase produces testable software.
