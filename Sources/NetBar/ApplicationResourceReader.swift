import AppKit
import Foundation

// MARK: - Data Models

/// Per-process resource usage snapshot (memory + CPU).
struct ProcessResourceUsage: Equatable {
    let pid: Int32
    let processName: String
    let displayName: String
    /// Resident memory in bytes.
    let residentMemory: UInt64?
    /// CPU usage as a percentage (0–100 per core, can exceed 100 on multi-core).
    let cpuPercentage: Double?
}

/// Protocol for reading per-process resource usage. Injectable for testing.
protocol ApplicationResourceReading: Sendable {
    func readProcessResources() -> [ProcessResourceUsage]
}

// MARK: - System Resource Summary

struct SystemResourceSummary: Equatable {
    /// Total physical memory installed (bytes).
    let totalMemory: UInt64
    /// Memory currently in use (bytes).
    let usedMemory: UInt64
    /// Overall CPU usage percentage (0–100).
    let cpuUsage: Double?
    /// Number of running processes.
    let processCount: Int

    var memoryUsagePercentage: Double? {
        guard totalMemory > 0 else { return nil }
        return Double(usedMemory) / Double(totalMemory) * 100.0
    }

    static let empty = SystemResourceSummary(
        totalMemory: 0,
        usedMemory: 0,
        cpuUsage: nil,
        processCount: 0
    )
}

// MARK: - Concrete Reader (uses ps aux)

final class PSApplicationResourceReader: ApplicationResourceReading, @unchecked Sendable {
    private let executableURL: URL
    private let arguments: [String]
    private let timeout: TimeInterval

    init(
        executableURL: URL = URL(fileURLWithPath: "/bin/ps"),
        arguments: [String] = ["-e", "-o", "pid=,rss=,%cpu=,comm="],
        timeout: TimeInterval = 3
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.timeout = timeout
    }

    func readProcessResources() -> [ProcessResourceUsage] {
        let process = Process()
        let pipe = Pipe()
        let output = LockedProcessOutput()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            output.append(data)
        }
        defer {
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        do {
            try process.run()
        } catch {
            return []
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return []
        }

        pipe.fileHandleForReading.readabilityHandler = nil
        let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remainingData.isEmpty {
            output.append(remainingData)
        }

        guard process.terminationStatus == 0 else { return [] }

        let outputText = String(data: output.data, encoding: .utf8) ?? ""
        return parse(outputText)
    }

    private func parse(_ output: String) -> [ProcessResourceUsage] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return [] }

        // No header line with -o col= syntax (= suppresses header)
        var results: [ProcessResourceUsage] = []
        results.reserveCapacity(lines.count)

        for line in lines {
            // ps -e -o pid=,rss=,%cpu=,comm= format: PID RSS %CPU COMM
            let columns = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard columns.count >= 4 else { continue }

            guard let pid = Int32(columns[0]) else { continue }
            // RSS is in KB, convert to bytes
            let rssKB = UInt64(columns[1]) ?? 0
            let residentMemory: UInt64? = rssKB > 0 ? rssKB * 1024 : nil
            let cpuPercentage = Double(columns[2])
            let comm = columns[3...]

            let processName = comm.joined(separator: " ")
            let displayName = Self.displayName(for: pid, fallback: processName)

            results.append(ProcessResourceUsage(
                pid: pid,
                processName: processName,
                displayName: displayName,
                residentMemory: residentMemory,
                cpuPercentage: cpuPercentage
            ))
        }

        return results
    }

    private static let displayNameCache = NSCache<NSNumber, NSString>()

    private static func displayName(for pid: Int32, fallback: String) -> String {
        let key = NSNumber(value: pid)
        if let cached = displayNameCache.object(forKey: key) {
            return cached as String
        }

        if let runningApplication = NSRunningApplication(processIdentifier: pid),
           let localizedName = runningApplication.localizedName,
           !localizedName.isEmpty {
            displayNameCache.setObject(localizedName as NSString, forKey: key)
            return localizedName
        }

        return fallback
    }
}

private final class LockedProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}

// MARK: - System Resource Reader

final class SystemResourceReader: @unchecked Sendable {
    /// Stores previous CPU tick snapshot for delta-based instantaneous calculation.
    private var previousCPUTicks: [UInt64]? // [user, system, nice, idle] aggregated across all cores

    /// Read overall system resource summary.
    func readSystemSummary(processCount: Int) -> SystemResourceSummary {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = Self.readUsedMemory()
        let cpuUsage = readCPUUsage()

        return SystemResourceSummary(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            cpuUsage: cpuUsage,
            processCount: processCount
        )
    }

    /// Read used memory via vm_stat.
    private static func readUsedMemory() -> UInt64 {
        // Use Mach host_info to get free memory
        let host = mach_host_self()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else {
            return ProcessInfo.processInfo.physicalMemory
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let freePages = UInt64(vmStats.free_count)
        let inactivePages = UInt64(vmStats.inactive_count)
        // Used = total - free - inactive (inactive is cached but reclaimable)
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = totalMemory > (freePages + inactivePages) * pageSize
            ? totalMemory - (freePages + inactivePages) * pageSize
            : totalMemory
        return usedMemory
    }

    /// Read instantaneous CPU usage via host_processor_info with delta calculation.
    private func readCPUUsage() -> Double? {
        let host = mach_host_self()
        var numCPUs = natural_t(0)
        var cpuInfo: processor_info_array_t?
        var numCPUInfo = mach_msg_type_number_t(0)

        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)) }

        // Aggregate ticks across all CPUs
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalNice: UInt64 = 0
        var totalIdle: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let base = i * Int(CPU_STATE_MAX)
            totalUser += UInt64(cpuInfo[base + Int(CPU_STATE_USER)])
            totalSystem += UInt64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            totalNice += UInt64(cpuInfo[base + Int(CPU_STATE_NICE)])
            totalIdle += UInt64(cpuInfo[base + Int(CPU_STATE_IDLE)])
        }

        let currentTicks = [totalUser, totalSystem, totalNice, totalIdle]

        // First sample: store and return nil (no delta yet)
        guard let prev = previousCPUTicks else {
            previousCPUTicks = currentTicks
            return nil
        }

        previousCPUTicks = currentTicks

        // Delta calculation for instantaneous usage
        let dUser = totalUser > prev[0] ? totalUser - prev[0] : 0
        let dSystem = totalSystem > prev[1] ? totalSystem - prev[1] : 0
        let dNice = totalNice > prev[2] ? totalNice - prev[2] : 0
        let dIdle = totalIdle > prev[3] ? totalIdle - prev[3] : 0

        let dUsed = dUser + dSystem + dNice
        let dTotal = dUsed + dIdle

        guard dTotal > 0 else { return nil }
        return Double(dUsed) / Double(dTotal) * 100.0
    }
}
