import Foundation

struct TrafficHistoryWindowPresentationModel: Equatable {
    let points: [RatePoint]
    let peakDownloadBytesPerSecond: Double
    let peakUploadBytesPerSecond: Double
}

enum TrafficHistoryWindowPresentation {
    static func make(points: [RatePoint], window: TrafficHistoryWindow) -> TrafficHistoryWindowPresentationModel {
        let filtered = window.points(from: points)
        return TrafficHistoryWindowPresentationModel(
            points: filtered,
            peakDownloadBytesPerSecond: filtered.map(\.downloadBytesPerSecond).max() ?? 0,
            peakUploadBytesPerSecond: filtered.map(\.uploadBytesPerSecond).max() ?? 0
        )
    }
}
