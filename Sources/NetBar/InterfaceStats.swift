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

    var hasTraffic: Bool {
        downloadBytesPerSecond > 0 || uploadBytesPerSecond > 0
    }
}

struct NetworkSnapshot: Equatable {
    var timestamp: Date
    var interfaces: [InterfaceRate]
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
    var sampleCount: Int

    static let empty = NetworkSnapshot(
        timestamp: Date(),
        interfaces: [],
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0,
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
    /// 采样差量直出的真实速率;归因覆盖率与汇总使用该值
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let totalReceivedBytes: UInt64
    let totalSentBytes: UInt64
    /// EMA 平滑后的显示速率(列表展示/排序使用);宽限期过后硬归零
    let displayDownloadBytesPerSecond: Double
    let displayUploadBytesPerSecond: Double
    /// raw 已空闲但仍处宽限期内(行保留、置灰)
    let isExpiring: Bool

    init(
        id: String,
        displayName: String,
        processNames: [String],
        pids: [Int32],
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double,
        totalReceivedBytes: UInt64,
        totalSentBytes: UInt64,
        displayDownloadBytesPerSecond: Double? = nil,
        displayUploadBytesPerSecond: Double? = nil,
        isExpiring: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.processNames = processNames
        self.pids = pids
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.totalReceivedBytes = totalReceivedBytes
        self.totalSentBytes = totalSentBytes
        // 未显式提供显示值时回落到 raw,保持构造方(测试/基线)的原语义
        self.displayDownloadBytesPerSecond = displayDownloadBytesPerSecond ?? downloadBytesPerSecond
        self.displayUploadBytesPerSecond = displayUploadBytesPerSecond ?? uploadBytesPerSecond
        self.isExpiring = isExpiring
    }

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
    /// 重开详情窗口后、新采样就绪前,旧列表置灰展示的标记
    var isStale = false

    static let empty = ApplicationTrafficState(
        timestamp: nil,
        applications: [],
        sampleCount: 0,
        isRefreshing: false,
        errorMessage: nil
    )
}
