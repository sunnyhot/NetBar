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

    // MARK: - Mock SystemResourceReader

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
            now: Date.init
        )

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }
}

// MARK: - Mock Reader

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

// MARK: - Test Helpers (duplicated from main test file for isolation)

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

private struct EmptyApplicationTrafficReader: ApplicationTrafficReading {
    func readApplications() -> ApplicationTrafficReadResult {
        ApplicationTrafficReadResult(stats: [], errorMessage: nil)
    }
}
