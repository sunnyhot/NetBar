import Combine
import Foundation
import UserNotifications

enum NetworkNotificationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
}

extension NetworkNotificationAuthorizationStatus {
    func title(language: AppLanguage) -> String {
        switch self {
        case .notDetermined:
            return language.text("未设置", "Not set")
        case .denied:
            return language.text("已拒绝", "Denied")
        case .authorized:
            return language.text("已授权", "Authorized")
        }
    }
}

@MainActor
protocol NetworkNotificationCentering: AnyObject {
    func authorizationStatus() async -> NetworkNotificationAuthorizationStatus
    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus
    func deliver(title: String, body: String) async
}

final class UserNotificationCenterAdapter: NetworkNotificationCentering {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NetworkNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func deliver(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

@MainActor
final class NetworkNotificationController: ObservableObject {
    @Published private(set) var authorizationStatus: NetworkNotificationAuthorizationStatus = .notDetermined

    private let center: NetworkNotificationCentering
    private let now: () -> Date
    private var lastDeliveredAtByKey: [String: Date] = [:]

    init(
        center: NetworkNotificationCentering,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.now = now
    }

    convenience init(now: @escaping () -> Date = Date.init) {
        self.init(center: UserNotificationCenterAdapter(), now: now)
    }

    @discardableResult
    func refreshAuthorizationStatus() async -> NetworkNotificationAuthorizationStatus {
        let status = await center.authorizationStatus()
        authorizationStatus = status
        return status
    }

    @discardableResult
    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus {
        let status = await center.requestAuthorization()
        authorizationStatus = status
        return status
    }

    @discardableResult
    func handle(
        _ event: NetworkAnomalyEvent,
        settings: NetworkIntelligenceSettings
    ) async -> Bool {
        guard shouldDeliver(event, settings: settings) else { return false }
        await center.deliver(title: event.title, body: event.message)
        return true
    }

    private func shouldDeliver(
        _ event: NetworkAnomalyEvent,
        settings: NetworkIntelligenceSettings
    ) -> Bool {
        guard settings.isSystemNotificationEnabled else { return false }
        guard settings.isEnabled(for: event.kind) else { return false }
        guard authorizationStatus == .authorized else { return false }

        let currentDate = now()
        let cooldown = cooldownSeconds(for: event.kind)
        if let lastDeliveredAt = lastDeliveredAtByKey[event.cooldownKey],
           currentDate.timeIntervalSince(lastDeliveredAt) < cooldown {
            return false
        }

        lastDeliveredAtByKey[event.cooldownKey] = currentDate
        return true
    }

    private func cooldownSeconds(for kind: NetworkAnomalyKind) -> TimeInterval {
        switch kind {
        case .highTraffic, .applicationSpike:
            return 10 * 60
        case .networkDrop, .networkRecovered:
            return 3 * 60
        case .proxyAttributionGap:
            return 15 * 60
        }
    }
}

extension NetworkIntelligenceSettings {
    func isEnabled(for kind: NetworkAnomalyKind) -> Bool {
        guard isAnomalyDetectionEnabled else { return false }

        switch kind {
        case .highTraffic:
            return true
        case .applicationSpike:
            return isApplicationSpikeAlertEnabled
        case .networkDrop, .networkRecovered:
            return isNetworkDropAlertEnabled
        case .proxyAttributionGap:
            return isProxyAttributionAlertEnabled
        }
    }
}
