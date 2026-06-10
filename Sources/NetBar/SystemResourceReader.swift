import Foundation

// MARK: - Data Models

/// Snapshot of system resource usage at a point in time.
struct SystemResourceSnapshot: Equatable {
    var memory: MemoryUsage
    var cpu: CPUUsage
    var thermal: ThermalInfo

    static let empty = SystemResourceSnapshot(
        memory: MemoryUsage(totalBytes: 0, usedBytes: 0, swapTotalBytes: 0, swapUsedBytes: 0),
        cpu: CPUUsage(totalTicks: 0, userTicks: 0, systemTicks: 0, idleTicks: 0),
        thermal: ThermalInfo(state: .nominal)
    )
}

/// Memory usage information.
struct MemoryUsage: Equatable {
    /// Total physical memory in bytes.
    var totalBytes: UInt64
    /// Used physical memory in bytes.
    var usedBytes: UInt64
    /// Total swap space in bytes.
    var swapTotalBytes: UInt64
    /// Used swap space in bytes.
    var swapUsedBytes: UInt64

    /// Free physical memory in bytes.
    var freeBytes: UInt64 {
        totalBytes > usedBytes ? totalBytes - usedBytes : 0
    }

    /// Memory usage as a fraction in 0...1.
    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    /// Memory usage as a percentage (0–100).
    var usedPercentage: Double {
        usedFraction * 100
    }

    /// Swap usage as a fraction in 0...1.
    var swapUsedFraction: Double {
        guard swapTotalBytes > 0 else { return 0 }
        return Double(swapUsedBytes) / Double(swapTotalBytes)
    }
}

/// CPU usage information based on two adjacent samples.
struct CPUUsage: Equatable {
    /// Total ticks from host processor info.
    var totalTicks: UInt64
    /// User-mode ticks.
    var userTicks: UInt64
    /// System-mode ticks.
    var systemTicks: UInt64
    /// Idle ticks.
    var idleTicks: UInt64

    /// CPU usage as a fraction in 0...1 (computed from delta with previous sample).
    /// Returns 0 for a single sample without a previous reference.
    var usageFraction: Double {
        guard totalTicks > 0 else { return 0 }
        let usedTicks = userTicks + systemTicks
        return Double(usedTicks) / Double(totalTicks)
    }

    /// CPU usage as a percentage (0–100).
    var usagePercentage: Double {
        usageFraction * 100
    }
}

/// Thermal pressure information.
struct ThermalInfo: Equatable {
    /// Current thermal state from ProcessInfo.
    var state: ThermalPressureState

    /// Human-readable description for the thermal state.
    var localizedDescription: String {
        switch state {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
}

/// Wrapper for ProcessInfo.ThermalState to make it Equatable and testable.
enum ThermalPressureState: Equatable {
    case nominal
    case fair
    case serious
    case critical

    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}

// MARK: - Reading Protocol

/// Protocol for reading system resource information.
/// Default implementation uses public macOS APIs.
/// Inject a mock for testing.
protocol SystemResourceReading: Sendable {
    func readMemoryUsage() -> MemoryUsage
    func readCPUTicks() -> CPUTickSample
    func readThermalState() -> ThermalInfo
    func readSystemSummary(processCount: Int) -> SystemResourceSummary
}

extension SystemResourceReading {
    func readSystemSummary(processCount: Int) -> SystemResourceSummary {
        let mem = readMemoryUsage()
        return SystemResourceSummary(
            totalMemory: mem.totalBytes,
            usedMemory: mem.usedBytes,
            cpuUsage: nil,
            processCount: processCount
        )
    }
}

/// A raw CPU tick sample used for computing deltas between readings.
struct CPUTickSample: Equatable {
    var total: UInt64
    var user: UInt64
    var system: UInt64
    var idle: UInt64
}

// MARK: - Default Implementation using public APIs

final class LiveSystemResourceReader: SystemResourceReading, @unchecked Sendable {
    func readMemoryUsage() -> MemoryUsage {
        // Use Mach host statistics for memory info
        let pageSize = UInt64(vm_kernel_page_size)
        let host = mach_host_self()

        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryUsage(
                totalBytes: UInt64(ProcessInfo.processInfo.physicalMemory),
                usedBytes: 0,
                swapTotalBytes: 0,
                swapUsedBytes: 0
            )
        }

        let totalMemory = UInt64(ProcessInfo.processInfo.physicalMemory)

        // used = total - (free_count + inactive_count + speculative_count) * page_size
        let freePages = UInt64(vmStats.free_count)
        let inactivePages = UInt64(vmStats.inactive_count)
        let speculativePages = UInt64(vmStats.speculative_count)
        let usedBytes = totalMemory > (freePages + inactivePages + speculativePages) * pageSize
            ? totalMemory - (freePages + inactivePages + speculativePages) * pageSize
            : 0

        let swapTotalBytes = UInt64(vmStats.swapouts) > 0
            ? UInt64(vmStats.external_page_count) * pageSize
            : 0
        let swapUsedBytes = UInt64(vmStats.compressor_page_count) * pageSize

        return MemoryUsage(
            totalBytes: totalMemory,
            usedBytes: usedBytes,
            swapTotalBytes: swapTotalBytes,
            swapUsedBytes: swapUsedBytes
        )
    }

    func readCPUTicks() -> CPUTickSample {
        let host = mach_host_self()
        var numCPUs = natural_t(0)
        var cpuInfo: processor_info_array_t?
        var numCPUInfo = mach_msg_type_number_t(0)

        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)

        guard result == KERN_SUCCESS, let cpuInfo else {
            return CPUTickSample(total: 0, user: 0, system: 0, idle: 0)
        }

        defer {
            let size = Int(numCPUInfo) * MemoryLayout<integer_t>.size
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(size))
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0

        let cpuInfoPointer = UnsafeMutablePointer<integer_t>(cpuInfo)
        for cpu in 0..<Int(numCPUs) {
            let offset = cpu * Int(CPU_STATE_MAX)
            totalUser += UInt64(max(cpuInfoPointer[offset + Int(CPU_STATE_USER)], 0))
            totalSystem += UInt64(max(cpuInfoPointer[offset + Int(CPU_STATE_SYSTEM)], 0))
            totalIdle += UInt64(max(cpuInfoPointer[offset + Int(CPU_STATE_IDLE)], 0))
            // Note: CPU_STATE_NICE is included in user for usage purposes
            totalUser += UInt64(max(cpuInfoPointer[offset + Int(CPU_STATE_NICE)], 0))
        }

        let totalTicks = totalUser + totalSystem + totalIdle

        return CPUTickSample(
            total: totalTicks,
            user: totalUser,
            system: totalSystem,
            idle: totalIdle
        )
    }

    func readThermalState() -> ThermalInfo {
        ThermalInfo(state: ThermalPressureState(ProcessInfo.processInfo.thermalState))
    }
}
