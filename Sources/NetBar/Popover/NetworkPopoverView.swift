import SwiftUI

struct NetworkPopoverView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    let openPreferences: () -> Void
    @State private var appSearchText = ""
    @State private var historyWindow: TrafficHistoryWindow = .seconds90

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeaderView(
                presentation: LivingSignalStatusPresentation.make(
                    snapshot: monitor.snapshot,
                    latestEvent: monitor.intelligenceSummary.latestEvent,
                    language: appPreferences.resolvedLanguage
                ),
                snapshot: monitor.snapshot,
                appPreferences: appPreferences
            )
                .padding(.horizontal, LivingSignalLayout.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 14)
                .layoutPriority(1)

            Divider().opacity(0.55)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    InsightStreamView(
                        summary: monitor.intelligenceSummary,
                        appPreferences: appPreferences,
                        openPreferences: openPreferences
                    )
                    .padding(.top, 16)

                    if !appPreferences.hasCompletedOnboarding {
                        FirstLaunchGuide(
                            appPreferences: appPreferences,
                            openPreferences: openPreferences,
                            completeOnboarding: appPreferences.completeOnboarding
                        )
                    } else {
                        let chartPresentation = TrafficHistoryWindowPresentation.make(
                            points: monitor.recentHistory,
                            window: historyWindow
                        )
                        TrafficPulseChartView(
                            presentation: chartPresentation,
                            selectedWindow: $historyWindow,
                            appPreferences: appPreferences
                        )
                    }

                    TodayNetworkSummaryPanel(
                        summary: monitor.intelligenceSummary,
                        appPreferences: appPreferences,
                        customCharacterStore: customCharacterStore
                    )

                    if appPreferences.networkIntelligenceSettings.isHistoryTrackingEnabled {
                        HistoryLedgerPanel(
                            presentation: NetworkHistoryPresentation.make(
                                summary: monitor.intelligenceSummary,
                                language: appPreferences.resolvedLanguage
                            ),
                            appPreferences: appPreferences
                        )
                    }

                    SummaryGrid(snapshot: monitor.snapshot, appPreferences: appPreferences)

                    ApplicationTopPanel(
                        realtimeApplications: monitor.intelligenceSummary.realtimeTopApplications,
                        todayApplications: monitor.intelligenceSummary.todayTopApplications,
                        appPreferences: appPreferences
                    )

                    ApplicationTrafficPanel(
                        snapshot: monitor.snapshot,
                        appTraffic: monitor.appTraffic,
                        preferences: appPreferences,
                        searchText: $appSearchText,
                        retry: monitor.refreshApplicationTraffic
                    )

                    SevenDaySummaryPanel(
                        summaries: monitor.intelligenceSummary.recentDays,
                        appPreferences: appPreferences
                    )

                    InterfaceAndSystemPanel(
                        snapshot: monitor.snapshot,
                        systemResources: monitor.appTraffic.systemResources,
                        appPreferences: appPreferences,
                        refresh: monitor.refresh
                    )
                }
                .padding(.horizontal, LivingSignalLayout.horizontalPadding)
                .padding(.bottom, 16)
            }
            .frame(minHeight: 0)

            Divider().opacity(0.55)

            PopoverFooterView(monitor: monitor, appPreferences: appPreferences, openPreferences: openPreferences)
                .padding(.horizontal, LivingSignalLayout.horizontalPadding)
                .padding(.vertical, 11)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(
            minWidth: LivingSignalLayout.minimumPopoverWidth,
            idealWidth: LivingSignalLayout.preferredPopoverWidth,
            maxWidth: LivingSignalLayout.preferredPopoverWidth,
            minHeight: LivingSignalLayout.minimumPopoverHeight,
            idealHeight: LivingSignalLayout.preferredPopoverHeight,
            maxHeight: .infinity
        )
        .livingSignalPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }

}

// MARK: - First Launch Guide

private struct FirstLaunchGuide: View {
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void
    let completeOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(appPreferences.text("欢迎使用 NetBar", "Welcome to NetBar"))
                        .font(.system(size: 14, weight: .bold))
                    Text(appPreferences.text(
                        "菜单栏会每秒更新网络速度；应用流量来自 macOS nettop，首次采样需要几秒。你可以在偏好设置里打开开机启动、隐藏 Dock 图标，并调整应用列表筛选。",
                        "The menu bar updates network speed every second. Application traffic comes from macOS nettop, so the first sample can take a few seconds. Preferences include launch at login, Dock visibility, and app filtering."
                    ))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button { openPreferences() } label: {
                    Label(appPreferences.text("打开偏好设置", "Open Preferences"), systemImage: "gearshape")
                }
                Button(appPreferences.text("知道了", "Got It")) { completeOnboarding() }
                    .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
        .netBarCard(cornerRadius: 14, padding: 14, isProminent: true)
    }
}
