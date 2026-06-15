import Foundation

struct NetworkInsightCenter {
    private var cards: [NetworkInsightCard] = []
    private var lastCardAtByCooldownKey: [String: Date] = [:]
    private let duplicateWindow: TimeInterval = 3 * 60

    mutating func ingest(
        events: [NetworkAnomalyEvent],
        settings: NetworkIntelligenceSettings,
        language: AppLanguage
    ) -> [NetworkInsightCard] {
        guard settings.isInsightStreamEnabled else {
            cards.removeAll()
            lastCardAtByCooldownKey.removeAll()
            return []
        }

        for event in events {
            if let last = lastCardAtByCooldownKey[event.cooldownKey],
               event.timestamp.timeIntervalSince(last) < duplicateWindow {
                continue
            }
            lastCardAtByCooldownKey[event.cooldownKey] = event.timestamp
            cards.insert(card(for: event, settings: settings, language: language), at: 0)
        }

        let limit = max(settings.insightRetentionLimit, 1)
        cards = Array(cards.prefix(limit))
        return cards
    }

    private func card(
        for event: NetworkAnomalyEvent,
        settings: NetworkIntelligenceSettings,
        language: AppLanguage
    ) -> NetworkInsightCard {
        NetworkInsightCard(
            kind: event.kind,
            severity: event.severity,
            title: event.title,
            message: event.message,
            suggestion: settings.isInsightSuggestionEnabled ? suggestion(for: event, language: language) : "",
            timestamp: event.timestamp,
            applicationName: event.applicationName,
            cooldownKey: event.cooldownKey
        )
    }

    private func suggestion(for event: NetworkAnomalyEvent, language: AppLanguage) -> String {
        switch event.kind {
        case .highTraffic:
            return language.text(
                "可以打开活动监视器或 NetBar 应用排行确认是否为预期下载、同步或视频流量。",
                "Open Activity Monitor or NetBar app ranking to confirm whether this is expected download, sync, or streaming traffic."
            )
        case .applicationSpike:
            let app = event.applicationName ?? language.text("该应用", "that app")
            return language.text(
                "如果不是预期行为，可以检查 \(app) 是否正在同步、更新或后台下载。",
                "If this is unexpected, check whether \(app) is syncing, updating, or downloading in the background."
            )
        case .networkDrop:
            return language.text(
                "可以检查 Wi-Fi、代理/VPN、路由器或系统网络设置。",
                "Check Wi-Fi, proxy/VPN, router, or macOS network settings."
            )
        case .networkRecovered:
            return language.text(
                "网络活动已恢复，可以继续观察是否再次波动。",
                "Network activity recovered. Keep watching for repeated drops."
            )
        case .proxyAttributionGap:
            return language.text(
                "应用流量可能集中在代理、VPN 或网络扩展进程中。",
                "Traffic may be concentrated in a proxy, VPN, or network extension process."
            )
        }
    }
}
