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
    static func evaluate(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        intelligenceSummary: NetworkIntelligenceSummary,
        settings: NetworkIntelligenceSettings,
        language: AppLanguage
    ) -> SmartStatusBarContext {
        guard settings.isSmartStatusBarModeEnabled else { return .manual }

        if settings.showsSmartAnomalyMarker,
           let event = intelligenceSummary.latestEvent,
           event.severity != .info {
            return SmartStatusBarContext(
                emphasis: .anomaly(event.kind),
                trafficDisplayModeOverride: nil,
                overrideLine: "! \(event.kind.title(language: language))"
            )
        }

        if settings.showsSmartTopApplication,
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

        if snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond >= 10_485_760 {
            return SmartStatusBarContext(
                emphasis: .totalTraffic,
                trafficDisplayModeOverride: .total,
                overrideLine: nil
            )
        }

        return .manual
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
