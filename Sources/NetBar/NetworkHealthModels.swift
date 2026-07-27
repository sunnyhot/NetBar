import Foundation

enum NetworkHealthState: String, Equatable, CaseIterable {
    case good
    case offline

    func title(language: AppLanguage) -> String {
        switch self {
        case .good:
            return language.text("网络可用", "Network available")
        case .offline:
            return language.text("网络离线", "Offline")
        }
    }

    func shortLabel(language: AppLanguage) -> String {
        switch self {
        case .good:
            return language.text("状态正常", "All good")
        case .offline:
            return language.text("网络离线", "Offline")
        }
    }
}

enum NetworkHealthTone: Equatable {
    case normal
    case critical
}

enum NetworkHealthCause: Equatable {
    case highTraffic
    case applicationSpike
    case connectivity
    case localPathUnavailable
    case recovery

    func shortLabel(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text("流量较高", "High traffic")
        case .applicationSpike:
            return language.text("应用占用高", "App spike")
        case .connectivity:
            return language.text("网络活动中断", "Network activity dropped")
        case .localPathUnavailable:
            return language.text("无可用网络", "No network")
        case .recovery:
            return language.text("已恢复", "Recovered")
        }
    }

    func explanation(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text(
                "当前总流量较高，但本地网络接口仍然可用。",
                "Current total throughput is high, while the local network interface remains available."
            )
        case .applicationSpike:
            return language.text(
                "某个应用的流量明显升高。",
                "An application's traffic increased significantly."
            )
        case .connectivity:
            return language.text(
                "最近检测到网络活动中断，但 NetBar 不会主动连接公网确认网络质量。",
                "Network activity recently dropped, but NetBar does not actively contact the internet to verify connection quality."
            )
        case .localPathUnavailable:
            return language.text(
                "macOS 没有报告可用的外部网络接口。",
                "macOS reports no eligible external network interface."
            )
        case .recovery:
            return language.text(
                "网络活动已恢复。",
                "Network activity recovered."
            )
        }
    }

    func recommendation(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text(
                "可在应用列表中查看占用流量的进程。",
                "Check the application list to see what is using bandwidth."
            )
        case .applicationSpike:
            return language.text(
                "可在应用列表中查看对应进程。",
                "Check the application list for the responsible process."
            )
        case .connectivity, .localPathUnavailable:
            return language.text(
                "请检查 Wi-Fi、网线、代理或 VPN 状态。",
                "Check Wi-Fi, Ethernet, proxy, or VPN status."
            )
        case .recovery:
            return language.text(
                "无需额外操作。",
                "No action needed."
            )
        }
    }
}

struct NetworkHealthNotice: Equatable, Identifiable {
    let id: UUID
    let cause: NetworkHealthCause
    let timestamp: Date

    init(id: UUID = UUID(), cause: NetworkHealthCause, timestamp: Date) {
        self.id = id
        self.cause = cause
        self.timestamp = timestamp
    }
}

struct NetworkHealthMetrics: Equatable {
    var hasEligibleExternalInterface: Bool
    var isLocalPathAvailable: Bool

    static let unknown = NetworkHealthMetrics(
        hasEligibleExternalInterface: false,
        isLocalPathAvailable: false
    )
}

struct NetworkHealthSnapshot: Equatable {
    var state: NetworkHealthState
    var primaryCause: NetworkHealthCause?
    var metrics: NetworkHealthMetrics
    var notices: [NetworkHealthNotice]
    var sampledAt: Date

    static func localOnlyHealthy(now: Date, hasInterface: Bool = true) -> NetworkHealthSnapshot {
        localOnly(
            metrics: NetworkHealthMetrics(
                hasEligibleExternalInterface: hasInterface,
                isLocalPathAvailable: hasInterface
            ),
            notices: [],
            now: now
        )
    }

    static func localOnly(
        metrics: NetworkHealthMetrics,
        notices: [NetworkHealthNotice],
        now: Date
    ) -> NetworkHealthSnapshot {
        let isAvailable = metrics.hasEligibleExternalInterface && metrics.isLocalPathAvailable
        return NetworkHealthSnapshot(
            state: isAvailable ? .good : .offline,
            primaryCause: isAvailable ? notices.first?.cause : .localPathUnavailable,
            metrics: metrics,
            notices: notices,
            sampledAt: now
        )
    }
}
