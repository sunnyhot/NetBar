import SwiftUI

struct ApplicationTrafficPanel: View {
    let snapshot: NetworkSnapshot
    let appTraffic: ApplicationTrafficState
    @ObservedObject var preferences: AppPreferences
    @Binding var searchText: String
    let retry: () -> Void

    var body: some View {
        ApplicationTrafficList(
            snapshot: snapshot,
            appTraffic: appTraffic,
            preferences: preferences,
            searchText: $searchText,
            retry: retry
        )
    }
}
// MARK: - Application Traffic List

private struct ApplicationTrafficList: View {
    let snapshot: NetworkSnapshot
    let appTraffic: ApplicationTrafficState
    @ObservedObject var preferences: AppPreferences
    @Binding var searchText: String
    let retry: () -> Void

    private var presentationModel: ApplicationTrafficPresentationModel {
        ApplicationTrafficPresentation.makeModel(
            snapshot: snapshot,
            state: appTraffic,
            hidesSystemProcesses: preferences.hidesSystemProcesses,
            searchText: searchText
        )
    }

    var body: some View {
        let model = presentationModel
        let visibleApplications = model.visibleApplications

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
                    message: "\(readerErrorMessage(errorMessage))\n\(preferences.text("可重试读取；如果仍失败，请确认系统自带 nettop 可运行。", "Try again. If it still fails, confirm that the built-in nettop command can run."))",
                    actionTitle: preferences.text("重试", "Retry"),
                    action: retry
                )
            } else {
                // Sort & search controls — always visible in the detail popup
                AppTrafficControls(
                    preferences: preferences,
                    searchText: $searchText
                )

                if appTraffic.sampleCount > 0 {
                    AppTrafficAttributionCard(
                        summary: model.attributionSummary,
                        preferences: preferences,
                        sampleCount: appTraffic.sampleCount,
                        applicationCount: visibleApplications.count
                    )
                }

                if !visibleApplications.isEmpty {
                    let summaryMetrics = model.summaryMetrics

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


                if visibleApplications.isEmpty {
                    AppTrafficNotice(
                        symbol: isInitialLoading ? "arrow.triangle.2.circlepath" : "line.3.horizontal.decrease.circle",
                        title: isInitialLoading ? preferences.text("正在读取应用流量", "Reading Application Traffic") : emptyTitle,
                        message: emptyMessage,
                        showsProgress: isInitialLoading,
                        minContentHeight: isInitialLoading ? 96 : nil
                    )
                } else {
                    if appTraffic.isStale {
                        Text(preferences.text("重新采样中，正在显示上次数据", "Resampling — showing last data"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 2)
                    }
                    VStack(spacing: 4) {
                        ForEach(visibleApplications) { application in
                            ApplicationTrafficRow(
                                application: application,
                                role: ApplicationTrafficPresentation.attributionRole(for: application),
                                language: preferences.resolvedLanguage,
                                isDimmed: appTraffic.isStale || application.isExpiring
                            )
                        }
                    }
                    if model.isTruncated {
                        Text(preferences.text(
                            "仅显示前 \(visibleApplications.count) 个 · 共 \(model.totalMatches) 个命中，搜索可找到更多",
                            "Showing top \(visibleApplications.count) of \(model.totalMatches) — search to find more"
                        ))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
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

    /// reader 层上报的是语言无关的失败标识,在此映射为双语文案;
    /// 未知字符串(如测试注入)原样展示。
    private func readerErrorMessage(_ raw: String) -> String {
        switch raw {
        case ApplicationTrafficReaderFailure.spawnFailed.rawValue:
            return preferences.text(
                "无法启动 nettop 采样进程（/usr/bin/script）",
                "Failed to launch the nettop sampling process (/usr/bin/script)."
            )
        case ApplicationTrafficReaderFailure.restartsExhausted.rawValue:
            return preferences.text(
                "nettop 进程多次退出，应用流量采样已暂停",
                "nettop exited repeatedly; application traffic sampling was paused."
            )
        default:
            return raw
        }
    }

    private var isInitialLoading: Bool {
        appTraffic.isRefreshing && appTraffic.sampleCount == 0
    }

    private var emptyMessage: String {
        if isInitialLoading {
            return preferences.text(
                "应用级数据来自 macOS nettop，首次采样约需 2 秒，请稍候。",
                "Application-level data comes from macOS nettop. The first sample takes about 2 seconds."
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

            Text(headline)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .livingSignalRow(tone: livingTone, padding: 9)
        .help(details)
    }

    /// 一句话人话;细节(接口/应用速率、代理候选、采样数)收进 tooltip
    private var headline: String {
        guard let coverage = summary.coveragePercentage else {
            return preferences.text("归因待采样", "Attribution pending")
        }
        return preferences.text(
            "应用合计约为接口总流量的 \(coverage)%",
            "Apps account for about \(coverage)% of interface traffic"
        )
    }

    private var details: String {
        var parts: [String] = []
        parts.append(preferences.text(
            "接口 \(ByteFormat.speed(summary.interfaceBytesPerSecond)) · 应用 \(ByteFormat.speed(summary.applicationBytesPerSecond))",
            "Interface \(ByteFormat.speed(summary.interfaceBytesPerSecond)) · Apps \(ByteFormat.speed(summary.applicationBytesPerSecond))"
        ))
        if summary.status == .partial {
            parts.append(preferences.text("总流量与应用汇总存在差异", "Interface and app totals differ"))
        }
        if let proxy = summary.proxyCandidateNames.first {
            parts.append(preferences.text("代理/VPN：\(proxy)", "Proxy/VPN: \(proxy)"))
        } else if let helper = summary.helperCandidateNames.first {
            parts.append(preferences.text("子进程：\(helper)", "Helper: \(helper)"))
        }
        parts.append("\(preferences.text("采样", "Samples")) \(sampleCount) · \(preferences.text("应用行", "Rows")) \(applicationCount)")
        return parts.joined(separator: "\n")
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
            return LivingSignalTone.neutral.color
        case .covered:
            return LivingSignalTone.normal.color
        case .partial:
            return LivingSignalTone.attention.color
        }
    }

    private var livingTone: LivingSignalTone {
        switch summary.status {
        case .idle:
            return .idle
        case .covered:
            return .normal
        case .partial:
            return .attention
        }
    }
}

// MARK: - Application Traffic Controls (always visible)

private struct AppTrafficControls: View {
    @ObservedObject var preferences: AppPreferences
    @Binding var searchText: String

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField(preferences.text("搜索应用或进程", "Search apps or processes"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                if hasSearchText {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(preferences.text("清除搜索", "Clear search"))
                    .accessibilityLabel(preferences.text("清除搜索", "Clear search"))
                }
            }
            .livingSignalRow(tone: .neutral, padding: 6)

            Toggle(preferences.text("隐藏系统进程", "Hide system"), isOn: $preferences.hidesSystemProcesses)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .fixedSize()
                .help(preferences.text(
                    "隐藏推测为系统服务的进程（与偏好设置同步）",
                    "Hide processes inferred as system services (synced with Preferences)"
                ))
        }
    }
}

private struct AppTrafficNotice: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// 加载态显示旋转进度指示(替代静态图标)
    var showsProgress: Bool = false
    /// 加载态最小高度占位,避免数据出现时面板高度跳动
    var minContentHeight: CGFloat? = nil

    var body: some View {
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }

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
        .livingSignalRow(tone: actionTitle == nil ? .idle : .attention, padding: 12)
        .modifier(OptionalMinHeight(height: minContentHeight))
    }
}

private struct OptionalMinHeight: ViewModifier {
    let height: CGFloat?

    func body(content: Content) -> some View {
        if let height {
            content.frame(minHeight: height)
        } else {
            content
        }
    }
}

struct ApplicationTrafficRow: View {
    let application: ApplicationTrafficRate
    let role: ApplicationAttributionRole
    let language: AppLanguage
    var isDimmed: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            AppBadge(title: application.displayName)

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
                ForEach(ApplicationTrafficPresentation.rowMetrics(for: application)) { metric in
                    CompactMetric(metric: metric)
                }
            }
        }
        .livingSignalRow(tone: rowTone, padding: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.5)
        )
        .opacity(isDimmed ? 0.55 : 1)
        .accessibilityElement(children: .combine)
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

    private var rowTone: LivingSignalTone {
        switch role {
        case .application:
            return .neutral
        case .proxyOrVPN:
            return .attention
        case .helper:
            return .normal
        case .systemService:
            return .idle
        }
    }
}

struct AttributionRoleBadge: View {
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
            return LivingSignalTone.neutral.color
        case .proxyOrVPN:
            return LivingSignalTone.attention.color
        case .helper:
            return LivingSignalTone.active.color
        case .systemService:
            return LivingSignalTone.neutral.color.opacity(0.82)
        }
    }
}

struct CompactMetric: View {
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
        }
    }

    var tint: Color {
        switch kind {
        case .download:
            return LivingSignalTone.active.color
        case .upload:
            return LivingSignalTone.uploadHeavy.color
        }
    }
}

struct AppBadge: View {
    let title: String

    var body: some View {
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
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }

    private var initial: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }
}
