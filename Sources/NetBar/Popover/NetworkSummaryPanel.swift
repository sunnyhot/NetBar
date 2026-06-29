import SwiftUI

struct NetworkDailySummaryCard: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let milestone: CharacterPlaybackMilestone?

    init(
        id: String,
        title: String,
        value: String,
        milestone: CharacterPlaybackMilestone? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.milestone = milestone
    }
}

enum CharacterPlaybackMilestone: Equatable {
    case spark
    case volt
    case crown
    case legend

    init?(count: UInt64) {
        switch count {
        case 1_000_000...:
            self = .legend
        case 500_000...:
            self = .crown
        case 100_000...:
            self = .volt
        case 50_000...:
            self = .spark
        default:
            return nil
        }
    }

    var symbolName: String {
        switch self {
        case .spark:
            return "sparkles"
        case .volt:
            return "bolt.fill"
        case .crown:
            return "crown.fill"
        case .legend:
            return "star.circle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .spark:
            return .mint
        case .volt:
            return .cyan
        case .crown:
            return .orange
        case .legend:
            return .pink
        }
    }

    var backgroundGradient: LinearGradient {
        switch self {
        case .spark:
            return LinearGradient(
                colors: [Color.mint.opacity(0.18), Color.green.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .volt:
            return LinearGradient(
                colors: [Color.cyan.opacity(0.2), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .crown:
            return LinearGradient(
                colors: [Color.orange.opacity(0.22), Color.yellow.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .legend:
            return LinearGradient(
                colors: [Color.pink.opacity(0.2), Color.orange.opacity(0.14), Color.mint.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var strokeGradient: LinearGradient {
        switch self {
        case .spark:
            return LinearGradient(colors: [.mint, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .volt:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .crown:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legend:
            return LinearGradient(colors: [.pink, .orange, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .spark:
            return 5
        case .volt:
            return 7
        case .crown:
            return 9
        case .legend:
            return 11
        }
    }

    var glowOpacity: Double {
        switch self {
        case .spark:
            return 0.18
        case .volt:
            return 0.24
        case .crown:
            return 0.3
        case .legend:
            return 0.38
        }
    }
}

enum NetworkDailySummaryPresentation {
    static func cards(
        for summary: NetworkIntelligenceSummary,
        language: AppLanguage,
        customCharacters: [CustomCharacter] = []
    ) -> [NetworkDailySummaryCard] {
        let today = summary.today
        let favoriteCount = summary.favoriteAnimationCharacterID
            .flatMap { summary.animationPlaybackCountsByCharacter[$0] } ?? 0
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
                ),
                milestone: CharacterPlaybackMilestone(count: favoriteCount)
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

struct TodayNetworkSummaryPanel: View {
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

struct HistoryLedgerPanel: View {
    let presentation: NetworkHistoryPresentationModel
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("历史账本", "Traffic Ledger"),
                subtitle: appPreferences.text("本地累计趋势", "Local accumulated trends")
            )

            HStack(spacing: 8) {
                historyMetricCard(
                    title: appPreferences.text("今日", "Today"),
                    value: ByteFormat.bytes(presentation.today.totalBytes)
                )
                historyMetricCard(
                    title: presentation.sevenDay.title,
                    value: ByteFormat.bytes(presentation.sevenDay.totalBytes)
                )
                historyMetricCard(
                    title: presentation.thirtyDay.title,
                    value: ByteFormat.bytes(presentation.thirtyDay.totalBytes)
                )
            }

            if let peak = presentation.peakDownload {
                Text("\(appPreferences.text("峰值下载", "Peak download")) \(peak.dateKey): \(ByteFormat.speed(peak.downloadBytesPerSecond))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if appPreferences.networkIntelligenceSettings.isApplicationHistoryRankingEnabled {
                applicationRanking
            }

            Text(presentation.estimateNotice)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .livingSignalPanel(tone: .neutral, padding: 12)
    }

    @ViewBuilder
    private var applicationRanking: some View {
        if presentation.applicationRanking.isEmpty {
            Text(appPreferences.text("暂无应用累计排行。", "No application ranking yet."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 5) {
                ForEach(Array(presentation.applicationRanking.prefix(5))) { app in
                    HStack {
                        Text(app.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(ByteFormat.bytes(app.totalBytes))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func historyMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .livingSignalPanel(tone: .neutral, padding: 8)
    }
}

private struct DailySummaryCell: View {
    let card: NetworkDailySummaryCard
    let tone: NetBarTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(card.title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let milestone = card.milestone {
                    Image(systemName: milestone.symbolName)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(milestone.strokeGradient)
                        .shadow(
                            color: milestone.accent.opacity(0.24),
                            radius: 3,
                            x: 0,
                            y: 0
                        )
                        .accessibilityHidden(true)
                }
            }

            Text(card.value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .netBarCard(cornerRadius: 10, padding: 9)
        .overlay {
            if let milestone = card.milestone {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(milestone.backgroundGradient)
                    .opacity(0.56)
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            summaryStroke
        )
        .shadow(
            color: card.milestone?.accent.opacity(0.12) ?? .clear,
            radius: card.milestone == nil ? 0 : 4,
            x: 0,
            y: 0
        )
    }

    @ViewBuilder
    private var summaryStroke: some View {
        if let milestone = card.milestone {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(milestone.strokeGradient, lineWidth: 1.05)
                .opacity(0.56)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tone.color.opacity(0.12), lineWidth: 0.6)
        }
    }
}

struct ApplicationTopPanel: View {
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
            AppBadge(title: application.displayName)

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

struct SevenDaySummaryPanel: View {
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

struct SummaryGrid: View {
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
