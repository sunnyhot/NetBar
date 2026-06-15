import Foundation

struct NetworkHistoryRangeSummary: Equatable {
    let id: String
    let title: String
    let days: [NetworkDailySummary]

    var downloadBytes: UInt64 { days.reduce(0) { $0 + $1.downloadBytes } }
    var uploadBytes: UInt64 { days.reduce(0) { $0 + $1.uploadBytes } }
    var totalBytes: UInt64 { downloadBytes + uploadBytes }
    var activeSeconds: TimeInterval { days.reduce(0) { $0 + $1.activeSeconds } }
}

struct NetworkHistoryPeak: Equatable {
    let dateKey: String
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

struct NetworkHistoryPresentationModel: Equatable {
    let today: NetworkDailySummary
    let sevenDay: NetworkHistoryRangeSummary
    let thirtyDay: NetworkHistoryRangeSummary
    let peakDownload: NetworkHistoryPeak?
    let peakUpload: NetworkHistoryPeak?
    let applicationRanking: [ApplicationDailyUsage]
    let estimateNotice: String
}

enum NetworkHistoryPresentation {
    static func make(
        summary: NetworkIntelligenceSummary,
        language: AppLanguage,
        applicationLimit: Int = 10
    ) -> NetworkHistoryPresentationModel {
        let recent = summary.recentDays
        let sevenDays = Array(recent.suffix(7))
        let thirtyDays = Array(recent.suffix(30))
        let rankedApplications = mergedApplications(from: [summary.today] + thirtyDays)
            .sorted {
                if $0.totalBytes != $1.totalBytes { return $0.totalBytes > $1.totalBytes }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }

        return NetworkHistoryPresentationModel(
            today: summary.today,
            sevenDay: NetworkHistoryRangeSummary(
                id: "sevenDay",
                title: language.text("最近 7 天", "Last 7 Days"),
                days: sevenDays
            ),
            thirtyDay: NetworkHistoryRangeSummary(
                id: "thirtyDay",
                title: language.text("最近 30 天", "Last 30 Days"),
                days: thirtyDays
            ),
            peakDownload: peak(in: thirtyDays, useDownload: true),
            peakUpload: peak(in: thirtyDays, useDownload: false),
            applicationRanking: Array(rankedApplications.prefix(applicationLimit)),
            estimateNotice: language.text(
                "历史统计为本地估算值，用于趋势判断，不等同于运营商计费。",
                "History values are local estimates for trend awareness and are not billing-grade measurements."
            )
        )
    }

    private static func peak(in days: [NetworkDailySummary], useDownload: Bool) -> NetworkHistoryPeak? {
        let best = days.max {
            let lhs = useDownload ? $0.peakDownloadBytesPerSecond : $0.peakUploadBytesPerSecond
            let rhs = useDownload ? $1.peakDownloadBytesPerSecond : $1.peakUploadBytesPerSecond
            return lhs < rhs
        }
        guard let best else { return nil }
        return NetworkHistoryPeak(
            dateKey: best.dateKey,
            downloadBytesPerSecond: best.peakDownloadBytesPerSecond,
            uploadBytesPerSecond: best.peakUploadBytesPerSecond
        )
    }

    private static func mergedApplications(from days: [NetworkDailySummary]) -> [ApplicationDailyUsage] {
        var merged: [String: ApplicationDailyUsage] = [:]
        for day in days {
            for app in day.topApplications {
                var current = merged[app.applicationID] ?? app
                if merged[app.applicationID] != nil {
                    current.downloadBytes += app.downloadBytes
                    current.uploadBytes += app.uploadBytes
                    current.lastSeenAt = max(current.lastSeenAt, app.lastSeenAt)
                    current.processNames = Array(Set(current.processNames + app.processNames)).sorted()
                }
                merged[app.applicationID] = current
            }
        }
        return Array(merged.values)
    }
}
