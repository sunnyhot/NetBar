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
            return LivingSignalTone.active.color
        case .volt:
            return LivingSignalTone.active.color.opacity(0.9)
        case .crown:
            return LivingSignalTone.attention.color
        case .legend:
            return LivingSignalTone.uploadHeavy.color
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.11), accent.opacity(0.035)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var strokeGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.84), accent.opacity(0.36)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        .livingSignalRow(tone: livingTone, padding: 9)
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

    private var livingTone: LivingSignalTone {
        switch tone {
        case .upload:
            return .uploadHeavy
        case .warning:
            return .attention
        case .danger:
            return .critical
        default:
            return .neutral
        }
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

            MetricPill(symbol: "arrow.down", value: ByteFormat.bytes(summary.downloadBytes), tint: LivingSignalTone.active.color)
            MetricPill(symbol: "arrow.up", value: ByteFormat.bytes(summary.uploadBytes), tint: LivingSignalTone.uploadHeavy.color)
            CompactMetric(symbol: "clock", value: NetworkDailySummaryPresentation.duration(summary.activeSeconds), tint: .secondary)
        }
        .livingSignalRow(tone: .neutral, padding: 7)
    }
}
