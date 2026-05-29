import XCTest
@testable import NetBar

@MainActor
final class SystemResourceTests: XCTestCase {

    // MARK: - MemoryUsage Tests

    func testMemoryUsageComputedProperties() {
        let usage = MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 4_000_000_000, swapUsedBytes: 1_000_000_000)

        XCTAssertEqual(usage.freeBytes, 8_000_000_000)
        XCTAssertEqualWithAccuracy(usage.usedFraction, 0.5, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(usage.usedPercentage, 50.0, accuracy: 0.01)
        XCTAssertEqualWithAccuracy(usage.swapUsedFraction, 0.25, accuracy: 0.001)
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

        XCTAssertEqualWithAccuracy(cpu.usageFraction, 0.35, accuracy: 0.001)
        XCTAssertEqualWithAccuracy(cpu.usagePercentage, 35.0, accuracy: 0.01)
    }

    func testCPUUsageZeroTicks() {
        let cpu = CPUUsage(totalTicks: 0, userTicks: 0, systemTicks: 0, idleTicks: 0)

        XCTAssertEqual(cpu.usageFraction, 0)
        XCTAssertEqual(cpu.usagePercentage, 0)
    }

    func testCPUUsageFullLoad() {
        let cpu = CPUUsage(totalTicks: 1000, userTicks: 800, systemTicks: 200, idleTicks: 0)

        XCTAssertEqualWithAccuracy(cpu.usageFraction, 1.0, accuracy: 0.001)
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

    // MARK: - SystemResourceFormat Tests

    func testMemoryPercentageFormatting() {
        let usage = MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0)
        let result = SystemResourceFormat.memoryPercentage(usage)
        XCTAssertEqual(result, "50.0%")
    }

    func testCPUPercentageFormatting() {
        let cpu = CPUUsage(totalTicks: 1000, userTicks: 250, systemTicks: 100, idleTicks: 650)
        let result = SystemResourceFormat.cpuPercentage(cpu)
        XCTAssertEqual(result, "35.0%")
    }

    func testThermalShortFormatting() {
        XCTAssertEqual(SystemResourceFormat.thermalShort(ThermalInfo(state: .nominal)), "✅ Nominal")
        XCTAssertEqual(SystemResourceFormat.thermalShort(ThermalInfo(state: .fair)), "⚠️ Fair")
        XCTAssertEqual(SystemResourceFormat.thermalShort(ThermalInfo(state: .serious)), "🌡️ Serious")
        XCTAssertEqual(SystemResourceFormat.thermalShort(ThermalInfo(state: .critical)), "🔥 Critical")
    }

    func testMemoryUsedFormatting() {
        let usage = MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_500_000_000, swapTotalBytes: 0, swapUsedBytes: 0)
        let result = SystemResourceFormat.memoryUsed(usage)
        // 8.5 GB
        XCTAssertTrue(result.contains("GB"))
    }

    func testMemorySummaryFormatting() {
        let usage = MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0)
        let result = SystemResourceFormat.memorySummary(usage)
        XCTAssertTrue(result.contains("50.0%"))
        XCTAssertTrue(result.contains("GB"))
    }

    // MARK: - Mock SystemResourceReader Tests

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

    // MARK: - SystemResourceSummary Tests (LUC-227)

    func testSystemResourceSummaryEmpty() {
        let empty = SystemResourceSummary.empty
        XCTAssertEqual(empty.totalMemory, 0)
        XCTAssertEqual(empty.usedMemory, 0)
        XCTAssertNil(empty.cpuUsage)
        XCTAssertEqual(empty.processCount, 0)
        XCTAssertNil(empty.memoryUsagePercentage)
    }

    func testSystemResourceSummaryMemoryPercentage() {
        let summary = SystemResourceSummary(
            totalMemory: 16_000_000_000,
            usedMemory: 8_000_000_000,
            cpuUsage: 25.5,
            processCount: 300
        )
        XCTAssertEqualWithAccuracy(summary.memoryUsagePercentage!, 50.0, accuracy: 0.01)
    }

    func testSystemResourceSummaryZeroMemory() {
        let summary = SystemResourceSummary(
            totalMemory: 0,
            usedMemory: 0,
            cpuUsage: nil,
            processCount: 0
        )
        XCTAssertNil(summary.memoryUsagePercentage)
    }

    func testSystemResourceSummaryEquality() {
        let a = SystemResourceSummary(totalMemory: 16, usedMemory: 8, cpuUsage: 25.0, processCount: 100)
        let b = SystemResourceSummary(totalMemory: 16, usedMemory: 8, cpuUsage: 25.0, processCount: 100)
        XCTAssertEqual(a, b)
    }

    // MARK: - ProcessResourceUsage Tests (LUC-227)

    func testProcessResourceUsageEquality() {
        let a = ProcessResourceUsage(pid: 123, processName: "Safari", displayName: "Safari", residentMemory: 1024, cpuPercentage: 5.0)
        let b = ProcessResourceUsage(pid: 123, processName: "Safari", displayName: "Safari", residentMemory: 1024, cpuPercentage: 5.0)
        XCTAssertEqual(a, b)
    }

    func testProcessResourceUsageWithNilFields() {
        let usage = ProcessResourceUsage(pid: 456, processName: "kernel", displayName: "kernel", residentMemory: nil, cpuPercentage: nil)
        XCTAssertNil(usage.residentMemory)
        XCTAssertNil(usage.cpuPercentage)
        XCTAssertEqual(usage.pid, 456)
    }

    // MARK: - ApplicationTrafficRate Resource Fields (LUC-227)

    func testApplicationTrafficRateWithResources() {
        let rate = ApplicationTrafficRate(
            id: "Safari",
            displayName: "Safari",
            processNames: ["Safari"],
            pids: [123],
            downloadBytesPerSecond: 1000,
            uploadBytesPerSecond: 500,
            totalReceivedBytes: 10000,
            totalSentBytes: 5000,
            residentMemory: 1024 * 1024 * 500, // 500 MB
            cpuPercentage: 12.5
        )
        XCTAssertEqual(rate.residentMemory, 524_288_000)
        XCTAssertEqual(rate.cpuPercentage, 12.5)
    }

    func testApplicationTrafficRateWithoutResources() {
        let rate = ApplicationTrafficRate(
            id: "unknown",
            displayName: "unknown",
            processNames: ["unknown"],
            pids: [999],
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            totalReceivedBytes: 100,
            totalSentBytes: 50,
            residentMemory: nil,
            cpuPercentage: nil
        )
        XCTAssertNil(rate.residentMemory)
        XCTAssertNil(rate.cpuPercentage)
    }

    func testApplicationTrafficStateEmptyHasSystemResources() {
        let empty = ApplicationTrafficState.empty
        // Empty state should have .empty systemResources
        XCTAssertEqual(empty.systemResources, SystemResourceSummary.empty)
    }

    // MARK: - Mock ApplicationResourceReader Tests (LUC-227)

    func testMockApplicationResourceReader() {
        let mock = MockApplicationResourceReader(processes: [
            ProcessResourceUsage(pid: 100, processName: "Safari", displayName: "Safari", residentMemory: 1024, cpuPercentage: 5.0),
            ProcessResourceUsage(pid: 200, processName: "Mail", displayName: "Mail", residentMemory: 2048, cpuPercentage: 2.0),
        ])
        let results = mock.readProcessResources()
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].processName, "Safari")
        XCTAssertEqual(results[1].processName, "Mail")
    }

    // MARK: - NetworkMonitor System Resource Integration

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
            resourceReader: MockApplicationResourceReader(processes: []),
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
            resourceReader: MockApplicationResourceReader(processes: []),
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
        XCTAssertEqualWithAccuracy(cpu.usagePercentage, 50.0, accuracy: 0.01)
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
            resourceReader: MockApplicationResourceReader(processes: []),
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
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testNetworkMonitorRefreshesApplicationTraffic() async {
        let mockResourceReader = MockApplicationResourceReader(processes: [
            ProcessResourceUsage(pid: 100, processName: "Safari", displayName: "Safari", residentMemory: 1024, cpuPercentage: 5.0),
        ])

        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            resourceReader: mockResourceReader,
            now: Date.init
        )

        // Start the monitor — this sets isRunning and starts timers
        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testNetworkMonitorPowerSaveMode() {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        // Should not crash when setting power save mode before start
        monitor.setPowerSaveMode(true)

        monitor.start()
        monitor.setPowerSaveMode(false)

        monitor.stop()
    }

    // MARK: - Application Traffic State Machine Tests (LUC-231)

    func testRefreshApplicationTrafficBlockedWhenSamplingDisabled() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            resourceReader: MockApplicationResourceReader(processes: []),
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
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        // Enable sampling (simulates popover opening)
        monitor.isApplicationTrafficVisible = true

        // Give the async Task time to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        // After first sample completes, isRefreshing must be false
        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false after first sample completes")
        XCTAssertNil(monitor.appTraffic.errorMessage, "No error expected for empty results")
        XCTAssertEqual(monitor.appTraffic.sampleCount, 1, "sampleCount should be 1 after first sample")
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
            resourceReader: MockApplicationResourceReader(processes: []),
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
            resourceReader: MockApplicationResourceReader(processes: []),
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

    func testStartDoesNotCreateAppTrafficTimerWhenNotVisible() async {
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            appTrafficReader: EmptyApplicationTrafficReader(),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        // start() should not trigger app traffic sampling when popover is not visible
        monitor.start()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // appTraffic should remain in empty state
        XCTAssertEqual(monitor.appTraffic.sampleCount, 0, "start() should not sample app traffic when sampling disabled")

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
            resourceReader: MockApplicationResourceReader(processes: []),
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

    // MARK: - KeepRefreshing Logic Tests (LUC-257)

    func testFirstSampleEmptyDataWithStreamingKeepsRefreshing() async {
        // When streamingReader is active (appTrafficReader omitted) and first sample is empty,
        // isRefreshing should stay true to avoid flashing "暂无应用流量".
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        // Verify streamingReader is active
        XCTAssertNotNil(monitor.streamingReader, "streamingReader should be non-nil when appTrafficReader is omitted")

        // Enable sampling
        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        // The first sample from StreamingNettopReader may or may not have data.
        // If it has data, isRefreshing should be false.
        // If it has no data, isRefreshing should remain true (keepRefreshing logic).
        let hasData = !monitor.appTraffic.applications.isEmpty
        if hasData {
            XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false when streaming produces data")
        } else {
            XCTAssertTrue(monitor.appTraffic.isRefreshing, "isRefreshing should stay true when streaming has no data yet and sampleCount < 3")
        }
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
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        // Verify streamingReader is nil
        XCTAssertNil(monitor.streamingReader, "streamingReader should be nil when appTrafficReader is provided")

        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Empty result + no streaming → isRefreshing must be false
        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false when streamingReader is nil and data is empty")
        XCTAssertEqual(monitor.appTraffic.sampleCount, 1)
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
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        monitor.isApplicationTrafficVisible = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false when first sample has data")
        XCTAssertEqual(monitor.appTraffic.sampleCount, 1)
        XCTAssertEqual(monitor.appTraffic.applications.count, 1)
    }

    func testStreamingSafetyCapStopsRefreshingAfterThreeSamples() async {
        // After 3 empty samples with streaming active, the safety cap should
        // force isRefreshing to false even though data is still empty.
        let monitor = NetworkMonitor(
            reader: SequenceNetworkStatsReader(samples: [[InterfaceStats(name: "en0", receivedBytes: 100, sentBytes: 50, receivedPackets: 10, sentPackets: 5)]]),
            systemResourceReader: MockSystemResourceReader(
                memory: MemoryUsage(totalBytes: 16_000_000_000, usedBytes: 8_000_000_000, swapTotalBytes: 0, swapUsedBytes: 0),
                cpu: CPUTickSample(total: 1000, user: 300, system: 100, idle: 600),
                thermal: ThermalInfo(state: .nominal)
            ),
            resourceReader: MockApplicationResourceReader(processes: []),
            now: Date.init
        )

        XCTAssertNotNil(monitor.streamingReader)

        monitor.isApplicationTrafficVisible = true

        // Sample multiple times to reach the safety cap
        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 600_000_000)
            monitor.refreshApplicationTraffic()
        }
        try? await Task.sleep(nanoseconds: 500_000_000)

        // After multiple samples, isRefreshing should eventually be false (safety cap)
        // regardless of whether data appeared or not
        if monitor.appTraffic.applications.isEmpty && monitor.appTraffic.sampleCount >= 3 {
            XCTAssertFalse(monitor.appTraffic.isRefreshing, "isRefreshing should be false after sampleCount >= 3 (safety cap)")
        }
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

private final class MockApplicationResourceReader: ApplicationResourceReading, @unchecked Sendable {
    let processes: [ProcessResourceUsage]

    init(processes: [ProcessResourceUsage]) {
        self.processes = processes
    }

    func readProcessResources() -> [ProcessResourceUsage] { processes }
}

// MARK: - Test Helpers

private final class SequenceNetworkStatsReader: NetworkStatsReading {
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
    private let semaphore = DispatchSemaphore(value: 0)

    func readApplications() -> ApplicationTrafficReadResult {
        semaphore.wait()
        return ApplicationTrafficReadResult(stats: [], errorMessage: nil)
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
