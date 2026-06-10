import Foundation

struct NetworkIntelligenceCoordinator {
    let notify: (NetworkAnomalyEvent, NetworkIntelligenceSettings) -> Void
    let petCue: (NetworkAnomalyEvent) -> Void
    let petDailySummary: (NetworkDailySummary) -> Void

    func handle(
        events: [NetworkAnomalyEvent],
        todaySummary: NetworkDailySummary,
        settings: NetworkIntelligenceSettings
    ) {
        for event in events {
            notify(event, settings)
            petCue(event)
        }
        petDailySummary(todaySummary)
    }
}
