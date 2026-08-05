import Foundation

// MARK: - System Resource Summary

/// System-wide resource summary (memory + CPU), sourced from Mach/system APIs
/// via `SystemResourceReading`. This is independent of any per-process reading.
struct SystemResourceSummary: Equatable {
    /// Total physical memory installed (bytes).
    let totalMemory: UInt64
    /// Memory currently in use (bytes).
    let usedMemory: UInt64
    /// Overall CPU usage percentage (0–100).
    let cpuUsage: Double?

    var memoryUsagePercentage: Double? {
        guard totalMemory > 0 else { return nil }
        return Double(usedMemory) / Double(totalMemory) * 100.0
    }

    static let empty = SystemResourceSummary(
        totalMemory: 0,
        usedMemory: 0,
        cpuUsage: nil
    )
}
