import Foundation

struct NetworkIntelligenceCoordinator {
    let notify: (NetworkAnomalyEvent, NetworkIntelligenceSettings) -> Void

    func handle(
        events: [NetworkAnomalyEvent],
        settings: NetworkIntelligenceSettings
    ) {
        for event in events {
            notify(event, settings)
        }
    }
}
