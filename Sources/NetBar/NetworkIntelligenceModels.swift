import Foundation

enum HighTrafficThreshold: Double, Codable, CaseIterable, Identifiable {
    case mbps5 = 5_242_880
    case mbps10 = 10_485_760
    case mbps25 = 26_214_400
    case mbps50 = 52_428_800

    var id: Double { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .mbps5: return language.text("5 MB/s", "5 MB/s")
        case .mbps10: return language.text("10 MB/s", "10 MB/s")
        case .mbps25: return language.text("25 MB/s", "25 MB/s")
        case .mbps50: return language.text("50 MB/s", "50 MB/s")
        }
    }
}

struct NetworkIntelligenceSettings: Codable, Equatable {
    var hasSeenNotificationOnboarding: Bool
    var isAnomalyDetectionEnabled: Bool
    var isSystemNotificationEnabled: Bool
    var highTrafficThreshold: HighTrafficThreshold
    var isApplicationSpikeAlertEnabled: Bool
    var isNetworkDropAlertEnabled: Bool
    var isProxyAttributionAlertEnabled: Bool
    var isHistoryTrackingEnabled: Bool

    init(
        hasSeenNotificationOnboarding: Bool,
        isAnomalyDetectionEnabled: Bool,
        isSystemNotificationEnabled: Bool,
        highTrafficThreshold: HighTrafficThreshold,
        isApplicationSpikeAlertEnabled: Bool,
        isNetworkDropAlertEnabled: Bool,
        isProxyAttributionAlertEnabled: Bool,
        isHistoryTrackingEnabled: Bool
    ) {
        self.hasSeenNotificationOnboarding = hasSeenNotificationOnboarding
        self.isAnomalyDetectionEnabled = isAnomalyDetectionEnabled
        self.isSystemNotificationEnabled = isSystemNotificationEnabled
        self.highTrafficThreshold = highTrafficThreshold
        self.isApplicationSpikeAlertEnabled = isApplicationSpikeAlertEnabled
        self.isNetworkDropAlertEnabled = isNetworkDropAlertEnabled
        self.isProxyAttributionAlertEnabled = isProxyAttributionAlertEnabled
        self.isHistoryTrackingEnabled = isHistoryTrackingEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaultSettings = NetworkIntelligenceSettings.default

        hasSeenNotificationOnboarding = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasSeenNotificationOnboarding
        ) ?? defaultSettings.hasSeenNotificationOnboarding
        isAnomalyDetectionEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isAnomalyDetectionEnabled
        ) ?? defaultSettings.isAnomalyDetectionEnabled
        isSystemNotificationEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isSystemNotificationEnabled
        ) ?? defaultSettings.isSystemNotificationEnabled
        highTrafficThreshold = try container.decodeIfPresent(
            HighTrafficThreshold.self,
            forKey: .highTrafficThreshold
        ) ?? defaultSettings.highTrafficThreshold
        isApplicationSpikeAlertEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isApplicationSpikeAlertEnabled
        ) ?? defaultSettings.isApplicationSpikeAlertEnabled
        isNetworkDropAlertEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isNetworkDropAlertEnabled
        ) ?? defaultSettings.isNetworkDropAlertEnabled
        isProxyAttributionAlertEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isProxyAttributionAlertEnabled
        ) ?? defaultSettings.isProxyAttributionAlertEnabled
        isHistoryTrackingEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isHistoryTrackingEnabled
        ) ?? defaultSettings.isHistoryTrackingEnabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(hasSeenNotificationOnboarding, forKey: .hasSeenNotificationOnboarding)
        try container.encode(isAnomalyDetectionEnabled, forKey: .isAnomalyDetectionEnabled)
        try container.encode(isSystemNotificationEnabled, forKey: .isSystemNotificationEnabled)
        try container.encode(highTrafficThreshold, forKey: .highTrafficThreshold)
        try container.encode(isApplicationSpikeAlertEnabled, forKey: .isApplicationSpikeAlertEnabled)
        try container.encode(isNetworkDropAlertEnabled, forKey: .isNetworkDropAlertEnabled)
        try container.encode(isProxyAttributionAlertEnabled, forKey: .isProxyAttributionAlertEnabled)
        try container.encode(isHistoryTrackingEnabled, forKey: .isHistoryTrackingEnabled)
    }

    static let `default` = NetworkIntelligenceSettings(
        hasSeenNotificationOnboarding: false,
        isAnomalyDetectionEnabled: true,
        isSystemNotificationEnabled: false,
        highTrafficThreshold: .mbps10,
        isApplicationSpikeAlertEnabled: true,
        isNetworkDropAlertEnabled: true,
        isProxyAttributionAlertEnabled: true,
        isHistoryTrackingEnabled: true
    )

    private enum CodingKeys: String, CodingKey {
        case hasSeenNotificationOnboarding
        case isAnomalyDetectionEnabled
        case isSystemNotificationEnabled
        case highTrafficThreshold
        case isApplicationSpikeAlertEnabled
        case isNetworkDropAlertEnabled
        case isProxyAttributionAlertEnabled
        case isHistoryTrackingEnabled
    }
}

enum NetworkAnomalySeverity: String, Codable, Equatable {
    case info
    case warning
    case critical
}

enum NetworkAnomalyKind: String, Codable, CaseIterable, Identifiable {
    case highTraffic
    case applicationSpike
    case networkDrop
    case networkRecovered
    case proxyAttributionGap

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text("高流量", "High traffic")
        case .applicationSpike:
            return language.text("应用突增", "Application spike")
        case .networkDrop:
            return language.text("网络断流", "Network drop")
        case .networkRecovered:
            return language.text("网络恢复", "Network recovered")
        case .proxyAttributionGap:
            return language.text("代理归因差异", "Proxy attribution gap")
        }
    }
}

struct NetworkAnomalyEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: NetworkAnomalyKind
    let severity: NetworkAnomalySeverity
    let title: String
    let message: String
    let timestamp: Date
    let applicationName: String?
    let bytesPerSecond: Double?
    let cooldownKey: String

    init(
        id: UUID = UUID(),
        kind: NetworkAnomalyKind,
        severity: NetworkAnomalySeverity,
        title: String,
        message: String,
        timestamp: Date,
        applicationName: String? = nil,
        bytesPerSecond: Double? = nil,
        cooldownKey: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.applicationName = applicationName
        self.bytesPerSecond = bytesPerSecond
        self.cooldownKey = cooldownKey
    }
}

struct ApplicationDailyUsage: Codable, Equatable, Identifiable {
    let applicationID: String
    var displayName: String
    var processNames: [String]
    var downloadBytes: UInt64
    var uploadBytes: UInt64
    var lastSeenAt: Date
    var role: ApplicationAttributionRole

    var id: String { applicationID }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }
}

struct NetworkDailySummary: Codable, Equatable, Identifiable {
    let dateKey: String
    var downloadBytes: UInt64
    var uploadBytes: UInt64
    var peakDownloadBytesPerSecond: Double
    var peakUploadBytesPerSecond: Double
    var sampleCount: Int
    var activeSeconds: TimeInterval
    var topApplications: [ApplicationDailyUsage]

    var id: String { dateKey }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }

    static func empty(dateKey: String) -> NetworkDailySummary {
        NetworkDailySummary(
            dateKey: dateKey,
            downloadBytes: 0,
            uploadBytes: 0,
            peakDownloadBytesPerSecond: 0,
            peakUploadBytesPerSecond: 0,
            sampleCount: 0,
            activeSeconds: 0,
            topApplications: []
        )
    }
}

struct NetworkIntelligenceSummary: Equatable {
    var latestEvent: NetworkAnomalyEvent?
    var today: NetworkDailySummary
    var recentDays: [NetworkDailySummary]
    var realtimeTopApplications: [ApplicationTrafficRate]
    var todayTopApplications: [ApplicationDailyUsage]

    static let empty = NetworkIntelligenceSummary(
        latestEvent: nil,
        today: .empty(dateKey: "1970-01-01"),
        recentDays: [],
        realtimeTopApplications: [],
        todayTopApplications: []
    )
}
