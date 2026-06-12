import Foundation

struct NetworkSamplingDiagnostics: Equatable {
    let isRunning: Bool
    let isApplicationTrafficVisible: Bool
    let isApplicationTrafficSamplingEnabled: Bool
    let isPowerSaveModeEnabled: Bool
}

struct DiagnosticsSnapshot: Equatable {
    let appVersion: String
    let bundleIdentifier: String
    let updateStatus: String
    let lastCheckedAt: Date?
    let sampling: NetworkSamplingDiagnostics
    let notificationAuthorization: String
    let historyStatus: String
    let historyPath: String
}

enum DiagnosticsCenter {
    static func makeSnapshot(
        appVersion: String,
        bundleIdentifier: String,
        updateStatus: String,
        lastCheckedAt: Date?,
        sampling: NetworkSamplingDiagnostics,
        notificationAuthorization: String,
        historyStatus: String,
        historyPath: String
    ) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            appVersion: appVersion,
            bundleIdentifier: bundleIdentifier,
            updateStatus: updateStatus,
            lastCheckedAt: lastCheckedAt,
            sampling: sampling,
            notificationAuthorization: notificationAuthorization,
            historyStatus: historyStatus,
            historyPath: historyPath
        )
    }

    static func copyText(for snapshot: DiagnosticsSnapshot, language: AppLanguage) -> String {
        let formatter = ISO8601DateFormatter()
        let checkedAt = snapshot.lastCheckedAt.map { formatter.string(from: $0) } ?? "never"
        let title = language.text("NetBar 诊断信息", "NetBar Diagnostics")
        let privacyLine = language.text(
            "privacy=不包含抓包内容、URL、域名、聊天内容、文件内容或载荷数据。",
            "privacy=No packet contents, URLs, domains, chat contents, file contents, or payload data are included."
        )
        return """
        \(title)
        version=\(sanitizeURL(snapshot.appVersion))
        bundleIdentifier=\(sanitizeURL(snapshot.bundleIdentifier))
        updateStatus=\(sanitizeFreeform(snapshot.updateStatus))
        lastCheckedAt=\(checkedAt)
        isRunning=\(snapshot.sampling.isRunning)
        appTrafficVisible=\(snapshot.sampling.isApplicationTrafficVisible)
        appTrafficSampling=\(snapshot.sampling.isApplicationTrafficSamplingEnabled)
        powerSave=\(snapshot.sampling.isPowerSaveModeEnabled)
        notificationAuthorization=\(sanitizeFreeform(snapshot.notificationAuthorization))
        historyStatus=\(sanitizeFreeform(snapshot.historyStatus))
        historyPath=\(sanitizeURL(snapshot.historyPath))
        \(privacyLine)
        """
    }

    private static func sanitizeURL(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"https?://\S+"#,
            with: "[redacted-url]",
            options: .regularExpression
        )
    }

    private static func sanitizeFreeform(_ text: String) -> String {
        sanitizeURL(text).replacingOccurrences(
            of: #"\b[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b"#,
            with: "[redacted-domain]",
            options: .regularExpression
        )
    }
}
