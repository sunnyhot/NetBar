import Foundation

struct InterfaceStats: Identifiable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let receivedPackets: UInt64
    let sentPackets: UInt64
    let isPrimary: Bool

    init(
        name: String,
        displayName: String? = nil,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        receivedPackets: UInt64,
        sentPackets: UInt64,
        isPrimary: Bool = false
    ) {
        self.id = name
        self.name = name
        self.displayName = displayName ?? name
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.receivedPackets = receivedPackets
        self.sentPackets = sentPackets
        self.isPrimary = isPrimary
    }
}

struct InterfaceRate: Identifiable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let totalReceivedBytes: UInt64
    let totalSentBytes: UInt64
    let receivedPackets: UInt64
    let sentPackets: UInt64
    let isPrimary: Bool
}

struct NetworkSnapshot: Equatable {
    var timestamp: Date
    var interfaces: [InterfaceRate]
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
    var totalReceivedBytes: UInt64
    var totalSentBytes: UInt64
    var sampleCount: Int

    static let empty = NetworkSnapshot(
        timestamp: Date(),
        interfaces: [],
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0,
        totalReceivedBytes: 0,
        totalSentBytes: 0,
        sampleCount: 0
    )
}

struct ApplicationTrafficStats: Identifiable, Equatable {
    let id: String
    let processName: String
    let displayName: String
    let pid: Int32?
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

struct ApplicationTrafficRate: Identifiable, Equatable {
    let id: String
    let displayName: String
    let processNames: [String]
    let pids: [Int32]
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let totalReceivedBytes: UInt64
    let totalSentBytes: UInt64

    var processLabel: String {
        let pidText = pids.prefix(3).map(String.init).joined(separator: ", ")
        if pids.count > 3 {
            return "\(pidText), ..."
        }
        return pidText
    }
}

struct ApplicationTrafficState: Equatable {
    var timestamp: Date?
    var applications: [ApplicationTrafficRate]
    var sampleCount: Int
    var isRefreshing: Bool
    var errorMessage: String?

    static let empty = ApplicationTrafficState(
        timestamp: nil,
        applications: [],
        sampleCount: 0,
        isRefreshing: false,
        errorMessage: nil
    )
}
