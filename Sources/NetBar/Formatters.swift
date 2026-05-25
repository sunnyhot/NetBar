import Foundation

enum ByteFormat {
    static func speed(_ bytesPerSecond: Double) -> String {
        "\(bytes(bytesPerSecond))/s"
    }

    static func bytes(_ value: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var amount = max(value, 0)
        var unitIndex = 0

        while amount >= 1024, unitIndex < units.count - 1 {
            amount /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(amount)) \(units[unitIndex])"
        }
        if amount >= 100 {
            return "\(Int(amount.rounded())) \(units[unitIndex])"
        }
        if amount >= 10 {
            return String(format: "%.1f %@", amount, units[unitIndex])
        }
        return String(format: "%.2f %@", amount, units[unitIndex])
    }

    static func bytes(_ value: UInt64) -> String {
        bytes(Double(value))
    }

    static func packets(_ value: UInt64) -> String {
        value.formatted(.number)
    }
}

// MARK: - System Resource Formatting

enum SystemResourceFormat {
    /// Formats memory usage as a compact string like "8.2 / 16.0 GB (51.3%)"
    static func memorySummary(_ usage: MemoryUsage) -> String {
        "\(ByteFormat.bytes(Double(usage.usedBytes))) / \(ByteFormat.bytes(Double(usage.totalBytes))) (\(String(format: "%.1f%%", usage.usedPercentage)))"
    }

    /// Formats memory used bytes as a human-readable string.
    static func memoryUsed(_ usage: MemoryUsage) -> String {
        ByteFormat.bytes(Double(usage.usedBytes))
    }

    /// Formats memory as a percentage string like "51.3%"
    static func memoryPercentage(_ usage: MemoryUsage) -> String {
        String(format: "%.1f%%", usage.usedPercentage)
    }

    /// Formats CPU usage as a percentage string like "23.4%"
    static func cpuPercentage(_ cpu: CPUUsage) -> String {
        String(format: "%.1f%%", cpu.usagePercentage)
    }

    /// Formats thermal state as a localized description string.
    static func thermalDescription(_ thermal: ThermalInfo) -> String {
        thermal.localizedDescription
    }

    /// Formats the thermal state as a short emoji + text representation.
    static func thermalShort(_ thermal: ThermalInfo) -> String {
        switch thermal.state {
        case .nominal: return "✅ Nominal"
        case .fair: return "⚠️ Fair"
        case .serious: return "🌡️ Serious"
        case .critical: return "🔥 Critical"
        }
    }
}
