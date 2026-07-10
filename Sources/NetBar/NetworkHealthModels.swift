import Foundation

/// Network health is expressed with four named states. NetBar never shows a
/// pseudo-precise 0–100 score, per the approved design.
enum NetworkHealthState: String, Equatable, CaseIterable {
    case good
    case fluctuating
    case poor
    case offline

    /// Tone buckets consumed by the status bar rendering pipeline. The renderer
    /// maps these to accent colors at draw time; this type never decides pixels.
    var tone: NetworkHealthTone {
        switch self {
        case .good: return .normal
        case .fluctuating: return .amber
        case .poor: return .coral
        case .offline: return .critical
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .good:
            return language.text("网络健康", "Healthy")
        case .fluctuating:
            return language.text("连接波动", "Fluctuating")
        case .poor:
            return language.text("连接较差", "Poor connection")
        case .offline:
            return language.text("网络离线", "Offline")
        }
    }

    /// One-line short status used by the status bar when smart mode is enabled.
    func shortLabel(language: AppLanguage) -> String {
        switch self {
        case .good:
            return language.text("状态正常", "All good")
        case .fluctuating:
            return language.text("延迟波动", "Latency fluctuating")
        case .poor:
            return language.text("连接较差", "Poor connection")
        case .offline:
            return language.text("网络离线", "Offline")
        }
    }
}

/// Accent buckets for the status bar color pipeline.
enum NetworkHealthTone: Equatable {
    case normal
    case amber
    case coral
    case critical
}

/// Describes whether a health conclusion is based on fresh active evidence,
/// local-only evidence, or is currently paused/unavailable.
enum NetworkHealthEvidenceMode: String, Equatable {
    case localOnly
    case active
    case paused
    case unavailable

    func title(language: AppLanguage) -> String {
        switch self {
        case .localOnly:
            return language.text("本地证据", "Local evidence")
        case .active:
            return language.text("主动检测", "Active check")
        case .paused:
            return language.text("已暂停", "Paused")
        case .unavailable:
            return language.text("暂不可用", "Unavailable")
        }
    }
}

/// The primary cause behind a health conclusion. Drives the short label shown
/// in the popover and the status bar. Notices can carry extra context but do
/// not by themselves lower the health state.
enum NetworkHealthCause: Equatable {
    case highTraffic
    case applicationSpike
    case proxyAttributionGap
    case connectivity
    case dns
    case latency
    case localPathUnavailable
    case recovery

    /// Short, status-bar-friendly label.
    func shortLabel(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text("流量较高", "High traffic")
        case .applicationSpike:
            return language.text("应用占用高", "App spike")
        case .proxyAttributionGap:
            return language.text("代理归因差异", "Proxy attribution")
        case .connectivity:
            return language.text("参考目标不可达", "Reference unreachable")
        case .dns:
            return language.text("解析较慢", "DNS slow")
        case .latency:
            return language.text("延迟波动", "Latency fluctuating")
        case .localPathUnavailable:
            return language.text("无可用网络", "No network")
        case .recovery:
            return language.text("已恢复", "Recovered")
        }
    }

    /// Longer popover explanation.
    func explanation(language: AppLanguage) -> String {
        switch self {
        case .highTraffic:
            return language.text(
                "当前总流量较高，但网络连接本身正常。",
                "Current total throughput is high, but connectivity is normal."
            )
        case .applicationSpike:
            return language.text(
                "某个应用的流量明显升高，网络连接本身正常。",
                "An application's traffic spiked; connectivity is normal."
            )
        case .proxyAttributionGap:
            return language.text(
                "代理或 VPN 接管了部分流量，应用归因可能与接口总量不一致。",
                "A proxy or VPN is handling part of the traffic, so app attribution may not match interface totals."
            )
        case .connectivity:
            return language.text(
                "无法连接到参考目标（github.com）。本地网络路径仍可用，不代表整体断网。",
                "Could not reach the reference target (github.com). The local network path is still available, so this is not a full outage."
            )
        case .dns:
            return language.text(
                "域名解析耗时较长，可能导致打开网页变慢。",
                "DNS resolution is slow, which can make browsing feel sluggish."
            )
        case .latency:
            return language.text(
                "连接响应延迟偏高，实时应用可能受到影响。",
                "Response latency is elevated; realtime apps may be affected."
            )
        case .localPathUnavailable:
            return language.text(
                "macOS 没有报告可用的外部网络接口。",
                "macOS reports no eligible external network interface."
            )
        case .recovery:
            return language.text(
                "网络连接已恢复。",
                "Network connectivity has recovered."
            )
        }
    }

    /// Recommended next action for the popover.
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
        case .proxyAttributionGap:
            return language.text(
                "这通常符合预期，无需处理。",
                "This is usually expected and needs no action."
            )
        case .connectivity:
            return language.text(
                "稍后可点击「立即复测」重新检查；若仅参考目标问题，实际网络可能正常。",
                "Tap Retest Now to re-check. If only the reference target is affected, your real connection may be fine."
            )
        case .dns:
            return language.text(
                "可尝试切换 DNS 或重启路由器。",
                "Try changing DNS servers or restarting your router."
            )
        case .latency:
            return language.text(
                "可检查 Wi-Fi 信号或切换网络。",
                "Check Wi-Fi signal or switch networks."
            )
        case .localPathUnavailable:
            return language.text(
                "请检查 Wi-Fi 或网线连接。",
                "Check your Wi-Fi or Ethernet connection."
            )
        case .recovery:
            return language.text(
                "无需额外操作。",
                "No action needed."
            )
        }
    }
}

/// Non-quality context (high traffic, app spikes, proxy gaps, recovery). Notices
/// can affect status bar emphasis or character choice but never lower the
/// health state on their own.
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

/// Passive + active measurements backing a health conclusion.
struct NetworkHealthMetrics: Equatable {
    /// Measured DNS resolution duration in milliseconds (active probe only).
    var dnsDurationMS: Double?
    /// Measured HTTPS response latency in milliseconds (active probe only).
    var responseLatencyMS: Double?
    /// Rolling window size used to compute recent failures (normally 5).
    var recentAttemptCount: Int
    /// Failures within the recent window.
    var recentFailureCount: Int
    /// True when at least one external interface carries traffic counters.
    var hasEligibleExternalInterface: Bool
    /// True when macOS reports a satisfied network path.
    var isLocalPathAvailable: Bool

    static let unknown = NetworkHealthMetrics(
        dnsDurationMS: nil,
        responseLatencyMS: nil,
        recentAttemptCount: 0,
        recentFailureCount: 0,
        hasEligibleExternalInterface: false,
        isLocalPathAvailable: false
    )
}

/// A complete, presentation-independent health conclusion. Consumed by the
/// popover, status bar text, status bar color, smart character recommendation,
/// and animation behavior — all from a single source of truth.
struct NetworkHealthSnapshot: Equatable {
    var state: NetworkHealthState
    var evidenceMode: NetworkHealthEvidenceMode
    var primaryCause: NetworkHealthCause?
    var metrics: NetworkHealthMetrics
    var notices: [NetworkHealthNotice]
    var sampledAt: Date
    var expiresAt: Date?
    var isRetestInProgress: Bool

    /// Recent failures formatted as "0 / 5".
    func failureRatioText() -> String {
        "\(metrics.recentFailureCount) / \(max(metrics.recentAttemptCount, recentFailureWindowCap))"
    }

    func isExpired(now: Date) -> Bool {
        guard let expiresAt else { return false }
        return now >= expiresAt
    }

    /// Default local-only healthy snapshot shown before any active diagnostics.
    static func localOnlyHealthy(now: Date, hasInterface: Bool = true) -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(
            state: hasInterface ? .good : .offline,
            evidenceMode: .localOnly,
            primaryCause: nil,
            metrics: NetworkHealthMetrics(
                dnsDurationMS: nil,
                responseLatencyMS: nil,
                recentAttemptCount: 0,
                recentFailureCount: 0,
                hasEligibleExternalInterface: hasInterface,
                isLocalPathAvailable: hasInterface
            ),
            notices: [],
            sampledAt: now,
            expiresAt: nil,
            isRetestInProgress: false
        )
    }
}

/// Threshold constants live in one place so tests can inject boundary values
/// without spreading magic numbers across the codebase.
struct NetworkHealthThresholds: Equatable {
    /// Cap for the rolling window of recent probe samples.
    let recentSampleWindow: Int
    /// DNS at or above this (ms) is a candidate for `good`.
    let goodDNSMaxMS: Double
    /// DNS in [goodDNSMaxMS, fluctuatingDNSMaxMS) hints at `fluctuating`.
    let fluctuatingDNSMaxMS: Double
    /// DNS at or above this (ms) hints at `poor`.
    let poorDNSMinMS: Double
    /// Response latency at or above this (ms) is a candidate for `good`.
    let goodLatencyMaxMS: Double
    /// Response latency in [goodLatencyMaxMS, fluctuatingLatencyMaxMS) hints at `fluctuating`.
    let fluctuatingLatencyMaxMS: Double
    /// Response latency at or above this (ms) hints at `poor`.
    let poorLatencyMinMS: Double
    /// Failures at or above this count within the window hint at `poor`.
    let poorRecentFailureMinCount: Int
    /// Failures at exactly this count hint at `fluctuating`.
    let fluctuatingRecentFailureCount: Int
    /// Consecutive candidate evaluations required to promote a degradation.
    let degradationPromotionStreak: Int
    /// Consecutive good candidate evaluations required to recover to `good`.
    let recoveryStreak: Int

    static let `default` = NetworkHealthThresholds(
        recentSampleWindow: 5,
        goodDNSMaxMS: 400,
        fluctuatingDNSMaxMS: 1000,
        poorDNSMinMS: 1000,
        goodLatencyMaxMS: 600,
        fluctuatingLatencyMaxMS: 1500,
        poorLatencyMinMS: 1500,
        poorRecentFailureMinCount: 2,
        fluctuatingRecentFailureCount: 1,
        degradationPromotionStreak: 2,
        recoveryStreak: 3
    )
}

/// Cap referenced by display formatting; mirrors the default window size.
private let recentFailureWindowCap = NetworkHealthThresholds.default.recentSampleWindow
