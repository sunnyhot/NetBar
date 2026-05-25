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
    private let executableURL = URL(fileURLWithPath: "/bin/ps")

    func readProcessResources() -> [ProcessResourceUsage] {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = executableURL
        // -x: all users, -o: custom format (pid= PID, rss= RSS in KB, %cpu= CPU%, command=)
        process.arguments = ["aux", "-o", "pid=,rss=,%cpu=,comm="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return parse(output)
    }

    private func parse(_ output: String) -> [ProcessResourceUsage] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 1 else { return [] }

        // Skip header line
        var results: [ProcessResourceUsage] = []
        results.reserveCapacity(lines.count - 1)

        for line in lines.dropFirst() {
            // ps aux format: USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND
            // But we requested pid=,rss=,%cpu=,comm= so format is: PID RSS %CPU COMM
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

// MARK: - System Resource Reader

final class SystemResourceReader: @unchecked Sendable {
    /// Read overall system resource summary.
    func readSystemSummary(processCount: Int) -> SystemResourceSummary {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = Self.readUsedMemory()
        let cpuUsage = Self.readCPUUsage()

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

    /// Read CPU usage via host_processor_info.
    private static func readCPUUsage() -> Double? {
        let host = mach_host_self()
        var numCPUs = natural_t(0)
        var cpuInfo: processor_info_array_t?
        var numCPUInfo = mach_msg_type_number_t(0)

        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)) }

        var totalUsage: Double = 0
        var totalTick: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt64(cpuInfo[base + Int(CPU_STATE_USER)])
            let system = UInt64(cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let nice = UInt64(cpuInfo[base + Int(CPU_STATE_NICE)])
            let idle = UInt64(cpuInfo[base + Int(CPU_STATE_IDLE)])
            let used = user + system + nice
            let total = used + idle
            if total > 0 {
                totalUsage += Double(used) / Double(total) * 100.0
            }
            totalTick += total
        }

        guard numCPUs > 0 else { return nil }
        // Average across all CPUs (result is 0-100 overall)
        return totalUsage / Double(numCPUs)
    }
}
