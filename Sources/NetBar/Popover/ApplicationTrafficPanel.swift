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
            sortMode: preferences.applicationSort,
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
        .livingSignalPanel(tone: livingTone, padding: 9)
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
        .livingSignalPanel(tone: .neutral, padding: 8)
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
        .livingSignalPanel(tone: actionTitle == nil ? .idle : .attention, padding: 12)
    }
}

struct ApplicationTrafficRow: View {
    let application: ApplicationTrafficRate
    let role: ApplicationAttributionRole
    let language: AppLanguage
    let displayMode: ApplicationSortMode

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
        .livingSignalPanel(tone: rowTone, padding: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.5)
        )
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

private final class AppBadgeIconCacheReference: @unchecked Sendable {
    let cache: NSCache<NSNumber, NSImage>

    init(_ cache: NSCache<NSNumber, NSImage>) {
        self.cache = cache
    }
}

private final class AppBadgeIconProviderReference: @unchecked Sendable {
    private let iconForPID: (Int32) -> NSImage?

    init(_ iconForPID: @escaping (Int32) -> NSImage?) {
        self.iconForPID = iconForPID
    }

    func icon(for pid: Int32) -> NSImage? {
        iconForPID(pid)
    }
}

enum AppBadgeIconResolver {
    static func cachedIcon(for pids: [Int32]) -> NSImage? {
        cachedIcon(for: pids, cache: appIconCache)
    }

    static func cachedIcon(for pids: [Int32], cache: NSCache<NSNumber, NSImage>) -> NSImage? {
        for pid in pids {
            if let cached = cache.object(forKey: NSNumber(value: pid)) {
                return cached
            }
        }
        return nil
    }

    static func resolveIcon(for pids: [Int32]) -> NSImage? {
        resolveIcon(for: pids, cache: appIconCache) { pid in
            guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
            return app.icon
        }
    }

    static func resolveIconAsync(for pids: [Int32]) async -> NSImage? {
        await resolveIconAsync(for: pids, cache: appIconCache) { pid in
            guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
            return app.icon
        }
    }

    static func resolveIconAsync(
        for pids: [Int32],
        cache: NSCache<NSNumber, NSImage>,
        iconForPID: @escaping (Int32) -> NSImage?
    ) async -> NSImage? {
        if let cached = cachedIcon(for: pids, cache: cache) {
            return cached
        }

        let cacheReference = AppBadgeIconCacheReference(cache)
        let providerReference = AppBadgeIconProviderReference(iconForPID)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let icon = resolveIcon(for: pids, cache: cacheReference.cache) { pid in
                    providerReference.icon(for: pid)
                }
                continuation.resume(returning: icon)
            }
        }
    }

    static func resolveIcon(
        for pids: [Int32],
        cache: NSCache<NSNumber, NSImage>,
        iconForPID: (Int32) -> NSImage?
    ) -> NSImage? {
        if let cached = cachedIcon(for: pids, cache: cache) {
            return cached
        }

        for pid in pids {
            guard let icon = iconForPID(pid) else { continue }
            cache.setObject(icon, forKey: NSNumber(value: pid))
            return icon
        }

        return nil
    }
}

struct AppBadge: View {
    let title: String
    let pids: [Int32]
    @State private var loadedIcon: NSImage?
    @State private var iconLoadTask: Task<Void, Never>?

    private var displayedIcon: NSImage? {
        loadedIcon ?? AppBadgeIconResolver.cachedIcon(for: pids)
    }

    var body: some View {
        Group {
            if let icon = displayedIcon {
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
        .onAppear(perform: scheduleIconLoad)
        .onDisappear(perform: cancelIconLoad)
        .onChange(of: pids) { _ in
            loadedIcon = AppBadgeIconResolver.cachedIcon(for: pids)
            scheduleIconLoad()
        }
    }

    private var initial: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    private func scheduleIconLoad() {
        if let cached = AppBadgeIconResolver.cachedIcon(for: pids) {
            cancelIconLoad()
            loadedIcon = cached
            return
        }

        guard !pids.isEmpty else {
            cancelIconLoad()
            return
        }
        iconLoadTask?.cancel()
        let pids = self.pids
        iconLoadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            let icon = await AppBadgeIconResolver.resolveIconAsync(for: pids)
            guard !Task.isCancelled else { return }
            loadedIcon = icon
            iconLoadTask = nil
        }
    }

    private func cancelIconLoad() {
        iconLoadTask?.cancel()
        iconLoadTask = nil
    }
}
