import Foundation

enum TrafficPulseChartScale {
    static func normalizedValues(_ values: [Double]) -> [Double] {
        guard let maxValue = values.max(), maxValue > 0 else {
            return values.map { _ in 0 }
        }
        return values.map { $0 / maxValue }
    }
}

struct TrafficHistoryWindowPresentationModel: Equatable {
    let points: [RatePoint]
    let peakDownloadBytesPerSecond: Double
    let peakUploadBytesPerSecond: Double
    let normalizedDownloadValues: [Double]
    let normalizedUploadValues: [Double]
}

enum TrafficHistoryWindowPresentation {
    static func make(points: [RatePoint], window: TrafficHistoryWindow) -> TrafficHistoryWindowPresentationModel {
        let filtered = window.points(from: points)
        let downloadValues = filtered.map(\.downloadBytesPerSecond)
        let uploadValues = filtered.map(\.uploadBytesPerSecond)
        return TrafficHistoryWindowPresentationModel(
            points: filtered,
            peakDownloadBytesPerSecond: downloadValues.max() ?? 0,
            peakUploadBytesPerSecond: uploadValues.max() ?? 0,
            normalizedDownloadValues: TrafficPulseChartScale.normalizedValues(downloadValues),
            normalizedUploadValues: TrafficPulseChartScale.normalizedValues(uploadValues)
        )
    }
}
