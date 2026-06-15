import SwiftUI

struct IntelligencePreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var notificationController: NetworkNotificationController
    @ObservedObject var petController: PetController
    let clearHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                onboardingSection
                anomalySection
                notificationSection
                historySection
                petFeedbackSection
            }
            .padding(.trailing, 2)
        }
        .task {
            await notificationController.refreshAuthorizationStatus()
        }
    }

    private var onboardingSection: some View {
        Group {
            if !appPreferences.networkIntelligenceSettings.hasSeenNotificationOnboarding {
                PreferenceSection(
                    title: appPreferences.text("异常通知", "Anomaly Notifications"),
                    systemImage: "bell.badge"
                ) {
                    Text(appPreferences.text(
                        "NetBar 可以在高流量、应用突增、断流/恢复时提醒你。开启后会请求 macOS 通知权限。",
                        "NetBar can notify you about high traffic, application spikes, and network drops or recovery. macOS notification permission is requested only after you enable it."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button(appPreferences.text("开启异常通知", "Enable Notifications")) {
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

    private var anomalySection: some View {
        PreferenceSection(
            title: appPreferences.text("智能检测", "Intelligence"),
            systemImage: "sparkles"
        ) {
            Toggle(
                appPreferences.text("异常检测", "Anomaly detection"),
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

            Toggle(
                appPreferences.text("应用突增提醒", "Application spike alerts"),
                isOn: settingsBinding(\.isApplicationSpikeAlertEnabled)
            )
            Toggle(
                appPreferences.text("断流/恢复提醒", "Drop/recovery alerts"),
                isOn: settingsBinding(\.isNetworkDropAlertEnabled)
            )
            Toggle(
                appPreferences.text("代理/VPN 归因提醒", "Proxy/VPN attribution alerts"),
                isOn: settingsBinding(\.isProxyAttributionAlertEnabled)
            )
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

            Toggle(
                appPreferences.text("洞察事件流", "Insight stream"),
                isOn: settingsBinding(\.isInsightStreamEnabled)
            )

            Toggle(
                appPreferences.text("洞察建议", "Insight suggestions"),
                isOn: settingsBinding(\.isInsightSuggestionEnabled)
            )

            Toggle(
                appPreferences.text("应用累计排行", "Application ranking"),
                isOn: settingsBinding(\.isApplicationHistoryRankingEnabled)
            )

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

    private var petFeedbackSection: some View {
        PreferenceSection(
            title: appPreferences.text("宠物反馈", "Pet Feedback"),
            systemImage: "face.smiling"
        ) {
            Toggle(
                appPreferences.text("心情反馈", "Mood feedback"),
                isOn: petSettingBinding(\.isPetMoodFeedbackEnabled)
            )
            Toggle(
                appPreferences.text("活跃等级", "Activity level"),
                isOn: petSettingBinding(\.isPetActivityLevelEnabled)
            )
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

    private func petSettingBinding<Value>(
        _ keyPath: WritableKeyPath<PetSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { petController.settings[keyPath: keyPath] },
            set: { newValue in
                petController.updateSettings { settings in
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
