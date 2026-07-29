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

    private static let displayNameCache = LockedObjectCache<NSNumber, NSString>()

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
