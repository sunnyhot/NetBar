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
            HeaderView(snapshot: monitor.snapshot, appPreferences: appPreferences)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)
                .layoutPriority(1)

            Divider().opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NetworkIntelligenceStatusCard(
                        presentation: NetworkIntelligenceStatusPresentation(
                            event: monitor.intelligenceSummary.latestEvent,
                            language: appPreferences.resolvedLanguage
                        ),
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
                        TrafficChart(
                            points: historyWindow.points(from: monitor.recentHistory),
                            selectedWindow: $historyWindow,
                            appPreferences: appPreferences
                        )
                            .frame(height: 132)
                    }

                    TodayNetworkSummary(
                        summary: monitor.intelligenceSummary,
                        appPreferences: appPreferences,
                        customCharacterStore: customCharacterStore
                    )

                    SummaryGrid(snapshot: monitor.snapshot, appPreferences: appPreferences)

                    ApplicationTopSection(
                        realtimeApplications: monitor.intelligenceSummary.realtimeTopApplications,
                        todayApplications: monitor.intelligenceSummary.todayTopApplications,
                        appPreferences: appPreferences
                    )

                    ApplicationTrafficList(
                        snapshot: monitor.snapshot,
                        appTraffic: monitor.appTraffic,
                        preferences: appPreferences,
                        searchText: $appSearchText,
                        retry: monitor.refreshApplicationTraffic
                    )

                    SevenDaySummarySection(
                        summaries: monitor.intelligenceSummary.recentDays,
                        appPreferences: appPreferences
                    )

                    InterfaceList(
                        interfaces: monitor.snapshot.interfaces,
                        appPreferences: appPreferences,
                        refresh: monitor.refresh
                    )
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .frame(minHeight: 0)

            Divider().opacity(0.55)

            FooterView(monitor: monitor, appPreferences: appPreferences, openPreferences: openPreferences)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(minWidth: 440, idealWidth: 440, maxWidth: 440, minHeight: 500, idealHeight: 720, maxHeight: .infinity)
        .netBarPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }
}

// MARK: - Header

private struct HeaderView: View {
    let snapshot: NetworkSnapshot
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NetBar")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(appPreferences.text("实时网络仪表盘", "Realtime Network Console"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    NetBarBadge(text: appPreferences.text("实时", "Live"), tone: .success)
                    Text(snapshot.timestamp, style: .time)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                SpeedTile(
                    title: appPreferences.text("下载", "Download"),
                    value: ByteFormat.speed(snapshot.downloadBytesPerSecond),
                    tone: .download,
                    symbol: "arrow.down"
                )
                SpeedTile(
                    title: appPreferences.text("上传", "Upload"),
                    value: ByteFormat.speed(snapshot.uploadBytesPerSecond),
                    tone: .upload,
                    symbol: "arrow.up"
                )
            }

            Text(appPreferences.text("接口级总速度，可能与应用级汇总存在差异", "Interface-level totals; may differ from app-level summary"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

// MARK: - Network Intelligence

enum NetworkIntelligenceTone: Equatable {
    case normal
    case attention
    case critical
}

struct NetworkIntelligenceStatusPresentation: Equatable {
    let title: String
    let message: String
    let tone: NetworkIntelligenceTone
    let symbolName: String

    init(event: NetworkAnomalyEvent?, language: AppLanguage) {
        guard let event else {
            title = language.text("网络状态正常", "Network status normal")
            message = language.text("没有检测到需要注意的网络异常。", "No network anomalies need attention.")
            tone = .normal
            symbolName = "checkmark.seal.fill"
            return
        }

        title = event.title
        message = event.message
        switch event.severity {
        case .info:
            tone = .normal
            symbolName = "info.circle.fill"
        case .warning:
            tone = .attention
            symbolName = "exclamationmark.circle.fill"
        case .critical:
            tone = .critical
            symbolName = "exclamationmark.triangle.fill"
        }
    }
}

struct NetworkDailySummaryCard: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
}

enum NetworkDailySummaryPresentation {
    static func cards(
        for summary: NetworkIntelligenceSummary,
        language: AppLanguage,
        customCharacters: [CustomCharacter] = []
    ) -> [NetworkDailySummaryCard] {
        let today = summary.today
        return [
            NetworkDailySummaryCard(
                id: "down",
                title: language.text("今日下载", "Today Down"),
                value: ByteFormat.bytes(today.downloadBytes)
            ),
            NetworkDailySummaryCard(
                id: "up",
                title: language.text("今日上传", "Today Up"),
                value: ByteFormat.bytes(today.uploadBytes)
            ),
            NetworkDailySummaryCard(
                id: "peak",
                title: language.text("今日峰值", "Peak"),
                value: ByteFormat.speed(max(today.peakDownloadBytesPerSecond, today.peakUploadBytesPerSecond))
            ),
            NetworkDailySummaryCard(
                id: "active",
                title: language.text("活跃时长", "Active"),
                value: duration(today.activeSeconds)
            ),
            NetworkDailySummaryCard(
                id: "animation",
                title: language.text("动画播放", "Anim Plays"),
                value: CharacterPlaybackPresentation.playCountText(
                    today.animationPlaybackCount,
                    language: language
                )
            ),
            NetworkDailySummaryCard(
                id: "favoriteCharacter",
                title: language.text("最爱英雄", "Favorite Hero"),
                value: CharacterPlaybackPresentation.favoriteText(
                    for: summary,
                    customCharacters: customCharacters,
                    language: language
                )
            )
        ]
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct NetworkIntelligenceStatusCard: View {
    let presentation: NetworkIntelligenceStatusPresentation
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                Text(presentation.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button { openPreferences() } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(NetBarIconButtonStyle())
            .help(appPreferences.text("调整智能检测", "Adjust Intelligence"))
        }
        .netBarCard(cornerRadius: 12, padding: 11, isProminent: presentation.tone != .normal)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 0.7)
        )
    }

    private var tint: Color {
        switch presentation.tone {
        case .normal:
            return .green
        case .attention:
            return .orange
        case .critical:
            return .red
        }
    }
}

private struct TodayNetworkSummary: View {
    let summary: NetworkIntelligenceSummary
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore

    private var cards: [NetworkDailySummaryCard] {
        NetworkDailySummaryPresentation.cards(
            for: summary,
            language: appPreferences.resolvedLanguage,
            customCharacters: customCharacterStore.characters
        )
    }

    private let columns = [
        GridItem(.flexible(minimum: 96), spacing: 8),
        GridItem(.flexible(minimum: 96), spacing: 8),
        GridItem(.flexible(minimum: 96), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("今日统计", "Today"),
                subtitle: appPreferences.text("本地累计估算", "Local estimate")
            )

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cards) { card in
                    DailySummaryCell(card: card, tone: tone(for: card.id))
                }
            }
        }
    }

    private func tone(for id: String) -> NetBarTone {
        switch id {
        case "down":
            return .download
        case "up":
            return .upload
        case "peak":
            return .warning
        case "favoriteCharacter":
            return .success
        default:
            return .neutral
        }
    }
}

private struct DailySummaryCell: View {
    let card: NetworkDailySummaryCard
    let tone: NetBarTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Text(card.value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .netBarCard(cornerRadius: 10, padding: 9)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tone.color.opacity(0.12), lineWidth: 0.6)
        )
    }
}

private struct ApplicationTopSection: View {
    let realtimeApplications: [ApplicationTrafficRate]
    let todayApplications: [ApplicationDailyUsage]
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        if !realtimeApplications.isEmpty || !todayApplications.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                NetBarSectionHeader(
                    title: appPreferences.text("应用 Top", "App Top"),
                    subtitle: appPreferences.text("实时活跃与今日累计", "Realtime and today")
                )

                if !realtimeApplications.isEmpty {
                    TopSubsectionTitle(title: appPreferences.text("当前最活跃", "Most Active Now"))
                    VStack(spacing: 4) {
                        ForEach(Array(realtimeApplications.prefix(3))) { application in
                            ApplicationTrafficRow(
                                application: application,
                                role: ApplicationTrafficPresentation.attributionRole(for: application),
                                language: appPreferences.resolvedLanguage,
                                displayMode: .activity
                            )
                        }
                    }
                }

                if !todayApplications.isEmpty {
                    TopSubsectionTitle(title: appPreferences.text("今日累计", "Today Total"))
                    VStack(spacing: 4) {
                        ForEach(Array(todayApplications.prefix(5))) { application in
                            DailyApplicationUsageRow(
                                application: application,
                                language: appPreferences.resolvedLanguage
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct TopSubsectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
    }
}

private struct DailyApplicationUsageRow: View {
    let application: ApplicationDailyUsage
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 8) {
            AppBadge(title: application.displayName, pids: [])

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(application.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    AttributionRoleBadge(role: application.role, language: language)
                }
                Text(application.processNames.prefix(2).joined(separator: ", "))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                MetricPill(symbol: "arrow.down", value: ByteFormat.bytes(application.downloadBytes), tint: .blue, fixedWidth: 92)
                MetricPill(symbol: "arrow.up", value: ByteFormat.bytes(application.uploadBytes), tint: .orange, fixedWidth: 92)
            }
        }
        .netBarCard(cornerRadius: 10, padding: 6)
    }
}

private struct SevenDaySummarySection: View {
    let summaries: [NetworkDailySummary]
    @ObservedObject var appPreferences: AppPreferences

    private var visibleSummaries: [NetworkDailySummary] {
        Array(summaries.suffix(7).reversed())
    }

    var body: some View {
        if !visibleSummaries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                NetBarSectionHeader(
                    title: appPreferences.text("最近 7 天", "Recent 7 Days"),
                    subtitle: appPreferences.text("按日期查看累计流量", "Daily accumulated traffic")
                )

                VStack(spacing: 4) {
                    ForEach(visibleSummaries) { summary in
                        SevenDaySummaryRow(summary: summary)
                    }
                }
            }
        }
    }
}

private struct SevenDaySummaryRow: View {
    let summary: NetworkDailySummary

    var body: some View {
        HStack(spacing: 8) {
            Text(summary.dateKey)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            MetricPill(symbol: "arrow.down", value: ByteFormat.bytes(summary.downloadBytes), tint: .blue)
            MetricPill(symbol: "arrow.up", value: ByteFormat.bytes(summary.uploadBytes), tint: .orange)
            CompactMetric(symbol: "clock", value: NetworkDailySummaryPresentation.duration(summary.activeSeconds), tint: .secondary)
        }
        .netBarCard(cornerRadius: 10, padding: 7)
    }
}

// MARK: - Speed Tile

private struct SpeedTile: View {
    let title: String
    let value: String
    let tone: NetBarTone
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            NetBarIconTile(systemName: symbol, tone: tone, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .animation(NetBarMotion.quick, value: value)
                ActivityLevelBars(tone: tone)
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .netBarCard(cornerRadius: 14, padding: 12, isProminent: true)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tone.color.opacity(0.12), lineWidth: 0.7))
    }
}

private struct ActivityLevelBars: View {
    let tone: NetBarTone

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(tone.color.opacity(0.18 + Double(index) * 0.055))
                    .frame(width: 8, height: CGFloat(3 + index % 4 * 2))
            }
        }
    }
}

// MARK: - Summary Grid

private struct SummaryGrid: View {
    let snapshot: NetworkSnapshot
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        HStack(spacing: 10) {
            SummaryCell(
                title: appPreferences.text("总下载", "Total Down"),
                value: ByteFormat.bytes(snapshot.totalReceivedBytes),
                tone: .download
            )
            SummaryCell(
                title: appPreferences.text("总上传", "Total Up"),
                value: ByteFormat.bytes(snapshot.totalSentBytes),
                tone: .upload
            )
            SummaryCell(
                title: appPreferences.text("接口", "Ifaces"),
                value: "\(snapshot.interfaces.count)",
                tone: .neutral
            )
            SummaryCell(
                title: appPreferences.text("采样", "Samples"),
                value: "\(snapshot.sampleCount)",
                tone: .neutral
            )
        }
    }
}

private struct SummaryCell: View {
    let title: String
    let value: String
    let tone: NetBarTone

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tone.color.opacity(tone == .neutral ? 0.22 : 0.75))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .netBarCard(cornerRadius: 11, padding: 10)
    }
}

// MARK: - Application Traffic List

private struct ApplicationTrafficList: View {
    let snapshot: NetworkSnapshot
    let appTraffic: ApplicationTrafficState
    @ObservedObject var preferences: AppPreferences
    @Binding var searchText: String
    let retry: () -> Void

    private var visibleApplications: [ApplicationTrafficRate] {
        ApplicationTrafficPresentation.visibleApplications(
            from: appTraffic,
            preferences: preferences,
            searchText: searchText
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NetBarSectionHeader(
                title: preferences.text("应用流量", "Application Traffic"),
                subtitle: preferences.text("按实时网络活动排序和筛选", "Sorted and filtered by realtime activity"),
                trailing: appTraffic.timestamp.map { "\(preferences.text("更新", "Updated")) \($0.formatted(date: .omitted, time: .shortened))" }
            )

            if let errorMessage = appTraffic.errorMessage {
                AppTrafficNotice(
                    symbol: "exclamationmark.triangle",
                    title: preferences.text("无法读取应用流量", "Unable to Read Application Traffic"),
                    message: "\(errorMessage)\n\(preferences.text("可重试读取；如果仍失败，请确认系统自带 nettop 可运行。", "Try again. If it still fails, confirm that the built-in nettop command can run."))",
                    actionTitle: preferences.text("重试", "Retry"),
                    action: retry
                )
            } else {
                // Sort & search controls — always visible in the detail popup
                AppTrafficControls(
                    preferences: preferences,
                    searchText: $searchText,
                    appTraffic: appTraffic
                )

                if appTraffic.sampleCount > 0 {
                    AppTrafficAttributionCard(
                        summary: ApplicationTrafficPresentation.attributionSummary(
                            snapshot: snapshot,
                            applications: appTraffic.applications
                        ),
                        preferences: preferences,
                        sampleCount: appTraffic.sampleCount,
                        applicationCount: visibleApplications.count
                    )
                }

                if !visibleApplications.isEmpty {
                    let summaryMetrics = ApplicationTrafficPresentation.summaryMetrics(
                        for: visibleApplications,
                        displayMode: preferences.applicationSort
                    )

                    HStack(spacing: 8) {
                        Text(preferences.text("应用级汇总", "App-level Total"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)

                        Spacer()

                        HStack(spacing: 8) {
                            ForEach(summaryMetrics) { metric in
                                CompactMetric(metric: metric)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }

                // System resource summary card
                let sys = appTraffic.systemResources
                if sys.totalMemory > 0 {
                    SystemResourceCard(
                        summary: sys,
                        appPreferences: preferences
                    )
                }

                if visibleApplications.isEmpty {
                    AppTrafficNotice(
                        symbol: isInitialLoading ? "arrow.triangle.2.circlepath" : "line.3.horizontal.decrease.circle",
                        title: isInitialLoading ? preferences.text("正在读取应用流量", "Reading Application Traffic") : emptyTitle,
                        message: emptyMessage
                    )
                } else {
                    VStack(spacing: 4) {
                        ForEach(visibleApplications) { application in
                            ApplicationTrafficRow(
                                application: application,
                                role: ApplicationTrafficPresentation.attributionRole(for: application),
                                language: preferences.resolvedLanguage,
                                displayMode: preferences.applicationSort
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? preferences.text("暂无应用流量", "No Application Traffic Yet")
            : preferences.text("没有匹配的应用", "No Matching Apps")
    }

    private var isInitialLoading: Bool {
        appTraffic.isRefreshing && appTraffic.sampleCount == 0
    }


    /// Always show controls (search + sort picker) when:
    /// - there is application data, OR
    /// - user is searching, OR
    /// - initial loading is done (so the sort picker is always accessible after startup).
    /// This ensures the sort picker is never hidden after the first load,
    /// so users can always switch between traffic/memory/CPU sort modes.
    private var shouldShowControls: Bool {
        !appTraffic.applications.isEmpty
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !appTraffic.isRefreshing && appTraffic.errorMessage == nil
    }

    private var emptyMessage: String {
        if isInitialLoading {
            return preferences.text(
                "应用级数据来自 macOS nettop，首次采样后会显示实时速率。",
                "Application-level data comes from macOS nettop. Live rates appear after the first sample."
            )
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return preferences.text(
                "请调整搜索关键字，或在偏好设置里关闭隐藏系统进程。",
                "Adjust the search term, or disable hidden system processes in Preferences."
            )
        }
        return preferences.text(
            "保持 NetBar 运行几秒后会显示有网络活动的应用。代理或 VPN 可能会把流量归到代理进程下。",
            "Keep NetBar running for a few seconds to show apps with network activity. Proxies and VPNs may attribute traffic to the proxy process."
        )
    }
}

private struct AppTrafficAttributionCard: View {
    let summary: ApplicationAttributionSummary
    @ObservedObject var preferences: AppPreferences
    let sampleCount: Int
    let applicationCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .netBarCard(cornerRadius: 11, padding: 9)
    }

    private var title: String {
        guard let coverage = summary.coveragePercentage else {
            return preferences.text("归因待采样", "Attribution pending")
        }
        return "\(preferences.text("应用级归因", "App attribution")) \(coverage)%"
    }

    private var detail: String {
        "\(preferences.text("接口", "Interface")) \(ByteFormat.speed(summary.interfaceBytesPerSecond)) · \(preferences.text("应用", "Apps")) \(ByteFormat.speed(summary.applicationBytesPerSecond))"
    }

    private var message: String {
        var parts: [String] = []
        if summary.status == .partial {
            parts.append(preferences.text("总流量与应用汇总存在差异", "Interface and app totals differ"))
        }
        if let proxy = summary.proxyCandidateNames.first {
            parts.append(preferences.text("代理/VPN：\(proxy)", "Proxy/VPN: \(proxy)"))
        } else if let helper = summary.helperCandidateNames.first {
            parts.append(preferences.text("子进程：\(helper)", "Helper: \(helper)"))
        }
        parts.append("\(preferences.text("采样", "Samples")) \(sampleCount) · \(preferences.text("应用行", "Rows")) \(applicationCount)")
        return parts.joined(separator: " · ")
    }

    private var symbol: String {
        switch summary.status {
        case .idle:
            return "circle.dotted"
        case .covered:
            return "checkmark.seal"
        case .partial:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    private var tint: Color {
        switch summary.status {
        case .idle:
            return .secondary
        case .covered:
            return .green
        case .partial:
            return .orange
        }
    }
}

// MARK: - Application Traffic Controls (always visible)

private struct AppTrafficControls: View {
    @ObservedObject var preferences: AppPreferences
    @Binding var searchText: String
    let appTraffic: ApplicationTrafficState

    var body: some View {
        HStack(spacing: 8) {
            TextField(preferences.text("搜索应用或进程", "Search apps or processes"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Menu {
                ForEach(ApplicationSortMode.displayModes) { sortMode in
                    Button {
                        preferences.applicationSort = sortMode
                    } label: {
                        HStack {
                            Text(sortMode.title(language: preferences.resolvedLanguage))
                            if preferences.applicationSort == sortMode {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text(preferences.applicationSort.title(language: preferences.resolvedLanguage))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
            }
            .fixedSize()
        }
        .netBarCard(cornerRadius: 11, padding: 8)
    }
}

private struct AppTrafficNotice: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .netBarCard(cornerRadius: 12, padding: 12)
    }
}

private struct ApplicationTrafficRow: View {
    let application: ApplicationTrafficRate
    let role: ApplicationAttributionRole
    let language: AppLanguage
    let displayMode: ApplicationSortMode
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            AppBadge(title: application.displayName, pids: application.pids)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(application.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    AttributionRoleBadge(role: role, language: language)
                }

                Text(detailSubtitle)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(ApplicationTrafficPresentation.rowMetrics(for: application, displayMode: displayMode)) { metric in
                    CompactMetric(metric: metric)
                }
            }
        }
        .netBarCard(cornerRadius: 10, padding: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.12 : 0.0), lineWidth: 0.5)
        )
        .animation(NetBarMotion.quick, value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var detailSubtitle: String {
        let processNames = application.processNames.prefix(2).joined(separator: ", ")
        guard !application.processLabel.isEmpty else {
            return processNames
        }
        guard !processNames.isEmpty else {
            return "PID \(application.processLabel)"
        }
        return "\(processNames)  PID \(application.processLabel)"
    }
}

private struct AttributionRoleBadge: View {
    let role: ApplicationAttributionRole
    let language: AppLanguage

    var body: some View {
        Text(role.title(language: language))
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(tint.opacity(0.1), in: Capsule())
            .lineLimit(1)
            .fixedSize()
    }

    private var tint: Color {
        switch role {
        case .application:
            return .secondary
        case .proxyOrVPN:
            return .orange
        case .helper:
            return .blue
        case .systemService:
            return .gray
        }
    }
}

private struct CompactMetric: View {
    let symbol: String
    let value: String
    let tint: Color

    init(symbol: String, value: String, tint: Color) {
        self.symbol = symbol
        self.value = value
        self.tint = tint
    }

    init(metric: ApplicationTrafficMetric) {
        self.symbol = metric.symbol
        self.value = metric.value
        self.tint = metric.tint
    }

    var body: some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minWidth: 72, alignment: .trailing)
    }
}

private extension ApplicationTrafficMetric {
    var symbol: String {
        switch kind {
        case .download: return "arrow.down"
        case .upload: return "arrow.up"
        case .memory: return "memorychip"
        case .cpu: return "cpu"
        }
    }

    var tint: Color {
        switch kind {
        case .download: return .blue
        case .upload: return .orange
        case .memory: return .purple
        case .cpu: return .red
        }
    }
}

private let appIconCache = NSCache<NSNumber, NSImage>()

private struct AppBadge: View {
    let title: String
    let pids: [Int32]

    private var appIcon: NSImage? {
        for pid in pids {
            let key = NSNumber(value: pid)
            if let cached = appIconCache.object(forKey: key) {
                return cached
            }
            if let app = NSRunningApplication(processIdentifier: pid),
               let icon = app.icon {
                appIconCache.setObject(icon, forKey: key)
                return icon
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text(initial)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(nsColor: .controlAccentColor), Color(nsColor: .controlAccentColor).opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var initial: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }
}

// MARK: - Interface List

private struct InterfaceList: View {
    let interfaces: [InterfaceRate]
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    private var activeInterfaces: [InterfaceRate] {
        interfaces.filter(\.hasTraffic)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("接口明细", "Interfaces"),
                subtitle: appPreferences.text("活动接口与累计包量", "Active interfaces and cumulative packets")
            )

            if activeInterfaces.isEmpty {
                EmptyInterfacesView(
                    hasKnownInterfaces: !interfaces.isEmpty,
                    appPreferences: appPreferences,
                    refresh: refresh
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(activeInterfaces) { item in
                        InterfaceRow(interface: item)
                    }
                }
            }
        }
    }
}

private struct EmptyInterfacesView: View {
    let hasKnownInterfaces: Bool
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button { refresh() } label: {
                Label(appPreferences.text("重新读取接口", "Read Interfaces Again"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .netBarCard(cornerRadius: 12, padding: 12)
    }

    private var title: String {
        hasKnownInterfaces
            ? appPreferences.text("暂无活动接口", "No Active Interfaces")
            : appPreferences.text("暂无网络接口", "No Network Interfaces")
    }

    private var message: String {
        hasKnownInterfaces
            ? appPreferences.text("检测到流量后会自动显示。", "Interfaces appear when traffic is detected.")
            : appPreferences.text("请确认网络连接可用。", "Check that a network connection is available.")
    }
}

private struct InterfaceRow: View {
    let interface: InterfaceRate
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: InterfacePresentation.iconName(for: interface.name))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(interface.isPrimary ? Color.blue : Color.secondary)
                    .frame(width: 18)

                Text(interface.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)

                if interface.isPrimary {
                    NetBarBadge(text: "主接口", tone: .download)
                }

                Spacer()

                Text(interface.name)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                MetricPill(symbol: "arrow.down", value: ByteFormat.speed(interface.downloadBytesPerSecond), tint: .blue)
                MetricPill(symbol: "arrow.up", value: ByteFormat.speed(interface.uploadBytesPerSecond), tint: .orange)
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("接收")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormat.bytes(interface.totalReceivedBytes))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .center, spacing: 1) {
                    Text("入包")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.quaternary)
                    Text(ByteFormat.packets(interface.receivedPackets))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("发送")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormat.bytes(interface.totalSentBytes))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("出包")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.quaternary)
                    Text(ByteFormat.packets(interface.sentPackets))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .netBarCard(cornerRadius: 12, padding: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.12 : 0.0), lineWidth: 0.7)
        )
        .animation(NetBarMotion.quick, value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - System Resource Card

private struct SystemResourceCard: View {
    let summary: SystemResourceSummary
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        HStack(spacing: 12) {
            // Memory usage
            HStack(spacing: 8) {
                NetBarIconTile(systemName: "memorychip", tone: .purple, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appPreferences.text("内存", "Memory"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 4) {
                        Text(ByteFormat.bytes(Double(summary.usedMemory)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let pct = summary.memoryUsagePercentage {
                            Text(String(format: "%.0f%%", pct))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    // Memory bar
                    GeometryReader { geo in
                        let pct = summary.memoryUsagePercentage ?? 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.06))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple.opacity(0.45))
                                .frame(width: geo.size.width * min(pct / 100.0, 1.0))
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // CPU usage
            HStack(spacing: 8) {
                NetBarIconTile(systemName: "cpu", tone: .danger, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                    if let cpu = summary.cpuUsage {
                        Text(String(format: "%.1f%%", cpu))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.primary.opacity(0.06))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange.opacity(0.45))
                                    .frame(width: geo.size.width * min(cpu / 100.0, 1.0))
                            }
                        }
                        .frame(height: 4)
                    } else {
                        Text("--")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Spacer().frame(height: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Process count
            VStack(alignment: .center, spacing: 2) {
                Text(appPreferences.text("进程", "Procs"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text("\(summary.processCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52)
        }
        .netBarCard(cornerRadius: 12, padding: 10)
    }
}

// MARK: - Metric Pill

private struct MetricPill: View {
    let symbol: String
    let value: String
    let tint: Color
    var fixedWidth: CGFloat? = nil

    var body: some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: fixedWidth)
            .frame(maxWidth: fixedWidth == nil ? .infinity : fixedWidth)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.08)))
            )
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - Footer

private struct FooterView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(monitor.isRunning ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(
                    monitor.isRunning
                        ? appPreferences.text("实时监控中", "Monitoring")
                        : appPreferences.text("已暂停", "Paused")
                )
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button { openPreferences() } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(NetBarIconButtonStyle())
                .help(appPreferences.text("偏好设置", "Preferences"))

                Button {
                    monitor.refresh()
                    monitor.refreshApplicationTraffic()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(NetBarIconButtonStyle())
                .help(appPreferences.text("立即刷新", "Refresh Now"))

                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(NetBarIconButtonStyle(tone: .warning))
                .help(appPreferences.text("退出 NetBar", "Quit NetBar"))
            }
        }
    }
}

// MARK: - Traffic Chart

private struct TrafficChart: View {
    let points: [RatePoint]
    @Binding var selectedWindow: TrafficHistoryWindow
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appPreferences.text("最近 \(selectedWindow.title(language: appPreferences.resolvedLanguage))", "Last \(selectedWindow.title(language: appPreferences.resolvedLanguage))"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(appPreferences.text("下载 / 上传实时趋势", "Download / upload trend"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Picker("", selection: $selectedWindow) {
                    ForEach(TrafficHistoryWindow.allCases) { window in
                        Text(window.title(language: appPreferences.resolvedLanguage)).tag(window)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                    chartGrid
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            LegendDot(title: appPreferences.text("下载", "Down"), color: .blue)
                            LegendDot(title: appPreferences.text("上传", "Up"), color: .orange)
                            Text("\(points.count) pts")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }

                    ChartLine(
                        points: points.map(\.uploadBytesPerSecond),
                        size: geometry.size,
                        color: .orange
                    )
                    ChartLine(
                        points: points.map(\.downloadBytesPerSecond),
                        size: geometry.size,
                        color: .blue
                    )
                }
            }
        }
        .netBarCard(cornerRadius: 14, padding: 12, isProminent: true)
    }

    private var chartGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.primary.opacity(0.055))
                    .frame(height: 0.5)
                Spacer()
            }
            Rectangle()
                .fill(Color.primary.opacity(0.055))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

private struct LegendDot: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ChartLine: View {
    let points: [Double]
    let size: CGSize
    let color: Color

    var body: some View {
        ZStack {
            filledPath
                .fill(LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            linePath
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var linePath: Path {
        Path { path in
            guard points.count > 1 else { return }
            let maxValue = max(points.max() ?? 1, 1)
            let step = size.width / CGFloat(points.count - 1)
            for i in points.indices {
                let x = CGFloat(i) * step
                let y = size.height - (CGFloat(points[i] / maxValue) * (size.height - 12)) - 6
                if i == points.startIndex { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }

    private var filledPath: Path {
        Path { path in
            guard points.count > 1 else { return }
            let maxValue = max(points.max() ?? 1, 1)
            let step = size.width / CGFloat(points.count - 1)
            for i in points.indices {
                let x = CGFloat(i) * step
                let y = size.height - (CGFloat(points[i] / maxValue) * (size.height - 12)) - 6
                if i == points.startIndex { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.addLine(to: CGPoint(x: CGFloat(points.count - 1) * step, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }
}
