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
