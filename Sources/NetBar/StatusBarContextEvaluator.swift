import Foundation

enum SmartStatusBarEmphasis: Equatable {
    case manual
    case anomaly(NetworkAnomalyKind)
    case upload
    case totalTraffic
    case topApplication(String)
}

struct SmartStatusBarContext: Equatable {
    let emphasis: SmartStatusBarEmphasis
    let trafficDisplayModeOverride: StatusBarTrafficDisplayMode?
    let overrideLine: String?

    static let manual = SmartStatusBarContext(
        emphasis: .manual,
        trafficDisplayModeOverride: nil,
        overrideLine: nil
    )
}

enum StatusBarContextEvaluator {
    private static let anomalyFreshnessInterval: TimeInterval = 60
    private static let appTrafficFreshnessInterval: TimeInterval = 10

    static func evaluate(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        intelligenceSummary: NetworkIntelligenceSummary,
        settings: NetworkIntelligenceSettings,
        language: AppLanguage,
        now: Date = Date()
    ) -> SmartStatusBarContext {
        guard settings.isSmartStatusBarModeEnabled else { return .manual }

        if settings.showsSmartAnomalyMarker,
           let event = intelligenceSummary.latestEvent,
           isFresh(event.timestamp, now: now, interval: anomalyFreshnessInterval),
           event.severity != .info {
            return SmartStatusBarContext(
                emphasis: .anomaly(event.kind),
                trafficDisplayModeOverride: nil,
                overrideLine: "! \(event.kind.title(language: language))"
            )
        }

        if settings.showsSmartTopApplication,
           appTraffic.timestamp.map({ isFresh($0, now: now, interval: appTrafficFreshnessInterval) }) == true,
           let app = topApplication(from: appTraffic),
           app.downloadBytesPerSecond + app.uploadBytesPerSecond >= 5_242_880 {
            let label = shortened(app.displayName)
            return SmartStatusBarContext(
                emphasis: .topApplication(label),
                trafficDisplayModeOverride: nil,
                overrideLine: label
            )
        }

        if snapshot.uploadBytesPerSecond >= max(snapshot.downloadBytesPerSecond * 1.5, 1_048_576) {
            return SmartStatusBarContext(
                emphasis: .upload,
                trafficDisplayModeOverride: .uploadOnly,
                overrideLine: nil
            )
        }

        if snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond >= settings.highTrafficThreshold.rawValue {
            return SmartStatusBarContext(
                emphasis: .totalTraffic,
                trafficDisplayModeOverride: .total,
                overrideLine: nil
            )
        }

        return .manual
    }

    private static func isFresh(_ timestamp: Date, now: Date, interval: TimeInterval) -> Bool {
        now.timeIntervalSince(timestamp) <= interval
    }

    private static func topApplication(from appTraffic: ApplicationTrafficState) -> ApplicationTrafficRate? {
        ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        ).first
    }

    private static func shortened(_ name: String) -> String {
        guard name.count > 12 else { return name }
        return "\(name.prefix(9))..."
    }
}

enum SmartCharacterSuggestionEvaluator {
    private static let anomalyFreshnessInterval: TimeInterval = 60
    private static let appTrafficFreshnessInterval: TimeInterval = 10
    private static let topApplicationBurstThreshold: Double = 5_242_880
    private static let uploadDominantThreshold: Double = 1_048_576
    private static let idleThreshold: Double = 100

    static func suggestedCharacterID(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        intelligenceSummary: NetworkIntelligenceSummary,
        settings: NetworkIntelligenceSettings,
        now: Date = Date()
    ) -> String? {
        guard settings.isSmartCharacterSuggestionEnabled else { return nil }

        if let event = intelligenceSummary.latestEvent,
           isFresh(event.timestamp, now: now, interval: anomalyFreshnessInterval),
           event.severity != .info {
            switch event.kind {
            case .networkDrop, .proxyAttributionGap:
                return "little_cloud"
            case .applicationSpike:
                return "shiba_inu"
            case .highTraffic:
                return "penguin"
            case .networkRecovered:
                return "bunny"
            }
        }

        if appTraffic.timestamp.map({ isFresh($0, now: now, interval: appTrafficFreshnessInterval) }) == true,
           let app = topApplication(from: appTraffic),
           app.downloadBytesPerSecond + app.uploadBytesPerSecond >= topApplicationBurstThreshold {
            return "shiba_inu"
        }

        if snapshot.uploadBytesPerSecond >= max(snapshot.downloadBytesPerSecond * 1.5, uploadDominantThreshold) {
            return "little_cloud"
        }

        let totalBytesPerSecond = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
        if totalBytesPerSecond >= settings.highTrafficThreshold.rawValue {
            return "penguin"
        }

        if totalBytesPerSecond < idleThreshold {
            return "tiny_plant"
        }

        return nil
    }

    private static func isFresh(_ timestamp: Date, now: Date, interval: TimeInterval) -> Bool {
        now.timeIntervalSince(timestamp) <= interval
    }

    private static func topApplication(from appTraffic: ApplicationTrafficState) -> ApplicationTrafficRate? {
        ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        ).first
    }
}
