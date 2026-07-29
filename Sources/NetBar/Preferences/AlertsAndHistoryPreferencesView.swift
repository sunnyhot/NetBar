import SwiftUI

struct AlertsAndHistoryPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var notificationController: NetworkNotificationController
    let clearHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                alertOnboardingSection
                highTrafficAlertSection
                notificationSection
                historySection
            }
            .padding(.trailing, 2)
        }
        .task {
            await notificationController.refreshAuthorizationStatus()
        }
    }

    private var alertOnboardingSection: some View {
        Group {
            if !appPreferences.networkIntelligenceSettings.hasSeenNotificationOnboarding {
                PreferenceSection(
                    title: appPreferences.text("高流量提醒", "High Traffic Alerts"),
                    systemImage: "bell.badge"
                ) {
                    Text(appPreferences.text(
                        "当网络流量持续超过设定阈值时，NetBar 可以发送提醒。开启后会请求 macOS 通知权限。",
                        "NetBar can alert you when network traffic stays above your threshold. macOS notification permission is requested only after you enable it."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button(appPreferences.text("开启提醒", "Enable Alerts")) {
                            updateSettings {
                                $0.hasSeenNotificationOnboarding = true
                                $0.isSystemNotificationEnabled = true
                            }
                            Task { await notificationController.requestAuthorization() }
                        }
                        Button(appPreferences.text("暂不开启", "Not Now")) {
                            updateSettings {
                                $0.hasSeenNotificationOnboarding = true
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var highTrafficAlertSection: some View {
        PreferenceSection(
            title: appPreferences.text("高流量提醒", "High Traffic Alerts"),
            systemImage: "speedometer"
        ) {
            Toggle(
                appPreferences.text("检测持续高流量", "Detect sustained high traffic"),
                isOn: settingsBinding(\.isAnomalyDetectionEnabled)
            )

            Picker(
                appPreferences.text("高流量阈值", "High traffic threshold"),
                selection: settingsBinding(\.highTrafficThreshold)
            ) {
                ForEach(HighTrafficThreshold.allCases) { threshold in
                    Text(threshold.title(language: appPreferences.resolvedLanguage)).tag(threshold)
                }
            }
            .pickerStyle(.segmented)

        }
    }

    private var notificationSection: some View {
        PreferenceSection(
            title: appPreferences.text("系统通知", "System Notifications"),
            systemImage: "bell"
        ) {
            Toggle(
                appPreferences.text("发送系统通知", "Send system notifications"),
                isOn: settingsBinding(\.isSystemNotificationEnabled)
            )

            HStack {
                Text(appPreferences.text("权限状态", "Authorization"))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(notificationController.authorizationStatus.title(language: appPreferences.resolvedLanguage))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if notificationController.authorizationStatus == .notDetermined {
                Button(appPreferences.text("请求通知权限", "Request Permission")) {
                    Task { await notificationController.requestAuthorization() }
                }
            }
        }
    }

    private var historySection: some View {
        PreferenceSection(
            title: appPreferences.text("历史统计", "History"),
            systemImage: "calendar.badge.clock"
        ) {
            Toggle(
                appPreferences.text("记录今日与最近 30 天", "Track today and recent 30 days"),
                isOn: settingsBinding(\.isHistoryTrackingEnabled)
            )

            Stepper(
                value: settingsBinding(\.historyRetentionDays),
                in: 7...30,
                step: 1
            ) {
                Text(appPreferences.text(
                    "历史保留 \(appPreferences.networkIntelligenceSettings.historyRetentionDays) 天",
                    "Keep \(appPreferences.networkIntelligenceSettings.historyRetentionDays) days"
                ))
            }

            Button(appPreferences.text("清空历史数据", "Clear History"), role: .destructive) {
                clearHistory()
            }

            Text(appPreferences.text(
                "历史统计为本地估算值，用于趋势判断，不等同于运营商计费。",
                "History values are local estimates for trend awareness and are not billing-grade measurements."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingsBinding<Value>(
        _ keyPath: WritableKeyPath<NetworkIntelligenceSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                appPreferences.networkIntelligenceSettings[keyPath: keyPath]
            },
            set: { newValue in
                updateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func updateSettings(_ update: (inout NetworkIntelligenceSettings) -> Void) {
        var settings = appPreferences.networkIntelligenceSettings
        update(&settings)
        appPreferences.networkIntelligenceSettings = settings
    }
}
