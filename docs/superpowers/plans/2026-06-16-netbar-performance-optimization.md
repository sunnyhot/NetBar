# NetBar Performance Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce NetBar's background overhead, render cost, disk I/O, and detail-window derived-data work while preserving current behavior.

**Architecture:** Introduce a pure sampling policy layer, keep `NetworkMonitor` as the owner of published runtime state, batch `NetworkHistoryStore` disk writes behind explicit flush points, and replace duplicate status-bar metric sampling with `NetworkMonitor.systemResources`. Add bounded caches around status bar rendering and build app-traffic/detail presentation models before SwiftUI consumes them.

**Tech Stack:** Swift 5 language mode, Swift Package Manager, AppKit, SwiftUI, Combine, Foundation, XCTest.

---

## File Structure

- Create: `Sources/NetBar/PerformanceSamplingPolicy.swift`
  - Pure policy types that compute sampling intervals and enabled samplers from state.
- Modify: `Sources/NetBar/NetworkMonitor.swift`
  - Consume sampling policy values, expose a history flush hook, and reuse one system metrics source.
- Modify: `Sources/NetBar/NetworkHistoryStore.swift`
  - Batch disk writes with a 20-second debounce and add `flushNow()`.
- Modify: `Sources/NetBar/StatusBarController.swift`
  - Remove the parallel `SystemMetricsSampler`, derive animation speed from `monitor.systemResources`, and use a dedicated render cache object.
- Modify: `Sources/NetBar/SystemMetricsReader.swift`
  - Keep `AnimationSpeedMapper`; remove or stop using `SystemMetricsSampler` after the controller no longer depends on it.
- Create: `Sources/NetBar/StatusBarRenderCache.swift`
  - Bounded image cache and cache key helpers used by the status bar controller and renderer.
- Modify: `Sources/NetBar/StatusBarStyle.swift`
  - Add small cache seams for layout/character rendering without changing visual output.
- Modify: `Sources/NetBar/ApplicationTrafficPresentation.swift`
  - Add a presentation model builder for visible apps, attribution summary, and summary metrics.
- Modify: `Sources/NetBar/NetworkHistoryPresentation.swift`
  - Add a history-window point model so chart filtering is testable outside SwiftUI `body`.
- Modify: `Sources/NetBar/NetworkPopoverView.swift`
  - Consume presentation models instead of recomputing app list and summary values in `body`.
- Modify: `Sources/NetBar/AppDelegate.swift`
  - Flush history on application termination.
- Modify: `Tests/NetBarTests/SystemResourceTests.swift`
  - Add sampling-policy, shared-metrics, monitor, and history batching tests.
- Modify: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
  - Add render cache and detail presentation tests; update or remove obsolete `SystemMetricsSampler` tests.

## Task 1: Add Pure Sampling Policy

**Files:**
- Create: `Sources/NetBar/PerformanceSamplingPolicy.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing policy tests**

Add these tests near the `NetworkMonitor System Resource Integration` section in `Tests/NetBarTests/SystemResourceTests.swift`:

```swift
func testPerformanceSamplingPolicyForBackgroundIdleState() {
    let policy = PerformanceSamplingCoordinator.policy(for: PerformanceSamplingState(
        isRunning: true,
        isDetailWindowVisible: false,
        isScreenLocked: false,
        isLowPowerModeEnabled: false,
        activityLevel: .idle,
        showsStatusAnimation: true,
        animationSpeedSource: .networkSpeed
    ))

    XCTAssertEqual(policy.interfaceInterval, 3.0)
    XCTAssertFalse(policy.isApplicationTrafficEnabled)
    XCTAssertEqual(policy.systemResourceInterval, 5.0)
    XCTAssertFalse(policy.isAnimationMetricSamplingEnabled)
}

func testPerformanceSamplingPolicyForDetailVisibleState() {
    let policy = PerformanceSamplingCoordinator.policy(for: PerformanceSamplingState(
        isRunning: true,
        isDetailWindowVisible: true,
        isScreenLocked: false,
        isLowPowerModeEnabled: false,
        activityLevel: .high,
        showsStatusAnimation: true,
        animationSpeedSource: .autoComposite
    ))

    XCTAssertEqual(policy.interfaceInterval, 1.0)
    XCTAssertTrue(policy.isApplicationTrafficEnabled)
    XCTAssertEqual(policy.systemResourceInterval, 5.0)
    XCTAssertTrue(policy.isAnimationMetricSamplingEnabled)
}

func testPerformanceSamplingPolicyForLowPowerAndLockedStates() {
    let lowPower = PerformanceSamplingCoordinator.policy(for: PerformanceSamplingState(
        isRunning: true,
        isDetailWindowVisible: true,
        isScreenLocked: false,
        isLowPowerModeEnabled: true,
        activityLevel: .moderate,
        showsStatusAnimation: true,
        animationSpeedSource: .cpuUsage
    ))
    XCTAssertEqual(lowPower.interfaceInterval, 2.0)
    XCTAssertTrue(lowPower.isApplicationTrafficEnabled)
    XCTAssertEqual(lowPower.systemResourceInterval, 10.0)
    XCTAssertTrue(lowPower.isAnimationMetricSamplingEnabled)

    let locked = PerformanceSamplingCoordinator.policy(for: PerformanceSamplingState(
        isRunning: true,
        isDetailWindowVisible: true,
        isScreenLocked: true,
        isLowPowerModeEnabled: false,
        activityLevel: .high,
        showsStatusAnimation: true,
        animationSpeedSource: .autoComposite
    ))
    XCTAssertEqual(locked.interfaceInterval, 0)
    XCTAssertFalse(locked.isApplicationTrafficEnabled)
    XCTAssertEqual(locked.systemResourceInterval, 0)
    XCTAssertFalse(locked.isAnimationMetricSamplingEnabled)
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
swift test --filter SystemResourceTests/testPerformanceSamplingPolicy
```

Expected: fail to compile because `PerformanceSamplingCoordinator`, `PerformanceSamplingState`, and `PerformanceSamplingPolicy` do not exist.

- [ ] **Step 3: Implement the pure policy file**

Create `Sources/NetBar/PerformanceSamplingPolicy.swift`:

```swift
import Foundation

struct PerformanceSamplingState: Equatable {
    let isRunning: Bool
    let isDetailWindowVisible: Bool
    let isScreenLocked: Bool
    let isLowPowerModeEnabled: Bool
    let activityLevel: NetworkActivityLevel
    let showsStatusAnimation: Bool
    let animationSpeedSource: AnimationSpeedSource
}

struct PerformanceSamplingPolicy: Equatable {
    let interfaceInterval: TimeInterval
    let isApplicationTrafficEnabled: Bool
    let applicationTrafficInterval: TimeInterval
    let systemResourceInterval: TimeInterval
    let isAnimationMetricSamplingEnabled: Bool

    static let stopped = PerformanceSamplingPolicy(
        interfaceInterval: 0,
        isApplicationTrafficEnabled: false,
        applicationTrafficInterval: 0,
        systemResourceInterval: 0,
        isAnimationMetricSamplingEnabled: false
    )
}

enum PerformanceSamplingCoordinator {
    static func policy(for state: PerformanceSamplingState) -> PerformanceSamplingPolicy {
        guard state.isRunning, !state.isScreenLocked else { return .stopped }

        let interfaceInterval = state.activityLevel.baseInterval * (state.isLowPowerModeEnabled ? 2 : 1)
        let applicationInterval: TimeInterval = state.isLowPowerModeEnabled ? 5.0 : 1.0
        let systemInterval: TimeInterval = state.isLowPowerModeEnabled ? 10.0 : 5.0
        let needsAnimationMetrics = state.showsStatusAnimation && state.animationSpeedSource != .networkSpeed

        return PerformanceSamplingPolicy(
            interfaceInterval: interfaceInterval,
            isApplicationTrafficEnabled: state.isDetailWindowVisible,
            applicationTrafficInterval: state.isDetailWindowVisible ? applicationInterval : 0,
            systemResourceInterval: systemInterval,
            isAnimationMetricSamplingEnabled: needsAnimationMetrics
        )
    }
}
```

- [ ] **Step 4: Run the policy tests**

Run:

```bash
swift test --filter SystemResourceTests/testPerformanceSamplingPolicy
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/PerformanceSamplingPolicy.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: add performance sampling policy"
```

## Task 2: Apply Sampling Policy In NetworkMonitor

**Files:**
- Modify: `Sources/NetBar/NetworkMonitor.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing monitor policy tests**

Add tests after the existing power-save sampling tests:

```swift
func testNetworkMonitorSamplingPolicyReflectsVisibilityAndPowerMode() {
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

    monitor.start()
    XCTAssertFalse(monitor.currentSamplingPolicy.isApplicationTrafficEnabled)
    XCTAssertEqual(monitor.currentSamplingPolicy.systemResourceInterval, 5.0)

    monitor.isApplicationTrafficVisible = true
    XCTAssertTrue(monitor.currentSamplingPolicy.isApplicationTrafficEnabled)
    XCTAssertEqual(monitor.currentSamplingPolicy.applicationTrafficInterval, 1.0)

    monitor.setPowerSaveMode(true)
    XCTAssertEqual(monitor.currentSamplingPolicy.applicationTrafficInterval, 5.0)
    XCTAssertEqual(monitor.currentSamplingPolicy.systemResourceInterval, 10.0)

    monitor.stop()
}

func testNetworkMonitorLockedPolicyStopsSamplers() {
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

    monitor.start()
    monitor.setScreenLockedForSampling(true)

    XCTAssertEqual(monitor.currentSamplingPolicy, .stopped)
    XCTAssertFalse(monitor.samplingDiagnostics.isRunning)
}
```

- [ ] **Step 2: Run the failing monitor tests**

Run:

```bash
swift test --filter SystemResourceTests/testNetworkMonitorSamplingPolicy
swift test --filter SystemResourceTests/testNetworkMonitorLockedPolicyStopsSamplers
```

Expected: fail to compile because `currentSamplingPolicy` and `setScreenLockedForSampling(_:)` do not exist.

- [ ] **Step 3: Add policy state to NetworkMonitor**

In `Sources/NetBar/NetworkMonitor.swift`, add state and a computed policy:

```swift
private var isScreenLockedForSampling = false

var currentSamplingPolicy: PerformanceSamplingPolicy {
    PerformanceSamplingCoordinator.policy(for: PerformanceSamplingState(
        isRunning: isRunning,
        isDetailWindowVisible: shouldSampleApplicationTraffic,
        isScreenLocked: isScreenLockedForSampling,
        isLowPowerModeEnabled: powerSaveMode,
        activityLevel: activityLevel,
        showsStatusAnimation: true,
        animationSpeedSource: .networkSpeed
    ))
}
```

Add the setter near `setPowerSaveMode(_:)`:

```swift
func setScreenLockedForSampling(_ locked: Bool) {
    guard isScreenLockedForSampling != locked else { return }
    isScreenLockedForSampling = locked
    if locked {
        stop()
    } else if !isRunning {
        start()
    } else {
        rescheduleTimers()
    }
}
```

- [ ] **Step 4: Route timers through policy values**

Replace `applicationSampleInterval` with:

```swift
private var applicationSampleInterval: TimeInterval {
    currentSamplingPolicy.applicationTrafficInterval > 0
        ? currentSamplingPolicy.applicationTrafficInterval
        : (powerSaveMode ? 5.0 : 1.0)
}
```

Change `scheduleSystemResourceTimer()`:

```swift
private func scheduleSystemResourceTimer() {
    let resourceInterval = currentSamplingPolicy.systemResourceInterval
    systemResourceTimer?.invalidate()
    systemResourceTimer = nil
    guard resourceInterval > 0 else { return }

    systemResourceTimer = Timer.scheduledTimer(withTimeInterval: resourceInterval, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.refreshSystemResources()
        }
    }
}
```

Change `scheduleNextSample()`:

```swift
private func scheduleNextSample() {
    timer?.invalidate()
    timer = nil
    let interval = currentSamplingPolicy.interfaceInterval
    guard interval > 0 else { return }

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.refresh()
            self?.scheduleNextSample()
        }
    }
}
```

Update `rescheduleTimers()` so app traffic is enabled only from policy:

```swift
private func rescheduleTimers() {
    guard isRunning else { return }

    scheduleNextSample()

    if currentSamplingPolicy.isApplicationTrafficEnabled {
        scheduleApplicationTrafficTimer()
    } else {
        applicationTimer?.invalidate()
        applicationTimer = nil
    }

    scheduleSystemResourceTimer()
}
```

- [ ] **Step 5: Route screen-lock handling through the policy setter**

In `StatusBarController`, replace the body of the `powerObserver.$isScreenLocked` sink with:

```swift
guard let self else { return }
if isLocked {
    self.flushAnimationPlaybackCount()
    self.catAnimation?.pauseForScreenLock()
    self.pauseGooglyEyesTracking()
    self.monitor.setScreenLockedForSampling(true)
} else {
    self.monitor.setScreenLockedForSampling(false)
    self.catAnimation?.resumeFromScreenLock()
    self.configureGooglyEyesTracking()
    self.lastRenderSignature = nil
    self.requestRender()
}
```

- [ ] **Step 6: Run monitor policy tests**

Run:

```bash
swift test --filter SystemResourceTests/testNetworkMonitorSamplingPolicy
swift test --filter SystemResourceTests/testNetworkMonitorLockedPolicyStopsSamplers
```

Expected: pass.

- [ ] **Step 7: Run existing sampling tests**

Run:

```bash
swift test --filter SystemResourceTests/testPowerSaveRescheduleDoesNotSampleAppTrafficWhenNotVisible
swift test --filter SystemResourceTests/testStartDoesNotSampleAppTrafficWhenNotVisible
```

Expected: pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/NetBar/NetworkMonitor.swift Sources/NetBar/StatusBarController.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "feat: apply performance sampling policy"
```

## Task 3: Batch Network History Disk Writes

**Files:**
- Modify: `Sources/NetBar/NetworkHistoryStore.swift`
- Modify: `Sources/NetBar/NetworkMonitor.swift`
- Modify: `Sources/NetBar/AppDelegate.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write failing history batching tests**

Add these tests near the existing `NetworkHistoryStore` tests in `PreferencesAndPresentationTests.swift`:

```swift
func testNetworkHistoryStoreDefersDiskWriteUntilFlush() throws {
    let root = try temporaryDirectory()
    let historyURL = root.appendingPathComponent("NetworkHistory.json")
    let store = NetworkHistoryStore(
        rootDirectory: root,
        calendar: fixedCalendar(),
        now: { Date(timeIntervalSince1970: 0) },
        saveDebounceInterval: 20
    )

    store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000))

    XCTAssertFalse(FileManager.default.fileExists(atPath: historyURL.path))

    store.flushNow()

    XCTAssertTrue(FileManager.default.fileExists(atPath: historyURL.path))
}

func testNetworkHistoryStoreClearFlushesImmediately() throws {
    let root = try temporaryDirectory()
    let historyURL = root.appendingPathComponent("NetworkHistory.json")
    let store = NetworkHistoryStore(
        rootDirectory: root,
        calendar: fixedCalendar(),
        now: { Date(timeIntervalSince1970: 0) },
        saveDebounceInterval: 20
    )

    store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000))
    store.clear()

    XCTAssertTrue(FileManager.default.fileExists(atPath: historyURL.path))
    let reloaded = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
    XCTAssertEqual(reloaded.summary.today.downloadBytes, 0)
    XCTAssertEqual(reloaded.summary.today.uploadBytes, 0)
}
```

Add this monitor flush test in `SystemResourceTests.swift`:

```swift
func testNetworkMonitorStopFlushesHistoryStore() async throws {
    var currentDate = Date(timeIntervalSince1970: 100)
    let root = try temporaryDirectoryForSystemTests()
    let historyURL = root.appendingPathComponent("NetworkHistory.json")
    let monitor = NetworkMonitor(
        reader: SequenceNetworkStatsReader(samples: [
            [InterfaceStats(name: "en0", receivedBytes: 1_000, sentBytes: 2_000, receivedPackets: 1, sentPackets: 1)],
            [InterfaceStats(name: "en0", receivedBytes: 2_000, sentBytes: 3_500, receivedPackets: 2, sentPackets: 2)]
        ]),
        appTrafficReader: EmptyApplicationTrafficReader(),
        systemResourceReader: MockSystemResourceReader(
            memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUTickSample(total: 0, user: 0, system: 0, idle: 0),
            thermal: ThermalInfo(state: .nominal)
        ),
        resourceReader: MockApplicationResourceReader(processes: []),
        historyStore: NetworkHistoryStore(rootDirectory: root, now: { currentDate }, saveDebounceInterval: 20),
        now: { currentDate }
    )

    monitor.refresh()
    await waitForSnapshotSamples(1, monitor: monitor)
    currentDate = currentDate.addingTimeInterval(1)
    monitor.refresh()
    await waitForSnapshotSamples(2, monitor: monitor)

    XCTAssertFalse(FileManager.default.fileExists(atPath: historyURL.path))

    monitor.stop()

    XCTAssertTrue(FileManager.default.fileExists(atPath: historyURL.path))
}
```

- [ ] **Step 2: Run the failing history tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStoreDefersDiskWriteUntilFlush
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStoreClearFlushesImmediately
swift test --filter SystemResourceTests/testNetworkMonitorStopFlushesHistoryStore
```

Expected: fail to compile because `saveDebounceInterval` and `flushNow()` do not exist.

- [ ] **Step 3: Add dirty-state batching to NetworkHistoryStore**

In `NetworkHistoryStore`, add properties:

```swift
private let saveDebounceInterval: TimeInterval
private var pendingSaveTimer: Timer?
private var isDirty = false
```

Update the initializer signature:

```swift
init(
    rootDirectory: URL? = nil,
    calendar: Calendar = .current,
    retentionDays: Int = 30,
    now: @escaping () -> Date = Date.init,
    saveDebounceInterval: TimeInterval = 20
) {
    self.calendar = calendar
    self.now = now
    self.retentionDays = max(retentionDays, 1)
    self.saveDebounceInterval = saveDebounceInterval
    let root = rootDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("NetBar", isDirectory: true)
    self.fileURL = root.appendingPathComponent("NetworkHistory.json")
    self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
}
```

Replace `publishAndSave(realtimeTopApplications:)` with:

```swift
private func publishAndScheduleSave(realtimeTopApplications: [ApplicationTrafficRate]) {
    summary = NetworkIntelligenceSummary(
        latestEvent: summary.latestEvent,
        today: state.today,
        recentDays: state.recentDays,
        realtimeTopApplications: realtimeTopApplications,
        todayTopApplications: Array(state.today.topApplications.prefix(5)),
        animationPlaybackCountsByCharacter: state.animationPlaybackCountsByCharacter,
        insightCards: summary.insightCards
    )
    scheduleSave()
}
```

Change each existing `publishAndSave(realtimeTopApplications:)` call to `publishAndScheduleSave(realtimeTopApplications:)`. After `clear()` publishes, call `flushNow()` in the same method so the cleared state is durable immediately.

Add:

```swift
func flushNow() {
    pendingSaveTimer?.invalidate()
    pendingSaveTimer = nil
    guard isDirty else { return }
    save()
    isDirty = false
}

private func scheduleSave() {
    isDirty = true
    guard pendingSaveTimer == nil else { return }
    let timer = Timer(timeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.flushNow()
        }
    }
    RunLoop.main.add(timer, forMode: .common)
    pendingSaveTimer = timer
}
```

In `clear()`, call `flushNow()` after publishing:

```swift
publishAndScheduleSave(realtimeTopApplications: [])
flushNow()
```

In `rolloverIfNeeded(for:)`, flush after the day state changes:

```swift
state.today = .empty(dateKey: key)
lastSnapshot = nil
lastApplicationTotals = [:]
```

Do not call `flushNow()` inside `rolloverIfNeeded(for:)` directly; the caller records the new sample and then schedules a save containing both the rollover and the new sample. The mandatory durability point is covered by `stop()`, app termination, and `clear()`.

- [ ] **Step 4: Add monitor and app lifecycle flush hooks**

In `NetworkMonitor`, add:

```swift
func flushNetworkHistory() {
    historyStore.flushNow()
}
```

In `stop()`, before `isRunning = false`, add:

```swift
flushNetworkHistory()
```

In `AppDelegate`, add:

```swift
func applicationWillTerminate(_ notification: Notification) {
    statusBarController?.flushNetworkHistory()
    networkHistoryStore.flushNow()
}
```

In `StatusBarController`, add:

```swift
func flushNetworkHistory() {
    monitor.flushNetworkHistory()
}
```

- [ ] **Step 5: Run history batching tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStoreDefersDiskWriteUntilFlush
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStoreClearFlushesImmediately
swift test --filter SystemResourceTests/testNetworkMonitorStopFlushesHistoryStore
```

Expected: pass.

- [ ] **Step 6: Run existing history tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStore
```

Expected: pass after adding `store.flushNow()` before each reload assertion in existing tests that create a second `NetworkHistoryStore` to read data written by the first store. Apply this to `testNetworkHistoryStorePersistsAndReloadsNormalizedSummary()` and `testNetworkHistoryStoreRollsPersistedYesterdayIntoRecentDaysOnInit()`.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/NetworkHistoryStore.swift Sources/NetBar/NetworkMonitor.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/AppDelegate.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift Tests/NetBarTests/SystemResourceTests.swift
git commit -m "perf: batch network history persistence"
```

## Task 4: Share System Metrics With Status Bar Animation

**Files:**
- Modify: `Sources/NetBar/StatusBarController.swift`
- Modify: `Sources/NetBar/SystemMetricsReader.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Test: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Write mapper tests for SystemResourceSnapshot animation levels**

Add these tests to `SystemResourceTests.swift` near the `SystemResourceSnapshot` tests:

```swift
func testAnimationSpeedMapperUsesSystemResourceSnapshotValues() {
    let snapshot = SystemResourceSnapshot(
        memory: MemoryUsage(totalBytes: 100, usedBytes: 70, swapTotalBytes: 0, swapUsedBytes: 0),
        cpu: CPUUsage(totalTicks: 100, userTicks: 80, systemTicks: 10, idleTicks: 10),
        thermal: ThermalInfo(state: .serious)
    )

    XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromSystemResources: snapshot, source: .memoryUsage), .moderate)
    XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromSystemResources: snapshot, source: .cpuUsage), .high)
    XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromSystemResources: snapshot, source: .thermalState), .moderate)
}

func testAnimationSpeedMapperAutoCompositeUsesNetworkAndSystemResources() {
    let snapshot = SystemResourceSnapshot(
        memory: MemoryUsage(totalBytes: 100, usedBytes: 10, swapTotalBytes: 0, swapUsedBytes: 0),
        cpu: CPUUsage(totalTicks: 100, userTicks: 10, systemTicks: 0, idleTicks: 90),
        thermal: ThermalInfo(state: .nominal)
    )

    let idle = AnimationSpeedMapper.activityLevel(
        fromSystemResources: snapshot,
        source: .autoComposite,
        networkActivityLevel: .idle
    )
    let highNetwork = AnimationSpeedMapper.activityLevel(
        fromSystemResources: snapshot,
        source: .autoComposite,
        networkActivityLevel: .high
    )

    XCTAssertEqual(idle, .idle)
    XCTAssertEqual(highNetwork, .low)
}
```

- [ ] **Step 2: Run failing mapper tests**

Run:

```bash
swift test --filter SystemResourceTests/testAnimationSpeedMapper
```

Expected: fail to compile because `activityLevel(fromSystemResources:source:)` does not exist.

- [ ] **Step 3: Add snapshot-based mapper methods**

In `Sources/NetBar/SystemMetricsReader.swift`, keep `AnimationSpeedMapper` and add:

```swift
extension AnimationSpeedMapper {
    static func activityLevel(
        fromSystemResources snapshot: SystemResourceSnapshot,
        source: AnimationSpeedSource,
        networkActivityLevel: ActivityLevel = .idle
    ) -> ActivityLevel {
        switch source {
        case .networkSpeed:
            return networkActivityLevel
        case .memoryUsage:
            return activityLevel(from: snapshot.memory.usedFraction)
        case .cpuUsage:
            return activityLevel(from: snapshot.cpu.usageFraction)
        case .thermalState:
            return activityLevel(fromThermalState: snapshot.thermal.state.animationSpeedValue)
        case .autoComposite:
            return autoCompositeActivityLevel(
                cpuUsage: snapshot.cpu.usageFraction,
                memoryUsage: snapshot.memory.usedFraction,
                thermalState: snapshot.thermal.state.animationSpeedValue,
                networkActivityLevel: networkActivityLevel
            )
        }
    }
}

private extension ThermalPressureState {
    var animationSpeedValue: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }
}
```

- [ ] **Step 4: Remove status bar's parallel metric sampler**

In `StatusBarController`, remove:

```swift
private let systemMetricsSampler: SystemMetricsSampler
```

Remove the `systemMetricsSampler` initializer parameter and assignment. Remove `configureSystemMetricsSampler()` and its call from `init`.

Add a Combine observer in `configureObservers()`:

```swift
monitor.$systemResources
    .removeDuplicates()
    .sink { [weak self] _ in
        guard let self else { return }
        guard self.settings.showsCat else { return }
        guard self.settings.resolvedAnimationSpeedSource != .networkSpeed else { return }
        self.requestRender()
    }
    .store(in: &cancellables)
```

In `updateStatusItem()`, replace the CPU, memory, thermal, and auto-composite branches with:

```swift
case .cpuUsage, .memoryUsage, .thermalState:
    let level = AnimationSpeedMapper.activityLevel(
        fromSystemResources: monitor.systemResources,
        source: source
    )
    catAnimation?.updateActivityLevel(level)
case .autoComposite:
    let totalBps = monitor.snapshot.uploadBytesPerSecond + monitor.snapshot.downloadBytesPerSecond
    let networkLevel: ActivityLevel
    if totalBps < 100 {
        networkLevel = .idle
    } else if totalBps < 1_000 {
        networkLevel = .low
    } else if totalBps < 100_000 {
        networkLevel = .moderate
    } else {
        networkLevel = .high
    }
    let compositeLevel = AnimationSpeedMapper.activityLevel(
        fromSystemResources: monitor.systemResources,
        source: .autoComposite,
        networkActivityLevel: networkLevel
    )
    catAnimation?.updateActivityLevel(compositeLevel)
```

In the screen-lock observer, remove `self.systemMetricsSampler.stop()` and `self.systemMetricsSampler.start()`.

- [ ] **Step 5: Remove obsolete sampler tests**

In `PreferencesAndPresentationTests.swift`, delete the `SystemMetricsSampler Tests` section and delete `MockSystemMetricsReader`. Run `rg -n "MockSystemMetricsReader|SystemMetricsSampler" Tests/NetBarTests Sources/NetBar` afterward. Expected: no test references remain, and the only source reference is the type declaration if Task 4 leaves `SystemMetricsSampler` in `SystemMetricsReader.swift` for future compatibility.

- [ ] **Step 6: Run mapper and controller compile tests**

Run:

```bash
swift test --filter SystemResourceTests/testAnimationSpeedMapper
swift test --filter PreferencesAndPresentationTests/testStatusBarAlwaysUsesRetinaImage
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/StatusBarController.swift Sources/NetBar/SystemMetricsReader.swift Tests/NetBarTests/SystemResourceTests.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "perf: share system metrics with status bar animation"
```

## Task 5: Add Bounded Status Bar Render Cache

**Files:**
- Create: `Sources/NetBar/StatusBarRenderCache.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Modify: `Sources/NetBar/StatusBarStyle.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing cache tests**

Add these tests near existing status bar renderer tests:

```swift
func testStatusBarRenderedImageCacheReusesMatchingSignatureAndEvictsOldest() {
    let settings = StatusBarSettings(defaults: isolatedDefaults())
    let cache = StatusBarRenderedImageCache(limit: 2)
    let snapshot = sampleSnapshot(download: 42_000, upload: 9_500)
    let firstSignature = StatusBarDisplayRenderer.signature(
        snapshot: snapshot,
        settings: settings,
        appearanceName: "NSAppearanceNameAqua"
    )
    let secondSignature = StatusBarDisplayRenderer.signature(
        snapshot: sampleSnapshot(download: 43_000, upload: 9_500),
        settings: settings,
        appearanceName: "NSAppearanceNameAqua"
    )
    let thirdSignature = StatusBarDisplayRenderer.signature(
        snapshot: sampleSnapshot(download: 44_000, upload: 9_500),
        settings: settings,
        appearanceName: "NSAppearanceNameAqua"
    )

    let firstImage = NSImage(size: NSSize(width: 10, height: 10))
    let secondImage = NSImage(size: NSSize(width: 11, height: 10))
    let thirdImage = NSImage(size: NSSize(width: 12, height: 10))

    cache.store(firstImage, for: firstSignature)
    cache.store(secondImage, for: secondSignature)

    XCTAssertTrue(cache.image(for: firstSignature) === firstImage)

    cache.store(thirdImage, for: thirdSignature)

    XCTAssertNil(cache.image(for: secondSignature))
    XCTAssertTrue(cache.image(for: firstSignature) === firstImage)
    XCTAssertTrue(cache.image(for: thirdSignature) === thirdImage)
}

func testStatusBarTextLayoutCacheReusesMatchingInputs() {
    let settings = StatusBarSettings(defaults: isolatedDefaults())
    let cache = StatusBarTextLayoutCache(limit: 2)
    let key = StatusBarTextLayoutCacheKey(
        lines: ["down", "up"],
        fontSize: settings.fontSize,
        isBold: settings.isBold,
        lineSpacing: settings.lineSpacing,
        alignment: settings.alignment,
        showsBackground: settings.showsBackground
    )
    let layout = StatusBarCachedTextLayout(
        width: 48,
        horizontalPadding: 2,
        lines: ["down", "up"]
    )

    cache.store(layout, for: key)

    XCTAssertEqual(cache.layout(for: key), layout)
}
```

- [ ] **Step 2: Run failing cache tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarRenderedImageCache
swift test --filter PreferencesAndPresentationTests/testStatusBarTextLayoutCache
```

Expected: fail to compile because the cache types do not exist.

- [ ] **Step 3: Add cache types**

Create `Sources/NetBar/StatusBarRenderCache.swift`:

```swift
import AppKit

@MainActor
final class StatusBarRenderedImageCache {
    private let limit: Int
    private var entries: [(signature: StatusBarRenderSignature, image: NSImage)] = []

    init(limit: Int = 12) {
        self.limit = max(limit, 1)
    }

    func image(for signature: StatusBarRenderSignature) -> NSImage? {
        guard let index = entries.firstIndex(where: { $0.signature == signature }) else { return nil }
        let entry = entries.remove(at: index)
        entries.append(entry)
        return entry.image
    }

    func store(_ image: NSImage, for signature: StatusBarRenderSignature) {
        entries.removeAll { $0.signature == signature }
        entries.append((signature, image))
        while entries.count > limit {
            entries.removeFirst()
        }
    }

    func removeAll() {
        entries.removeAll()
    }
}

struct StatusBarTextLayoutCacheKey: Hashable {
    let lines: [String]
    let fontSize: Double
    let isBold: Bool
    let lineSpacing: Double
    let alignment: StatusBarAlignment
    let showsBackground: Bool
}

struct StatusBarCachedTextLayout: Equatable {
    let width: CGFloat
    let horizontalPadding: CGFloat
    let lines: [String]
}

@MainActor
final class StatusBarTextLayoutCache {
    private let limit: Int
    private var entries: [(key: StatusBarTextLayoutCacheKey, layout: StatusBarCachedTextLayout)] = []

    init(limit: Int = 24) {
        self.limit = max(limit, 1)
    }

    func layout(for key: StatusBarTextLayoutCacheKey) -> StatusBarCachedTextLayout? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        let entry = entries.remove(at: index)
        entries.append(entry)
        return entry.layout
    }

    func store(_ layout: StatusBarCachedTextLayout, for key: StatusBarTextLayoutCacheKey) {
        entries.removeAll { $0.key == key }
        entries.append((key, layout))
        while entries.count > limit {
            entries.removeFirst()
        }
    }
}
```

- [ ] **Step 4: Replace controller array cache**

In `StatusBarController`, replace:

```swift
private var renderedImageCache: [(signature: StatusBarRenderSignature, image: NSImage)] = []
private static let renderedImageCacheLimit = 12
```

with:

```swift
private let renderedImageCache = StatusBarRenderedImageCache(limit: 12)
```

Replace the image lookup and store block in `updateStatusItem()` with:

```swift
let image: NSImage
if let cached = renderedImageCache.image(for: signature) {
    image = cached
} else {
    let scale = button.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    image = StatusBarDisplayRenderer.image(
        snapshot: monitor.snapshot,
        settings: settings,
        scale: scale,
        customCharacterStore: customCharacterStore,
        catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
        googlyEyesState: activeGooglyEyesState,
        smartContext: smartContext
    )
    renderedImageCache.store(image, for: signature)
}
```

When appearance changes, clear both signature and cache:

```swift
self?.lastRenderSignature = nil
self?.lastColorTimeBucket = nil
self?.renderedImageCache.removeAll()
self?.requestRender()
```

- [ ] **Step 5: Add text layout cache seam in renderer**

In `StatusBarDisplayRenderer`, add a static cache:

```swift
private static let textLayoutCache = StatusBarTextLayoutCache(limit: 24)
```

Inside `layout(...)`, compute `lines` first as it does today, then use:

```swift
let cacheKey = StatusBarTextLayoutCacheKey(
    lines: lines,
    fontSize: settings.fontSize,
    isBold: settings.isBold,
    lineSpacing: settings.lineSpacing,
    alignment: settings.alignment,
    showsBackground: settings.showsBackground
)
if settings.usesAutomaticWidth, let cached = textLayoutCache.layout(for: cacheKey) {
    let catExtraWidth = characterExtraWidth(
        settings: settings,
        customCharacterStore: customCharacterStore,
        catFrameIndex: catFrameIndex
    )
    return Layout(
        width: ceil(cached.width + catExtraWidth),
        horizontalPadding: cached.horizontalPadding,
        lines: cached.lines,
        font: font
    )
}
```

After computing `automaticTextWidth`, store:

```swift
textLayoutCache.store(
    StatusBarCachedTextLayout(
        width: ceil(automaticTextWidth + horizontalPadding * 2),
        horizontalPadding: horizontalPadding,
        lines: lines
    ),
    for: cacheKey
)
```

For fixed-width settings, keep returning `settings.clampedWidth` as today.

- [ ] **Step 6: Run cache and renderer tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarRenderedImageCache
swift test --filter PreferencesAndPresentationTests/testStatusBarTextLayoutCache
swift test --filter PreferencesAndPresentationTests/testStatusBar
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/StatusBarRenderCache.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/StatusBarStyle.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "perf: add bounded status bar render caches"
```

## Task 6: Build Detail Presentation Models

**Files:**
- Modify: `Sources/NetBar/ApplicationTrafficPresentation.swift`
- Modify: `Sources/NetBar/NetworkHistoryPresentation.swift`
- Modify: `Sources/NetBar/NetworkPopoverView.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing presentation model tests**

Add these tests near existing `ApplicationTrafficPresentation` tests:

```swift
func testApplicationTrafficPresentationModelBuildsVisibleAppsAndSummary() {
    let snapshot = sampleSnapshot(download: 4_000, upload: 2_000)
    let state = ApplicationTrafficState(
        timestamp: Date(timeIntervalSince1970: 10),
        applications: [
            appRate("Safari", download: 1_500, upload: 500, received: 10_000, sent: 2_000),
            appRate("Helper", download: 0, upload: 0, received: 0, sent: 0, memory: 1_024, cpu: 2)
        ],
        sampleCount: 2,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    )

    let model = ApplicationTrafficPresentation.makeModel(
        snapshot: snapshot,
        state: state,
        hidesSystemProcesses: false,
        sortMode: .activity,
        searchText: "",
        limit: 18
    )

    XCTAssertEqual(model.visibleApplications.map(\.displayName), ["Safari"])
    XCTAssertEqual(model.summaryMetrics, [
        ApplicationTrafficMetric(kind: .download, value: "1.46 KB/s"),
        ApplicationTrafficMetric(kind: .upload, value: "500 B/s")
    ])
    XCTAssertEqual(model.attributionSummary.applicationBytesPerSecond, 2_000)
}

func testApplicationTrafficPresentationModelKeepsMemoryModeResourceOnlyApps() {
    let state = ApplicationTrafficState(
        timestamp: Date(timeIntervalSince1970: 10),
        applications: [
            appRate("Safari", download: 0, upload: 0, memory: 2_048, cpu: 1),
            appRate("Mail", download: 0, upload: 0, memory: 4_096, cpu: 3)
        ],
        sampleCount: 1,
        isRefreshing: false,
        errorMessage: nil,
        systemResources: .empty
    )

    let model = ApplicationTrafficPresentation.makeModel(
        snapshot: .empty,
        state: state,
        hidesSystemProcesses: false,
        sortMode: .memory,
        searchText: "mail",
        limit: 18
    )

    XCTAssertEqual(model.visibleApplications.map(\.displayName), ["Mail"])
    XCTAssertEqual(model.summaryMetrics, [ApplicationTrafficMetric(kind: .memory, value: "4 KB")])
}
```

Extend the `appRate(...)` helper used by these tests at the bottom of `PreferencesAndPresentationTests.swift` so it accepts `memory` and `cpu` parameters:

```swift
private func appRate(
    _ name: String,
    download: Double,
    upload: Double,
    received: UInt64 = 0,
    sent: UInt64 = 0,
    memory: UInt64? = nil,
    cpu: Double? = nil
) -> ApplicationTrafficRate {
    ApplicationTrafficRate(
        id: name,
        displayName: name,
        processNames: [name],
        pids: [],
        downloadBytesPerSecond: download,
        uploadBytesPerSecond: upload,
        totalReceivedBytes: received,
        totalSentBytes: sent,
        residentMemory: memory,
        cpuPercentage: cpu
    )
}
```

- [ ] **Step 2: Run failing presentation tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testApplicationTrafficPresentationModel
```

Expected: fail to compile because `ApplicationTrafficPresentation.makeModel(...)` and its model type do not exist.

- [ ] **Step 3: Add model builder**

In `Sources/NetBar/ApplicationTrafficPresentation.swift`, add:

```swift
struct ApplicationTrafficPresentationModel: Equatable {
    let visibleApplications: [ApplicationTrafficRate]
    let summaryMetrics: [ApplicationTrafficMetric]
    let attributionSummary: ApplicationAttributionSummary
}
```

Add to `ApplicationTrafficPresentation`:

```swift
static func makeModel(
    snapshot: NetworkSnapshot,
    state: ApplicationTrafficState,
    hidesSystemProcesses: Bool,
    sortMode: ApplicationSortMode,
    searchText: String,
    limit: Int = 18
) -> ApplicationTrafficPresentationModel {
    let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let filtered = state.applications.filter { application in
        if hidesSystemProcesses, isLikelySystemProcess(application) {
            return false
        }

        guard !normalizedSearch.isEmpty else { return true }
        let searchableText = ([application.displayName] + application.processNames)
            .joined(separator: " ")
            .lowercased()
        return searchableText.localizedStandardContains(normalizedSearch)
    }
    let displayFiltered = displayApplications(filtered, mode: sortMode)
    let visible = Array(sorted(displayFiltered, by: sortMode).prefix(limit))

    return ApplicationTrafficPresentationModel(
        visibleApplications: visible,
        summaryMetrics: summaryMetrics(for: visible, displayMode: sortMode),
        attributionSummary: attributionSummary(snapshot: snapshot, applications: state.applications)
    )
}
```

Leave `visibleApplications(from:preferences:searchText:limit:)` in place for compatibility, but implement it through the model:

```swift
@MainActor
static func visibleApplications(
    from state: ApplicationTrafficState,
    preferences: AppPreferences,
    searchText: String,
    limit: Int = 18
) -> [ApplicationTrafficRate] {
    makeModel(
        snapshot: .empty,
        state: state,
        hidesSystemProcesses: preferences.hidesSystemProcesses,
        sortMode: preferences.applicationSort,
        searchText: searchText,
        limit: limit
    ).visibleApplications
}
```

- [ ] **Step 4: Add history window point presentation**

Add this test near `testNetworkHistoryPresentationBuildsSevenAndThirtyDaySummaries`:

```swift
func testTrafficHistoryWindowPresentationFiltersPointsAndSummarizesTotals() {
    let latest = Date(timeIntervalSince1970: 1_000)
    let points = [
        RatePoint(timestamp: latest.addingTimeInterval(-400), downloadBytesPerSecond: 10, uploadBytesPerSecond: 1),
        RatePoint(timestamp: latest.addingTimeInterval(-60), downloadBytesPerSecond: 20, uploadBytesPerSecond: 2),
        RatePoint(timestamp: latest, downloadBytesPerSecond: 30, uploadBytesPerSecond: 3)
    ]

    let model = TrafficHistoryWindowPresentation.make(points: points, window: .seconds90)

    XCTAssertEqual(model.points.map(\.downloadBytesPerSecond), [20, 30])
    XCTAssertEqual(model.peakDownloadBytesPerSecond, 30)
    XCTAssertEqual(model.peakUploadBytesPerSecond, 3)
}
```

In `Sources/NetBar/NetworkHistoryPresentation.swift`, add:

```swift
struct TrafficHistoryWindowPresentationModel: Equatable {
    let points: [RatePoint]
    let peakDownloadBytesPerSecond: Double
    let peakUploadBytesPerSecond: Double
}

enum TrafficHistoryWindowPresentation {
    static func make(points: [RatePoint], window: TrafficHistoryWindow) -> TrafficHistoryWindowPresentationModel {
        let filtered = window.points(from: points)
        return TrafficHistoryWindowPresentationModel(
            points: filtered,
            peakDownloadBytesPerSecond: filtered.map(\.downloadBytesPerSecond).max() ?? 0,
            peakUploadBytesPerSecond: filtered.map(\.uploadBytesPerSecond).max() ?? 0
        )
    }
}
```

- [ ] **Step 5: Use models in ApplicationTrafficList and TrafficChart**

In `NetworkPopoverView.swift`, replace the `visibleApplications` computed property with:

```swift
private var presentationModel: ApplicationTrafficPresentationModel {
    ApplicationTrafficPresentation.makeModel(
        snapshot: snapshot,
        state: appTraffic,
        hidesSystemProcesses: preferences.hidesSystemProcesses,
        sortMode: preferences.applicationSort,
        searchText: searchText
    )
}

private var visibleApplications: [ApplicationTrafficRate] {
    presentationModel.visibleApplications
}
```

Replace:

```swift
summary: ApplicationTrafficPresentation.attributionSummary(
    snapshot: snapshot,
    applications: appTraffic.applications
)
```

with:

```swift
summary: presentationModel.attributionSummary
```

Replace the local `summaryMetrics` creation with:

```swift
let summaryMetrics = presentationModel.summaryMetrics
```

In `NetworkPopoverView.body`, replace the inline chart point filtering with:

```swift
let chartPresentation = TrafficHistoryWindowPresentation.make(
    points: monitor.recentHistory,
    window: historyWindow
)
TrafficChart(
    points: chartPresentation.points,
    selectedWindow: $historyWindow,
    appPreferences: appPreferences
)
    .frame(height: 132)
```

- [ ] **Step 6: Run presentation and popover compile tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testApplicationTrafficPresentationModel
swift test --filter PreferencesAndPresentationTests/testTrafficHistoryWindowPresentation
swift test --filter PreferencesAndPresentationTests/testApplicationTrafficPresentation
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/ApplicationTrafficPresentation.swift Sources/NetBar/NetworkHistoryPresentation.swift Sources/NetBar/NetworkPopoverView.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "perf: add application traffic presentation model"
```

## Task 7: Final Verification And Cleanup

**Files:**
- Review: `Sources/NetBar/NetworkMonitor.swift`
- Review: `Sources/NetBar/NetworkHistoryStore.swift`
- Review: `Sources/NetBar/StatusBarController.swift`
- Review: `Sources/NetBar/StatusBarStyle.swift`
- Review: `Sources/NetBar/ApplicationTrafficPresentation.swift`
- Review: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
- Review: `Tests/NetBarTests/SystemResourceTests.swift`

- [ ] **Step 1: Run focused test groups**

Run:

```bash
swift test --filter SystemResourceTests
swift test --filter PreferencesAndPresentationTests/testNetworkHistoryStore
swift test --filter PreferencesAndPresentationTests/testApplicationTrafficPresentation
swift test --filter PreferencesAndPresentationTests/testStatusBar
```

Expected: pass.

- [ ] **Step 2: Run full test suite**

Run:

```bash
swift test
```

Expected: pass.

- [ ] **Step 3: Run release app build**

Run:

```bash
./Scripts/build-app.sh
```

Expected: exits 0 and creates `build/NetBar.app`.

- [ ] **Step 4: Inspect changed files for performance regressions**

Run:

```bash
git diff --stat HEAD~6..HEAD
git diff -- Sources/NetBar/NetworkMonitor.swift Sources/NetBar/NetworkHistoryStore.swift Sources/NetBar/StatusBarController.swift Sources/NetBar/StatusBarStyle.swift Sources/NetBar/ApplicationTrafficPresentation.swift
```

Expected: changes are limited to sampling policy, history batching, shared metrics, render cache, and presentation model work.

- [ ] **Step 5: Commit warning cleanup when files changed**

When Step 4 finds compile-warning cleanup changes, commit them:

```bash
git add Sources/NetBar Tests/NetBarTests
git commit -m "chore: clean up performance optimization warnings"
```

When Step 4 finds no cleanup changes, leave the git history unchanged.
