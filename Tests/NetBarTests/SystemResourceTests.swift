import XCTest
@testable import NetBar

@MainActor
final class SystemResourceTests: XCTestCase {

    // MARK: - MemoryUsage Tests

    func testMemoryUsageComputedProperties() {
        let usage = MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 4_000_000_000, swapUsedBytes: 1_000_000_000)

        XCTAssertEqual(usage.freeBytes, 8_000_000_000)
        XCTAssertEqual(usage.usedFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(usage.usedPercentage, 50.0, accuracy: 0.01)
        XCTAssertEqual(usage.swapUsedFraction, 0.25, accuracy: 0.001)
    }

    func testMemoryUsageZeroTotal() {
        let usage = MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0)

        XCTAssertEqual(usage.freeBytes, 0)
        XCTAssertEqual(usage.usedFraction, 0)
        XCTAssertEqual(usage.usedPercentage, 0)
        XCTAssertEqual(usage.swapUsedFraction, 0)
    }

    func testMemoryUsageMoreUsedThanTotal() {
        // Edge case: usedBytes > totalBytes should not produce negative freeBytes
        let usage = MemoryUsage(totalBytes: 8_000_000_000, usedBytes: 10_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0)

        XCTAssertEqual(usage.freeBytes, 0)
        XCTAssertGreaterThanOrEqual(usage.usedFraction, 1.0)
    }

    func testMemoryUsageNoSwap() {
        let usage = MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0)

        XCTAssertEqual(usage.swapUsedFraction, 0)
    }

    // MARK: - CPUUsage Tests

    func testCPUUsageFromDelta() {
        // Simulate a delta where 25% of ticks are user, 10% are system
        let cpu = CPUUsage(totalTicks: 1000, userTicks: 250, systemTicks: 100, idleTicks: 650)

        XCTAssertEqual(cpu.usageFraction, 0.35, accuracy: 0.001)
        XCTAssertEqual(cpu.usagePercentage, 35.0, accuracy: 0.01)
    }

    func testCPUUsageZeroTicks() {
        let cpu = CPUUsage(totalTicks: 0, userTicks: 0, systemTicks: 0, idleTicks: 0)

        XCTAssertEqual(cpu.usageFraction, 0)
        XCTAssertEqual(cpu.usagePercentage, 0)
    }

    func testCPUUsageFullLoad() {
        let cpu = CPUUsage(totalTicks: 1000, userTicks: 800, systemTicks: 200, idleTicks: 0)

        XCTAssertEqual(cpu.usageFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - ThermalInfo Tests

    func testThermalInfoLocalizedDescription() {
        XCTAssertEqual(ThermalInfo(state: .nominal).localizedDescription, "Nominal")
        XCTAssertEqual(ThermalInfo(state: .fair).localizedDescription, "Fair")
        XCTAssertEqual(ThermalInfo(state: .serious).localizedDescription, "Serious")
        XCTAssertEqual(ThermalInfo(state: .critical).localizedDescription, "Critical")
    }

    func testThermalPressureStateFromProcessInfo() {
        XCTAssertEqual(ThermalPressureState(ProcessInfo.ThermalState.nominal), .nominal)
        XCTAssertEqual(ThermalPressureState(ProcessInfo.ThermalState.fair), .fair)
        XCTAssertEqual(ThermalPressureState(ProcessInfo.ThermalState.serious), .serious)
        XCTAssertEqual(ThermalPressureState(ProcessInfo.ThermalState.critical), .critical)
    }

    // MARK: - SystemResourceSnapshot Tests

    func testSystemResourceSnapshotEmpty() {
        let empty = SystemResourceSnapshot.empty
        XCTAssertEqual(empty.memory.totalBytes, 0)
        XCTAssertEqual(empty.cpu.totalTicks, 0)
        XCTAssertEqual(empty.thermal.state, .nominal)
    }

    func testSystemResourceSnapshotEquality() {
        let a = SystemResourceSnapshot(
            memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUUsage(totalTicks: 100, userTicks: 50, systemTicks: 20, idleTicks: 30),
            thermal: ThermalInfo(state: .nominal)
        )
        let b = SystemResourceSnapshot(
            memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUUsage(totalTicks: 100, userTicks: 50, systemTicks: 20, idleTicks: 30),
            thermal: ThermalInfo(state: .nominal)
        )
        XCTAssertEqual(a, b)
    }

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


    func testMockReaderReturnsConfiguredValues() {
        let mock = MockSystemResourceReader(
            memory: MemoryUsage(totalBytes: 32_000_000_000, usedBytes: 16_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUTickSample(total: 2000, user: 500, system: 200, idle: 1300),
            thermal: ThermalInfo(state: .fair)
        )

        let mem = mock.readMemoryUsage()
        XCTAssertEqual(mem.totalBytes, 32_000_000_000)
        XCTAssertEqual(mem.usedBytes, 16_000_000_000)

        let cpu = mock.readCPUTicks()
        XCTAssertEqual(cpu.total, 2000)
        XCTAssertEqual(cpu.user, 500)

        let thermal = mock.readThermalState()
        XCTAssertEqual(thermal.state, .fair)
    }

    // MARK: - CPUTickSample Tests

    func testCPUTickSampleEquality() {
        let a = CPUTickSample(total: 1000, user: 300, system: 100, idle: 600)
        let b = CPUTickSample(total: 1000, user: 300, system: 100, idle: 600)
        XCTAssertEqual(a, b)
    }

    func testCPUTickSampleInequality() {
        let a = CPUTickSample(total: 1000, user: 300, system: 100, idle: 600)
        let b = CPUTickSample(total: 2000, user: 300, system: 100, idle: 600)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ThermalPressureState Tests

    func testThermalPressureStateEquality() {
        XCTAssertEqual(ThermalPressureState.nominal, ThermalPressureState.nominal)
        XCTAssertNotEqual(ThermalPressureState.nominal, ThermalPressureState.fair)
        XCTAssertNotEqual(ThermalPressureState.fair, ThermalPressureState.serious)
        XCTAssertNotEqual(ThermalPressureState.serious, ThermalPressureState.critical)
    }

    // MARK: - NetworkMonitor System Resource Integration

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
        XCTAssertEqual(policy.systemResourceInterval, 0)
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

    func testNetworkMonitorExposesSamplingDiagnostics() {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 0, user: 0, system: 0, idle: 0),
                thermal: ThermalInfo(state: .nominal)
            ),
        )

        monitor.setPowerSaveMode(true)
        let diagnostics = monitor.samplingDiagnostics

        XCTAssertFalse(diagnostics.isRunning)
        XCTAssertFalse(diagnostics.isApplicationTrafficSamplingEnabled)
        XCTAssertTrue(diagnostics.isPowerSaveModeEnabled)
    }

    func testNetworkMonitorUpdatesNetworkIntelligenceSummary() async throws {
        var currentDate = Date(timeIntervalSince1970: 100)
        let reader = SequenceNetworkStatsReader(samples: [
            [
                InterfaceStats(
                    name: "en0",
                    displayName: "Wi-Fi",
                    receivedBytes: 1_000,
                    sentBytes: 2_000,
                    receivedPackets: 1,
                    sentPackets: 1,
                    isPrimary: true
                )
            ],
            [
                InterfaceStats(
                    name: "en0",
                    displayName: "Wi-Fi",
                    receivedBytes: 3_000,
                    sentBytes: 5_000,
                    receivedPackets: 2,
                    sentPackets: 2,
                    isPrimary: true
                )
            ]
        ])
        let root = try temporaryDirectoryForSystemTests()
        let monitor = NetworkMonitor(
            reader: reader,
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 0, user: 0, system: 0, idle: 0),
                thermal: ThermalInfo(state: .nominal)
            ),
            historyStore: NetworkHistoryStore(rootDirectory: root, now: { currentDate }),
            now: { currentDate }
        )

        monitor.refresh()
        await waitForSnapshotSamples(1, monitor: monitor)
        currentDate = currentDate.addingTimeInterval(1)
        monitor.refresh()
        await waitForSnapshotSamples(2, monitor: monitor)

        XCTAssertEqual(monitor.intelligenceSummary.today.downloadBytes, 2_000)
        XCTAssertEqual(monitor.intelligenceSummary.today.uploadBytes, 3_000)
    }

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


    func testNetworkMonitorRefreshIntelligenceStoresLatestEvent() async throws {
        var currentDate = Date(timeIntervalSince1970: 100)
        let reader = SequenceNetworkStatsReader(samples: [
            [InterfaceStats(name: "en0", receivedBytes: 0, sentBytes: 0, receivedPackets: 1, sentPackets: 1, isPrimary: true)],
            [InterfaceStats(name: "en0", receivedBytes: 12_000_000, sentBytes: 0, receivedPackets: 2, sentPackets: 2, isPrimary: true)],
            [InterfaceStats(name: "en0", receivedBytes: 140_000_000, sentBytes: 0, receivedPackets: 3, sentPackets: 3, isPrimary: true)]
        ])
        let monitor = NetworkMonitor(
            reader: reader,
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 0, user: 0, system: 0, idle: 0),
                thermal: ThermalInfo(state: .nominal)
            ),
            historyStore: NetworkHistoryStore(rootDirectory: try temporaryDirectoryForSystemTests(), now: { currentDate }),
            now: { currentDate }
        )

        monitor.refresh()
        await waitForSnapshotSamples(1, monitor: monitor)
        currentDate = currentDate.addingTimeInterval(1)
        monitor.refresh()
        await waitForSnapshotSamples(2, monitor: monitor)
        XCTAssertTrue(monitor.refreshIntelligence(settings: .default).isEmpty)

        currentDate = currentDate.addingTimeInterval(11)
        monitor.refresh()
        await waitForSnapshotSamples(3, monitor: monitor)
        let events = monitor.refreshIntelligence(settings: .default)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "高流量")
        XCTAssertEqual(monitor.intelligenceSummary.latestEvent?.title, "高流量")
    }

    func testNetworkMonitorRefreshesSystemResources() async {
        let mock = MockSystemResourceReader(
            memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
            thermal: ThermalInfo(state: .nominal)
        )

        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: mock,
            now: Date.init
        )

        // First refresh — should populate initial snapshot
        monitor.refreshSystemResources()

        // Wait briefly for the async Task to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        // First sample: no previous CPU tick data, so CPU usage reports total but usageFraction should be non-zero
        let resources = monitor.systemResources
        XCTAssertEqual(resources.memory.totalBytes, 16_000_000_000)
        XCTAssertEqual(resources.memory.usedBytes, 8_000_000_000)
        XCTAssertEqual(resources.thermal.state, .nominal)
    }

    func testNetworkMonitorCPUDeltaBetweenSamples() async {
        // First sample
        let mock = MockSystemResourceReader(
            memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
            thermal: ThermalInfo(state: .nominal)
        )

        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: mock,
            now: Date.init
        )

        // First refresh
        monitor.refreshSystemResources()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Update mock to simulate second sample with more ticks
        mock.cpu = CPUTickSample(total: 2000, user: 700, system: 200, idle: 1100)

        // Second refresh — now delta should be computed
        monitor.refreshSystemResources()
        try? await Task.sleep(nanoseconds: 200_000_000)

        let cpu = monitor.systemResources.cpu
        // Delta: total=1000, user=400, system=100, idle=500
        XCTAssertEqual(cpu.totalTicks, 1000)
        XCTAssertEqual(cpu.userTicks, 400)
        XCTAssertEqual(cpu.systemTicks, 100)
        XCTAssertEqual(cpu.usagePercentage, 50.0, accuracy: 0.01)
    }

    func testNetworkMonitorStopsResourceTimer() async {
        let mock = MockSystemResourceReader(
            memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
            cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
            thermal: ThermalInfo(state: .nominal)
        )

        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: mock,
            now: Date.init
        )

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testNetworkMonitorStartsAndStops() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testNetworkMonitorRefreshesApplicationTraffic() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            now: Date.init
        )

        // Start the monitor — this sets isRunning and starts timers
        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testNetworkMonitorDoesNotDuplicateTrafficApplicationsWhenAddingResources() async {
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [
                ApplicationTrafficStats(id: "Safari.100", processName: "Safari", displayName: "Safari", pid: 100, receivedBytes: 1_000, sentBytes: 500)
            ], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [
                ApplicationTrafficStats(id: "Safari.100", processName: "Safari", displayName: "Safari", pid: 100, receivedBytes: 2_500, sentBytes: 1_100)
            ], errorMessage: nil),
        ])
        let sampleDates = [
            Date(timeIntervalSince1970: 1_000),
            Date(timeIntervalSince1970: 1_005),
        ]
        var dateIndex = 0
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: {
                defer { dateIndex += 1 }
                return sampleDates[min(dateIndex, sampleDates.count - 1)]
            }
        )

        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficSamples(1, monitor: monitor)
        monitor.refreshApplicationTraffic()
        await waitForApplicationTrafficSamples(2, monitor: monitor)

        XCTAssertEqual(monitor.appTraffic.applications.count, 1)
        let application = monitor.appTraffic.applications.first
        XCTAssertEqual(application?.displayName, "Safari")
        XCTAssertEqual(application?.downloadBytesPerSecond, 300)
        XCTAssertEqual(application?.uploadBytesPerSecond, 120)
    }

    func testNetworkMonitorPowerSaveMode() {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            now: Date.init
        )

        // Should not crash when setting power save mode before start
        monitor.setPowerSaveMode(true)

        monitor.start()
        monitor.setPowerSaveMode(false)

        monitor.stop()
    }

    func testNetworkMonitorSamplingPolicyReflectsVisibilityAndPowerMode() {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 0, user: 0, system: 0, idle: 0),
                thermal: ThermalInfo(state: .nominal)
            ),
        )

        monitor.start()
        XCTAssertFalse(monitor.currentSamplingPolicy.isApplicationTrafficEnabled)
        XCTAssertEqual(monitor.currentSamplingPolicy.systemResourceInterval, 0)

        monitor.isApplicationTrafficVisible = true
        XCTAssertTrue(monitor.currentSamplingPolicy.isApplicationTrafficEnabled)
        XCTAssertEqual(monitor.currentSamplingPolicy.applicationTrafficInterval, 1.0)

        monitor.configureAnimationMetricSampling(showsAnimation: true, speedSource: .cpuUsage)
        XCTAssertEqual(monitor.currentSamplingPolicy.systemResourceInterval, 5.0)

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
        )

        monitor.start()
        monitor.setScreenLockedForSampling(true)

        XCTAssertEqual(monitor.currentSamplingPolicy, .stopped)
        XCTAssertFalse(monitor.samplingDiagnostics.isRunning)
    }

    // MARK: - Application Traffic State Machine Tests (LUC-231)

    func testRefreshApplicationTrafficBlockedWhenSamplingDisabled() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            now: Date.init
        )

        // shouldSampleApplicationTraffic defaults to false, so refreshApplicationTraffic should be a no-op
        monitor.refreshApplicationTraffic()
        // appTraffic should remain in empty state (not isRefreshing)
        XCTAssertFalse(monitor.appTraffic.isRefreshing)
        XCTAssertEqual(monitor.appTraffic.sampleCount, 0)
    }

    func testRefreshApplicationTrafficFirstSampleTransitionsOutOfRefreshing() async {
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        // Enable sampling (simulates popover opening)
        monitor.isApplicationTrafficVisible = true

        // Give the async Task time to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        // After first sample completes, isRefreshing must be false
        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false after first sample completes")
        XCTAssertNil(monitor.appTraffic.errorMessage, "No error expected for empty results")
        XCTAssertGreaterThanOrEqual(monitor.appTraffic.sampleCount, 1, "sampleCount should be at least 1 after first sample (基线后可能立即跟随采样)")
    }

    func testRefreshApplicationTrafficErrorTransitionsOutOfRefreshing() async {
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [], errorMessage: "nettop failed"),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false after error sample")
        XCTAssertNotNil(monitor.appTraffic.errorMessage, "Error message should be set")
    }

    func testRefreshApplicationTrafficReentrancyGuard() async {
        let trafficReader = BlockingApplicationTrafficReader()
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true

        // First call should succeed (starts async task that blocks)
        // Second call should be blocked by isReadingApplicationTraffic guard
        monitor.refreshApplicationTraffic()
        // This second call should be a no-op (guard prevents reentrancy)
        monitor.refreshApplicationTraffic()

        // Unblock the reader
        trafficReader.unblock()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should reset after blocked read completes")
    }

    func testPausedApplicationTrafficIgnoresInFlightResult() async {
        let staleResult = ApplicationTrafficReadResult(
            stats: [
                ApplicationTrafficStats(
                    id: "Stale.42",
                    processName: "Stale",
                    displayName: "Stale",
                    pid: 42,
                    receivedBytes: 4_096,
                    sentBytes: 2_048
                )
            ],
            errorMessage: nil
        )
        let trafficReader = BlockingApplicationTrafficReader(result: staleResult)
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[
                InterfaceStats(
                    name: "en0",
                    receivedBytes: 100,
                    sentBytes: 50,
                    receivedPackets: 10,
                    sentPackets: 5
                )
            ]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        let startDeadline = Date().addingTimeInterval(1)
        while !trafficReader.hasStarted && Date() < startDeadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(trafficReader.hasStarted)
        monitor.isApplicationTrafficVisible = false
        trafficReader.unblock()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(monitor.appTraffic.sampleCount, 0)
        XCTAssertTrue(monitor.appTraffic.applications.isEmpty)
        XCTAssertFalse(monitor.appTraffic.isRefreshing)
    }

    func testStartDoesNotCreateAppTrafficTimerWhenNotVisible() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        // start() should not trigger app traffic sampling when popover is not visible
        monitor.start()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // appTraffic should remain in empty state
        XCTAssertEqual(monitor.appTraffic.sampleCount, 0, "start() should not sample app traffic when sampling disabled")

        monitor.stop()
    }

    func testPowerSaveRescheduleDoesNotSampleAppTrafficWhenNotVisible() async {
        let trafficReader = TrackingApplicationTrafficReader()
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.start()
        monitor.setPowerSaveMode(true)
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        XCTAssertEqual(trafficReader.callCount, 0, "Power-save reschedule must not start app traffic sampling while hidden")

        monitor.stop()
    }

    func testPauseAndResumeSamplingResetsState() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.start()

        // Open popover → starts sampling
        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertFalse(monitor.appTraffic.isRefreshing, "Should finish refreshing after first sample")

        // Close popover → stops sampling
        monitor.isApplicationTrafficVisible = false

        // Reopen popover → should be able to sample again
        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertFalse(monitor.appTraffic.isRefreshing, "Should finish refreshing after resume")

        monitor.stop()
    }

    // MARK: - Application Traffic Loading State Tests

    func testFirstSampleEmptyDataWithStreamingStopsRefreshing() async {
        // When streamingReader is active (appTrafficReader omitted) and the first sample is empty,
        // the completed sample should stop the loading state. Future timer ticks can keep retrying
        // in the background without leaving the popover stuck on "正在读取应用流量".
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        // Verify streamingReader is active
        XCTAssertNotNil(monitor.streamingReader, "streamingReader should be non-nil when appTrafficReader is omitted")

        // Enable sampling
        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false after the first streaming sample completes")
        XCTAssertGreaterThanOrEqual(monitor.appTraffic.sampleCount, 1)
    }

    func testFirstSampleEmptyDataWithoutStreamingStopsRefreshing() async {
        // When streamingReader is nil (appTrafficReader provided) and first sample is empty,
        // isRefreshing should be false — no keepRefreshing logic applies.
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        // Verify streamingReader is nil
        XCTAssertNil(monitor.streamingReader, "streamingReader should be nil when appTrafficReader is provided")

        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Empty result + no streaming → isRefreshing must be false
        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false when streamingReader is nil and data is empty")
        XCTAssertGreaterThanOrEqual(monitor.appTraffic.sampleCount, 1)
    }

    func testFirstSampleWithDataStopsRefreshingRegardlessOfStreaming() async {
        // When first sample has data, isRefreshing should be false even if streaming is active.
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [
                ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: 1000, sentBytes: 500),
            ], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false when first sample has data")
        XCTAssertGreaterThanOrEqual(monitor.appTraffic.sampleCount, 1)
        XCTAssertGreaterThanOrEqual(monitor.appTraffic.applications.count, 1)
    }

    func testRepeatedEmptyStreamingSamplesStayOutOfRefreshing() async {
        // Repeated empty samples should keep retrying in the background without
        // putting the empty-state notice back into a loading state.
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        XCTAssertNotNil(monitor.streamingReader)

        monitor.isApplicationTrafficVisible = true

        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 600_000_000)
            monitor.refreshApplicationTraffic()
        }
        await waitForApplicationTrafficIdle(monitor: monitor)

        XCTAssertFalse(monitor.appTraffic.isRefreshing, "Repeated empty samples should not leave the popover in a loading state")
        XCTAssertGreaterThanOrEqual(monitor.appTraffic.sampleCount, 1)
    }

    func testStreamingNettopReaderUsesTerminalBackedOutputForImmediateCSV() async throws {
        let scriptURL = try makeExecutableScript(
            """
            #!/bin/sh
            if [ -t 1 ]; then
              printf ',bytes_in,bytes_out,\\n'
              printf 'Codex.123,4096,2048,\\n'
              sleep 5
            else
              sleep 5
            fi
            """
        )
        let reader = StreamingNettopReader(
            executableURL: URL(fileURLWithPath: "/usr/bin/script"),
            arguments: ["-q", "/dev/null", scriptURL.path]
        )

        reader.start()
        var result = reader.readApplications()
        for _ in 0..<10 where result.stats.isEmpty {
            try await Task.sleep(nanoseconds: 200_000_000)
            result = reader.readApplications()
        }
        reader.stop()

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.stats.count, 1)
        XCTAssertEqual(result.stats.first?.processName, "Codex")
        XCTAssertEqual(result.stats.first?.receivedBytes, 4096)
        XCTAssertEqual(result.stats.first?.sentBytes, 2048)
    }

    func testStreamingNettopReaderReportsSpawnFailure() {
        let reader = StreamingNettopReader(
            executableURL: URL(fileURLWithPath: "/usr/bin/netbar-missing-\(UUID().uuidString)")
        )

        reader.start()
        let result = reader.readApplications()

        XCTAssertEqual(
            result.errorMessage,
            ApplicationTrafficReaderFailure.spawnFailed.rawValue,
            "spawn 失败应通过 readApplications 上报错误"
        )
        reader.stop()
    }

    func testStreamingNettopReaderRecoversViaRestartsWithoutError() async throws {
        // 脚本前 3 次运行立即退出(触发重启),第 4 次输出 CSV 并存活;
        // 重启期间不应误报错误,最终恢复出数据
        let scriptURL = try makeExecutableScript(
            """
            #!/bin/sh
            count_file="$0.count"
            count=$(cat "$count_file" 2>/dev/null || echo 0)
            count=$((count + 1))
            echo "$count" > "$count_file"
            if [ "$count" -le 3 ]; then
              exit 0
            fi
            printf ',bytes_in,bytes_out,\\nSafari.123,4096,2048,\\n'
            sleep 5
            """
        )
        let reader = StreamingNettopReader(
            executableURL: URL(fileURLWithPath: "/usr/bin/script"),
            arguments: ["-q", "/dev/null", scriptURL.path]
        )

        reader.start()
        var result = reader.readApplications()
        let deadline = Date().addingTimeInterval(5)
        while result.stats.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
            result = reader.readApplications()
        }
        reader.stop()

        XCTAssertNil(result.errorMessage, "重启恢复后不应携带错误")
        XCTAssertEqual(result.stats.first?.processName, "Safari")
    }

    func testStreamingNettopReaderReportsExhaustedRestartsAndAllowsRestart() async throws {
        // 脚本短暂存活后退出:3 次重启耗尽后应上报错误、复位 isRunning(修复耗尽后
        // isRunning 卡 true 导致 start() 无法再拉起的 bug),并可再次 start()
        let scriptURL = try makeExecutableScript(
            """
            #!/bin/sh
            sleep 0.2
            exit 0
            """
        )
        let reader = StreamingNettopReader(
            executableURL: URL(fileURLWithPath: "/usr/bin/script"),
            arguments: ["-q", "/dev/null", scriptURL.path]
        )

        reader.start()
        var result = reader.readApplications()
        var deadline = Date().addingTimeInterval(5)
        while result.errorMessage == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
            result = reader.readApplications()
        }

        XCTAssertEqual(result.errorMessage, ApplicationTrafficReaderFailure.restartsExhausted.rawValue)
        XCTAssertEqual(result.stats.count, 0, "放弃重启后应清空死进程的残留数据")
        XCTAssertTrue(result.stats.isEmpty)

        deadline = Date().addingTimeInterval(2)
        while reader.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(reader.isRunning, "耗尽后 isRunning 应复位,允许 start() 重试")

        reader.start()
        deadline = Date().addingTimeInterval(2)
        while !reader.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(reader.isRunning, "耗尽后 start() 应能重新拉起进程")
        reader.stop()
    }

    func testRetryApplicationTrafficReadingClearsErrorAfterRecovery() async {
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [], errorMessage: "nettop failed"),
            ApplicationTrafficReadResult(stats: [
                ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: 1000, sentBytes: 500),
            ], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficIdle(monitor: monitor)
        XCTAssertNotNil(monitor.appTraffic.errorMessage, "首个样本错误应保留 errorMessage")

        monitor.retryApplicationTrafficReading()
        await waitForApplicationTrafficSamples(1, monitor: monitor)

        XCTAssertNil(monitor.appTraffic.errorMessage, "重试成功后错误应清除")
        XCTAssertEqual(monitor.appTraffic.applications.count, 1)
    }

    func testPauseMarksTrafficStaleAndResumeKeepsLastList() async {
        func safariStats(received: UInt64, sent: UInt64) -> ApplicationTrafficStats {
            ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: received, sentBytes: sent)
        }
        // 序列设计为稳定的 stale 终态,规避首值加速引入的时序竞态:
        // s1 基线 → s2 差量(出速率) → 暂停重开 → s3 空(跳过) → s4 新基线(stale 保留旧列表)
        // → s5 起恒为空(定时器持续跳过,stale 稳定) → 手动刷新消费 s6 差量后 stale 清除
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [safariStats(received: 1_000, sent: 500)], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [safariStats(received: 5_000, sent: 2_500)], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [safariStats(received: 9_000, sent: 4_500)], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [safariStats(received: 16_000, sent: 8_000)], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficSamples(2, monitor: monitor, timeout: 3)
        XCTAssertFalse(monitor.appTraffic.applications.isEmpty, "差量样本后应有应用列表")

        monitor.isApplicationTrafficVisible = false
        let listBeforePause = monitor.appTraffic.applications

        // 重开:空样本与新基线都不清旧列表,stale 稳定保持
        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficSamples(3, monitor: monitor, timeout: 4)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(monitor.appTraffic.isStale, "重开后的基线样本期间应标记 stale")
        XCTAssertEqual(monitor.appTraffic.applications, listBeforePause, "基线样本不得清空或改写旧列表")

        // 真实速率样本落地后 stale 清除、数据更新
        monitor.refreshApplicationTraffic()
        await waitForApplicationTrafficSamples(4, monitor: monitor, timeout: 3)

        XCTAssertFalse(monitor.appTraffic.isStale)
        XCTAssertNotEqual(monitor.appTraffic.applications, listBeforePause, "新速率样本应刷新列表")
        monitor.stop()
    }

    func testStaleStateSkipsEmptySamplesToKeepList() async {
        func safariStats(received: UInt64, sent: UInt64) -> ApplicationTrafficStats {
            ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: received, sentBytes: sent)
        }
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [safariStats(received: 1_000, sent: 500)], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [safariStats(received: 5_000, sent: 2_500)], errorMessage: nil),
            // 重开后 nettop 尚未吐出数据(空样本),不应清空旧列表
            ApplicationTrafficReadResult(stats: [], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficSamples(2, monitor: monitor, timeout: 3)
        let listBeforePause = monitor.appTraffic.applications
        XCTAssertFalse(listBeforePause.isEmpty)

        monitor.isApplicationTrafficVisible = false
        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficIdle(monitor: monitor, timeout: 3)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(monitor.appTraffic.isStale)
        XCTAssertEqual(monitor.appTraffic.applications, listBeforePause, "空样本不得清空 stale 期间的旧列表")
        monitor.stop()
    }

    func testResumeTriggersImmediateFollowUpSampleForFirstRate() async {
        func safariStats(received: UInt64, sent: UInt64) -> ApplicationTrafficStats {
            ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: received, sentBytes: sent)
        }
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [safariStats(received: 1_000, sent: 500)], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [safariStats(received: 5_000, sent: 2_500)], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        // 定时器间隔为 1s:500ms 内出现第 2 个样本,说明基线落地后立即触发了
        // 跟随采样(而非等待下一个定时器周期)
        await waitForApplicationTrafficSamples(2, monitor: monitor, timeout: 0.5)

        XCTAssertEqual(monitor.appTraffic.sampleCount, 2)
        let safari = monitor.appTraffic.applications.first { $0.displayName == "Safari" }
        XCTAssertNotNil(safari)
        XCTAssertGreaterThanOrEqual(safari!.downloadBytesPerSecond, 1, "跟随样本应产生非零速率")
        monitor.stop()
    }

    @MainActor
    func testApplicationDisplayRatesSmoothWithEMA() async {
        func safariStats(received: UInt64) -> ApplicationTrafficStats {
            ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: received, sentBytes: 0)
        }
        var clock = Date(timeIntervalSince1970: 100)
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            // 基线
            ApplicationTrafficReadResult(stats: [safariStats(received: 1_000)], errorMessage: nil),
            // 跟随样本(间隔被钳到 0.2s):Δ2000 → raw 10000,作为 EMA 种子
            ApplicationTrafficReadResult(stats: [safariStats(received: 3_000)], errorMessage: nil),
            // 后续每 1s Δ20000 → raw 20000
            ApplicationTrafficReadResult(stats: [safariStats(received: 23_000)], errorMessage: nil),
            ApplicationTrafficReadResult(stats: [safariStats(received: 43_000)], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: { clock }
        )

        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficSamples(2, monitor: monitor, timeout: 2)

        let seeded = monitor.appTraffic.applications.first { $0.displayName == "Safari" }
        XCTAssertNotNil(seeded)
        XCTAssertEqual(seeded!.displayDownloadBytesPerSecond, 10_000, accuracy: 1, "首个差量样本作为平滑种子")

        clock = clock.addingTimeInterval(1)
        monitor.refreshApplicationTraffic()
        await waitForApplicationTrafficSamples(3, monitor: monitor, timeout: 2)
        let first = monitor.appTraffic.applications.first { $0.displayName == "Safari" }!
        XCTAssertEqual(first.downloadBytesPerSecond, 20_000, accuracy: 1, "raw 值不受平滑影响")
        XCTAssertEqual(first.displayDownloadBytesPerSecond, 20_000 * 0.4 + 10_000 * 0.6, accuracy: 1, "EMA: raw*0.4 + prev*0.6")

        clock = clock.addingTimeInterval(1)
        monitor.refreshApplicationTraffic()
        await waitForApplicationTrafficSamples(4, monitor: monitor, timeout: 2)
        let second = monitor.appTraffic.applications.first { $0.displayName == "Safari" }!
        let expectedSecond = 20_000 * 0.4 + (20_000 * 0.4 + 10_000 * 0.6) * 0.6
        XCTAssertEqual(second.displayDownloadBytesPerSecond, expectedSecond, accuracy: 1)
        monitor.stop()
    }

    @MainActor
    func testIdleApplicationKeepsRowInGraceThenHardExits() async {
        func safariStats(received: UInt64) -> ApplicationTrafficStats {
            ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: received, sentBytes: 0)
        }
        var clock = Date(timeIntervalSince1970: 100)
        let trafficReader = SequenceApplicationTrafficReader(samples: [
            ApplicationTrafficReadResult(stats: [safariStats(received: 1_000)], errorMessage: nil),
            // 跟随样本:Δ2000@0.2s → raw 10000,活跃种子
            ApplicationTrafficReadResult(stats: [safariStats(received: 3_000)], errorMessage: nil),
            // 之后 raw 归零(计数器不再增长)
            ApplicationTrafficReadResult(stats: [safariStats(received: 3_000)], errorMessage: nil),
        ])
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: trafficReader,
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16, usedBytes: 8, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 100, user: 20, system: 10, idle: 70),
                thermal: ThermalInfo(state: .nominal)
            ),
            now: { clock }
        )

        monitor.isApplicationTrafficVisible = true
        await waitForApplicationTrafficSamples(2, monitor: monitor, timeout: 2)

        // 空闲 1s:宽限期内,行保留、置灰、显示值衰减
        clock = clock.addingTimeInterval(1)
        monitor.refreshApplicationTraffic()
        await waitForApplicationTrafficSamples(3, monitor: monitor, timeout: 2)
        let coasting = monitor.appTraffic.applications.first { $0.displayName == "Safari" }!
        XCTAssertTrue(coasting.isExpiring, "raw 空闲但宽限期内应标记 isExpiring")
        XCTAssertEqual(coasting.displayDownloadBytesPerSecond, 10_000 * 0.6, accuracy: 1, "宽限期内显示值按 EMA 衰减")

        // 宽限期(3s)过后:显示值硬归零,行移出列表
        clock = clock.addingTimeInterval(4)
        monitor.refreshApplicationTraffic()
        try? await Task.sleep(nanoseconds: 300_000_000)
        let expired = monitor.appTraffic.applications.first { $0.displayName == "Safari" }!
        XCTAssertFalse(expired.isExpiring)
        XCTAssertEqual(expired.displayDownloadBytesPerSecond, 0, "宽限期过后显示值硬归零")
        monitor.stop()
    }

    private func waitForApplicationTrafficSamples(
        _ count: Int,
        monitor: NetworkMonitor,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while monitor.appTraffic.sampleCount < count && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func waitForApplicationTrafficIdle(
        monitor: NetworkMonitor,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while monitor.appTraffic.isRefreshing && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func waitForSnapshotSamples(
        _ count: Int,
        monitor: NetworkMonitor,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while monitor.snapshot.sampleCount < count && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func temporaryDirectoryForSystemTests() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBarSystemResourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeExecutableScript(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBarSystemResourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scriptURL = directory.appendingPathComponent("fake-ps.sh")
        try Data(contents.utf8).write(to: scriptURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }
}

    // MARK: - StreamingNettopReader Fallback Guard Tests (LUC-256)

    func testStreamingReaderRunningWithDataReturnsDataNoFallback() async {
        let trackingFallback = TrackingApplicationTrafficReader()
        let reader = StreamingNettopReaderTestable(fallback: trackingFallback)

        // Simulate: streaming reader is running and has data
        reader.simulateIsRunning = true
        reader.simulateHasProcess = true
        reader.simulateStats = [
            "Safari.123": ApplicationTrafficStats(id: "Safari.123", processName: "Safari", displayName: "Safari", pid: 123, receivedBytes: 1000, sentBytes: 500)
        ]

        let result = reader.readApplications()

        // Should return the streaming data, NOT call fallback
        XCTAssertEqual(result.stats.count, 1)
        XCTAssertEqual(result.stats[0].processName, "Safari")
        XCTAssertEqual(trackingFallback.callCount, 0, "Fallback should NOT be called when streaming reader has data")
    }

    func testStreamingReaderRunningNoDataReturnsEmptyNoFallback() async {
        let trackingFallback = TrackingApplicationTrafficReader()
        let reader = StreamingNettopReaderTestable(fallback: trackingFallback)

        // Simulate: streaming reader is running but no data yet (core regression test)
        reader.simulateIsRunning = true
        reader.simulateHasProcess = true
        reader.simulateStats = [:]

        let result = reader.readApplications()

        // Should return empty, NOT call fallback (this is the bug fix)
        XCTAssertEqual(result.stats.count, 0)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(trackingFallback.callCount, 0, "Fallback should NOT be called when streaming reader is running but has no data")
    }

    func testStreamingReaderNotRunningFallsBack() async {
        let trackingFallback = TrackingApplicationTrafficReader()
        let reader = StreamingNettopReaderTestable(fallback: trackingFallback)

        // Simulate: streaming reader is NOT running
        reader.simulateIsRunning = false
        reader.simulateHasProcess = false
        reader.simulateStats = [:]

        let result = reader.readApplications()

        // Should call fallback
        XCTAssertEqual(result.stats.count, 0)
        XCTAssertEqual(trackingFallback.callCount, 1, "Fallback SHOULD be called when streaming reader is not running")
    }

    func testStreamingReaderRunningButNoProcessFallsBack() async {
        let trackingFallback = TrackingApplicationTrafficReader()
        let reader = StreamingNettopReaderTestable(fallback: trackingFallback)

        // Edge case: isRunning=true but no process (shouldn't happen normally,
        // but we should handle it gracefully by falling back)
        reader.simulateIsRunning = true
        reader.simulateHasProcess = false
        reader.simulateStats = [:]

        let result = reader.readApplications()

        // isRunning is true, so should NOT fall back — returns empty
        XCTAssertEqual(result.stats.count, 0)
        XCTAssertEqual(trackingFallback.callCount, 0, "isRunning guard prevents fallback even with no process")
    }


// MARK: - Mock Readers

private final class MockSystemResourceReader: SystemResourceReading, @unchecked Sendable {
    var memory: MemoryUsage
    var cpu: CPUTickSample
    var thermal: ThermalInfo

    init(memory: MemoryUsage, cpu: CPUTickSample, thermal: ThermalInfo) {
        self.memory = memory
        self.cpu = cpu
        self.thermal = thermal
    }

    func readMemoryUsage() -> MemoryUsage { memory }
    func readCPUTicks() -> CPUTickSample { cpu }
    func readThermalState() -> ThermalInfo { thermal }
}

// MARK: - Test Helpers

private final class SequenceNetworkStatsReader: NetworkStatsReading, @unchecked Sendable {
    private var samples: [[InterfaceStats]]
    private var index = 0

    init(samples: [[InterfaceStats]]) {
        self.samples = samples
    }

    func readInterfaces() -> [InterfaceStats] {
        let sample = samples[min(index, samples.count - 1)]
        index += 1
        return sample
    }
}

private final class SequenceApplicationTrafficReader: ApplicationTrafficReading, @unchecked Sendable {
    private var samples: [ApplicationTrafficReadResult]
    private var index = 0

    init(samples: [ApplicationTrafficReadResult]) {
        self.samples = samples
    }

    func readApplications() -> ApplicationTrafficReadResult {
        let sample = samples[min(index, samples.count - 1)]
        index += 1
        return sample
    }
}

private final class BlockingApplicationTrafficReader: ApplicationTrafficReading, @unchecked Sendable {
    private let startedLock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private let result: ApplicationTrafficReadResult
    private var didStart = false

    init(result: ApplicationTrafficReadResult = ApplicationTrafficReadResult(stats: [], errorMessage: nil)) {
        self.result = result
    }

    func readApplications() -> ApplicationTrafficReadResult {
        startedLock.lock()
        didStart = true
        startedLock.unlock()
        semaphore.wait()
        return result
    }

    var hasStarted: Bool {
        startedLock.lock()
        defer { startedLock.unlock() }
        return didStart
    }

    func unblock() {
        semaphore.signal()
    }
}

private struct EmptyApplicationTrafficReader: ApplicationTrafficReading {
    func readApplications() -> ApplicationTrafficReadResult {
        ApplicationTrafficReadResult(stats: [], errorMessage: nil)
    }
}

// MARK: - StreamingNettopReader Test Helpers (LUC-256)

private final class TrackingApplicationTrafficReader: ApplicationTrafficReading, @unchecked Sendable {
    private(set) var callCount = 0

    func readApplications() -> ApplicationTrafficReadResult {
        callCount += 1
        return ApplicationTrafficReadResult(stats: [], errorMessage: nil)
    }
}

/// A testable subclass of StreamingNettopReader that exposes internal state
/// for controlled testing without launching actual nettop processes.
private final class StreamingNettopReaderTestable: ApplicationTrafficReading, @unchecked Sendable {
    private let _fallback: TrackingApplicationTrafficReader
    var simulateIsRunning = false
    var simulateHasProcess = false
    var simulateStats: [String: ApplicationTrafficStats] = [:]
    private let lock = NSLock()

    init(fallback: TrackingApplicationTrafficReader) {
        self._fallback = fallback
    }

    func readApplications() -> ApplicationTrafficReadResult {
        lock.lock()
        let stats = Array(simulateStats.values)
        let running = simulateIsRunning
        let hasProcess = simulateHasProcess
        lock.unlock()

        if hasProcess && !stats.isEmpty {
            return ApplicationTrafficReadResult(stats: stats, errorMessage: nil)
        }

        if running {
            return ApplicationTrafficReadResult(stats: [], errorMessage: nil)
        }

        return _fallback.readApplications()
    }
}
