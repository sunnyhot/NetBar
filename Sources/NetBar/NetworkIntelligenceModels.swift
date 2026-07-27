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
    var isHistoryTrackingEnabled: Bool
    var historyRetentionDays: Int

    init(
        hasSeenNotificationOnboarding: Bool,
        isAnomalyDetectionEnabled: Bool,
        isSystemNotificationEnabled: Bool,
        highTrafficThreshold: HighTrafficThreshold,
        isHistoryTrackingEnabled: Bool,
        historyRetentionDays: Int = 30
    ) {
        self.hasSeenNotificationOnboarding = hasSeenNotificationOnboarding
        self.isAnomalyDetectionEnabled = isAnomalyDetectionEnabled
        self.isSystemNotificationEnabled = isSystemNotificationEnabled
        self.highTrafficThreshold = highTrafficThreshold
        self.isHistoryTrackingEnabled = isHistoryTrackingEnabled
        self.historyRetentionDays = historyRetentionDays
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
        isHistoryTrackingEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isHistoryTrackingEnabled
        ) ?? defaultSettings.isHistoryTrackingEnabled
        historyRetentionDays = try container.decodeIfPresent(
            Int.self,
            forKey: .historyRetentionDays
        ) ?? defaultSettings.historyRetentionDays
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(hasSeenNotificationOnboarding, forKey: .hasSeenNotificationOnboarding)
        try container.encode(isAnomalyDetectionEnabled, forKey: .isAnomalyDetectionEnabled)
        try container.encode(isSystemNotificationEnabled, forKey: .isSystemNotificationEnabled)
        try container.encode(highTrafficThreshold, forKey: .highTrafficThreshold)
        try container.encode(isHistoryTrackingEnabled, forKey: .isHistoryTrackingEnabled)
        try container.encode(historyRetentionDays, forKey: .historyRetentionDays)
    }

    static let `default` = NetworkIntelligenceSettings(
        hasSeenNotificationOnboarding: false,
        isAnomalyDetectionEnabled: true,
        isSystemNotificationEnabled: false,
        highTrafficThreshold: .mbps10,
        isHistoryTrackingEnabled: true,
        historyRetentionDays: 30
    )

    private enum CodingKeys: String, CodingKey {
        case hasSeenNotificationOnboarding
        case isAnomalyDetectionEnabled
        case isSystemNotificationEnabled
        case highTrafficThreshold
        case isHistoryTrackingEnabled
        case historyRetentionDays
    }
}

enum NetworkAnomalyKind: String, Codable, CaseIterable, Identifiable {
    case highTraffic

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text("高流量", "High traffic")
        }
    }
}

struct NetworkAnomalyEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: NetworkAnomalyKind
    let title: String
    let message: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        kind: NetworkAnomalyKind,
        title: String,
        message: String,
        timestamp: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.timestamp = timestamp
    }
}

struct NetworkDailySummary: Codable, Equatable, Identifiable {
    let dateKey: String
    var downloadBytes: UInt64
    var uploadBytes: UInt64
    var peakDownloadBytesPerSecond: Double
    var peakUploadBytesPerSecond: Double
    var sampleCount: Int
    var activeSeconds: TimeInterval
    var animationPlaybackCount: UInt64
    var animationPlaybackCountsByCharacter: [String: UInt64]

    var id: String { dateKey }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }

    init(
        dateKey: String,
        downloadBytes: UInt64,
        uploadBytes: UInt64,
        peakDownloadBytesPerSecond: Double,
        peakUploadBytesPerSecond: Double,
        sampleCount: Int,
        activeSeconds: TimeInterval,
        animationPlaybackCount: UInt64 = 0,
        animationPlaybackCountsByCharacter: [String: UInt64] = [:]
    ) {
        self.dateKey = dateKey
        self.downloadBytes = downloadBytes
        self.uploadBytes = uploadBytes
        self.peakDownloadBytesPerSecond = peakDownloadBytesPerSecond
        self.peakUploadBytesPerSecond = peakUploadBytesPerSecond
        self.sampleCount = sampleCount
        self.activeSeconds = activeSeconds
        self.animationPlaybackCount = animationPlaybackCount
        self.animationPlaybackCountsByCharacter = animationPlaybackCountsByCharacter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        dateKey = try container.decode(String.self, forKey: .dateKey)
        downloadBytes = try container.decode(UInt64.self, forKey: .downloadBytes)
        uploadBytes = try container.decode(UInt64.self, forKey: .uploadBytes)
        peakDownloadBytesPerSecond = try container.decode(Double.self, forKey: .peakDownloadBytesPerSecond)
        peakUploadBytesPerSecond = try container.decode(Double.self, forKey: .peakUploadBytesPerSecond)
        sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        activeSeconds = try container.decode(TimeInterval.self, forKey: .activeSeconds)
        animationPlaybackCount = try container.decodeIfPresent(UInt64.self, forKey: .animationPlaybackCount) ?? 0
        animationPlaybackCountsByCharacter = try container.decodeIfPresent(
            [String: UInt64].self,
            forKey: .animationPlaybackCountsByCharacter
        ) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(dateKey, forKey: .dateKey)
        try container.encode(downloadBytes, forKey: .downloadBytes)
        try container.encode(uploadBytes, forKey: .uploadBytes)
        try container.encode(peakDownloadBytesPerSecond, forKey: .peakDownloadBytesPerSecond)
        try container.encode(peakUploadBytesPerSecond, forKey: .peakUploadBytesPerSecond)
        try container.encode(sampleCount, forKey: .sampleCount)
        try container.encode(activeSeconds, forKey: .activeSeconds)
        try container.encode(animationPlaybackCount, forKey: .animationPlaybackCount)
        try container.encode(animationPlaybackCountsByCharacter, forKey: .animationPlaybackCountsByCharacter)
    }

    static func empty(dateKey: String) -> NetworkDailySummary {
        NetworkDailySummary(
            dateKey: dateKey,
            downloadBytes: 0,
            uploadBytes: 0,
            peakDownloadBytesPerSecond: 0,
            peakUploadBytesPerSecond: 0,
            sampleCount: 0,
            activeSeconds: 0,
            animationPlaybackCount: 0,
            animationPlaybackCountsByCharacter: [:]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case dateKey
        case downloadBytes
        case uploadBytes
        case peakDownloadBytesPerSecond
        case peakUploadBytesPerSecond
        case sampleCount
        case activeSeconds
        case animationPlaybackCount
        case animationPlaybackCountsByCharacter
    }
}

struct NetworkIntelligenceSummary: Equatable {
    var latestEvent: NetworkAnomalyEvent?
    var today: NetworkDailySummary
    var recentDays: [NetworkDailySummary]
    var animationPlaybackCountsByCharacter: [String: UInt64]

    var favoriteAnimationCharacterID: String? {
        animationPlaybackCountsByCharacter
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .first?.key
    }

    static let empty = NetworkIntelligenceSummary(
        latestEvent: nil,
        today: .empty(dateKey: "1970-01-01"),
        recentDays: [],
        animationPlaybackCountsByCharacter: [:]
    )
}
