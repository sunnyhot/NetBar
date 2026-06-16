import Foundation
import AppKit

// MARK: - System Metrics Protocol

/// Protocol for reading system-level metrics (CPU, memory, thermal state).
/// Designed for dependency injection so tests can swap in mock implementations.
protocol SystemMetricsReading: AnyObject {
    func cpuUsage() -> Double          // 0.0...1.0
    func memoryUsage() -> Double       // 0.0...1.0
    func thermalState() -> Int         // 0=normal, 1=fair, 2=serious, 3=critical
}

// MARK: - Live System Metrics Reader

final class SystemMetricsReader: SystemMetricsReading {
    private var previousCPUTime: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?

    func cpuUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = withUnsafeMutablePointer(to: &numCPUs) { numCPUsPtr in
            withUnsafeMutablePointer(to: &numCPUInfo) { numCPUInfoPtr in
                host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, numCPUsPtr, &cpuInfo, numCPUInfoPtr)
            }
        }

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return 0 }

        defer {
            let size = mach_msg_type_number_t(numCPUInfo)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(UInt32(size) * UInt32(MemoryLayout<integer_t>.size)))
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        let numCPUsInt = Int(numCPUs)
        for i in 0..<numCPUsInt {
            let base = i * Int(CPU_STATE_MAX)
            totalUser += UInt64(cpuInfo[base + Int(CPU_STATE_USER)])
            totalSystem += UInt64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(cpuInfo[base + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(cpuInfo[base + Int(CPU_STATE_NICE)])
        }

        let current = (user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice)
        defer { previousCPUTime = current }

        guard let previous = previousCPUTime else { return 0 }

        let dUser = Double(current.user &- previous.user)
        let dSystem = Double(current.system &- previous.system)
        let dIdle = Double(current.idle &- previous.idle)
        let dNice = Double(current.nice &- previous.nice)
        let total = dUser + dSystem + dIdle + dNice

        guard total > 0 else { return 0 }
        return min((dUser + dSystem + dNice) / total, 1.0)
    }

    func memoryUsage() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: Int(size)) { int32Ptr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, int32Ptr, &size)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let activePages = UInt64(vmStats.active_count)
        let wiredPages = UInt64(vmStats.wire_count)
        let compressedPages = UInt64(vmStats.compressor_page_count)
        let freePages = UInt64(vmStats.free_count)
        let inactivePages = UInt64(vmStats.inactive_count)

        let usedPages = activePages + wiredPages + compressedPages
        let totalPages = usedPages + freePages + inactivePages

        guard totalPages > 0 else { return 0 }
        return min(Double(usedPages) / Double(totalPages), 1.0)
    }

    func thermalState() -> Int {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }
}

// MARK: - Animation Speed Mapper

/// Maps a system metric value to an `ActivityLevel` for animation speed control.
/// Each source has its own thresholds tuned for a good user experience.
enum AnimationSpeedMapper {
    /// Maps a 0...1 metric value to an ActivityLevel.
    static func activityLevel(from metricValue: Double) -> ActivityLevel {
        if metricValue < 0.15 {
            return .idle
        } else if metricValue < 0.45 {
            return .low
        } else if metricValue < 0.75 {
            return .moderate
        } else {
            return .high
        }
    }

    /// Maps thermal state (0-3) to an ActivityLevel.
    static func activityLevel(fromThermalState state: Int) -> ActivityLevel {
        switch state {
        case 0: return .idle
        case 1: return .low
        case 2: return .moderate
        default: return .high
        }
    }

    /// Computes an auto-composite ActivityLevel by averaging normalized values from all sources.
    static func autoCompositeActivityLevel(
        cpuUsage: Double,
        memoryUsage: Double,
        thermalState: Int,
        networkActivityLevel: ActivityLevel
    ) -> ActivityLevel {
        let thermalNormalized = Double(thermalState) / 3.0
        let networkNormalized: Double = {
            switch networkActivityLevel {
            case .idle: return 0.0
            case .low: return 0.25
            case .moderate: return 0.6
            case .high: return 1.0
            }
        }()

        let composite = (cpuUsage + memoryUsage + thermalNormalized + networkNormalized) / 4.0
        return activityLevel(from: composite)
    }
}

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

// MARK: - System Metrics Sampler

/// Periodically samples system metrics and publishes the latest values.
@MainActor
final class SystemMetricsSampler: ObservableObject {
    @Published private(set) var lastCPUUsage: Double = 0
    @Published private(set) var lastMemoryUsage: Double = 0
    @Published private(set) var lastThermalState: Int = 0

    private let reader: SystemMetricsReading
    private var timer: Timer?
    private let sampleInterval: TimeInterval

    init(
        reader: SystemMetricsReading = SystemMetricsReader(),
        sampleInterval: TimeInterval = 2.0
    ) {
        self.reader = reader
        self.sampleInterval = sampleInterval
    }

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let reader = self.reader
        Task { [weak self] in
            let cpu = await Task.detached(priority: .utility) { reader.cpuUsage() }.value
            let memory = await Task.detached(priority: .utility) { reader.memoryUsage() }.value
            let thermal = await Task.detached(priority: .utility) { reader.thermalState() }.value
            self?.lastCPUUsage = cpu
            self?.lastMemoryUsage = memory
            self?.lastThermalState = thermal
        }
    }
}
