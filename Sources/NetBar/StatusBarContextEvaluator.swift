import Foundation

enum SmartStatusBarEmphasis: Equatable {
    case manual
    case anomaly(NetworkAnomalyKind)
    case upload
    case totalTraffic
    case topApplication(String)
    case health(NetworkHealthState)
}

struct SmartStatusBarContext: Equatable {
    let emphasis: SmartStatusBarEmphasis
    let trafficDisplayModeOverride: StatusBarTrafficDisplayMode?
    let overrideLine: String?
    /// Accent tone for the status bar color pipeline, derived from health state.
    /// `.normal` means "use the user's default"; smart overrides set amber/coral/critical.
    let tone: NetworkHealthTone

    static let manual = SmartStatusBarContext(
        emphasis: .manual,
        trafficDisplayModeOverride: nil,
        overrideLine: nil,
        tone: .normal
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
        health: NetworkHealthSnapshot? = nil,
        now: Date = Date()
    ) -> SmartStatusBarContext {
        guard settings.isSmartStatusBarModeEnabled else { return .manual }

        // Health state sets tone and, when degraded, overrides the short status
        // text. Good state preserves the user's traffic layout. This takes
        // priority over traffic-driven emphasis so a connectivity problem is
        // never masked by "high traffic".
        if let health {
            switch health.state {
            case .offline:
                return SmartStatusBarContext(
                    emphasis: .health(.offline),
                    trafficDisplayModeOverride: nil,
                    overrideLine: language.text("网络离线", "Offline"),
                    tone: .critical
                )
            case .poor:
                let label = health.primaryCause?.shortLabel(language: language)
                    ?? language.text("连接较差", "Poor connection")
                return SmartStatusBarContext(
                    emphasis: .health(.poor),
                    trafficDisplayModeOverride: nil,
                    overrideLine: label,
                    tone: .coral
                )
            case .fluctuating:
                let label = health.primaryCause?.shortLabel(language: language)
                    ?? language.text("延迟波动", "Latency fluctuating")
                return SmartStatusBarContext(
                    emphasis: .health(.fluctuating),
                    trafficDisplayModeOverride: nil,
                    overrideLine: label,
                    tone: .amber
                )
            case .good:
                // Preserve user layout; tone stays normal.
                break
            }
        }

        if settings.showsSmartAnomalyMarker,
           let event = intelligenceSummary.latestEvent,
           isFresh(event.timestamp, now: now, interval: anomalyFreshnessInterval),
           event.severity != .info {
            return SmartStatusBarContext(
                emphasis: .anomaly(event.kind),
                trafficDisplayModeOverride: nil,
                overrideLine: "! \(event.kind.title(language: language))",
                tone: .normal
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
                overrideLine: label,
                tone: .normal
            )
        }

        if snapshot.uploadBytesPerSecond >= max(snapshot.downloadBytesPerSecond * 1.5, 1_048_576) {
            return SmartStatusBarContext(
                emphasis: .upload,
                trafficDisplayModeOverride: .uploadOnly,
                overrideLine: nil,
                tone: .normal
            )
        }

        if snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond >= settings.highTrafficThreshold.rawValue {
            return SmartStatusBarContext(
                emphasis: .totalTraffic,
                trafficDisplayModeOverride: .total,
                overrideLine: nil,
                tone: .normal
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
        health: NetworkHealthSnapshot? = nil,
        now: Date = Date()
    ) -> String? {
        guard settings.isSmartCharacterSuggestionEnabled else { return nil }

        // Health-driven character suggestions take priority over traffic ones
        // so a connectivity problem is always visible. Good state falls through
        // to the existing cause-based logic below.
        if let health {
            switch health.state {
            case .offline:
                return "little_cloud"
            case .poor, .fluctuating:
                // Connectivity, DNS, latency, or attribution issues suggest
                // little_cloud. High-traffic / app-spike notices reuse their
                // existing characters below.
                if let cause = health.primaryCause {
                    switch cause {
                    case .highTraffic:
                        return "penguin"
                    case .applicationSpike:
                        return "shiba_inu"
                    case .recovery:
                        return "bunny"
                    default:
                        return "little_cloud"
                    }
                }
                return "little_cloud"
            case .good:
                break
            }
        }

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
