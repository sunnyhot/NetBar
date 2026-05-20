import SwiftUI

struct NetworkPopoverView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void
    @State private var appSearchText = ""

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
                    if !appPreferences.hasCompletedOnboarding {
                        FirstLaunchGuide(
                            appPreferences: appPreferences,
                            openPreferences: openPreferences,
                            completeOnboarding: appPreferences.completeOnboarding
                        )
                        .padding(.top, 16)
                    } else {
                        TrafficChart(points: monitor.recentHistory)
                            .frame(height: 132)
                            .padding(.top, 16)
                    }

                    SummaryGrid(snapshot: monitor.snapshot, appPreferences: appPreferences)

                    ApplicationTrafficList(
                        appTraffic: monitor.appTraffic,
                        preferences: appPreferences,
                        searchText: $appSearchText,
                        retry: monitor.refreshApplicationTraffic
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
                if shouldShowControls {
                    HStack(spacing: 8) {
                        TextField(preferences.text("搜索应用或进程", "Search apps or processes"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        Picker(preferences.text("排序", "Sort"), selection: $preferences.applicationSort) {
                            ForEach(ApplicationSortMode.allCases) { sortMode in
                                Text(sortMode.title(language: preferences.resolvedLanguage)).tag(sortMode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 126)
                    }
                    .netBarCard(cornerRadius: 11, padding: 8)
                }

                if visibleApplications.isEmpty {
                    AppTrafficNotice(
                        symbol: appTraffic.isRefreshing ? "arrow.triangle.2.circlepath" : "line.3.horizontal.decrease.circle",
                        title: appTraffic.isRefreshing ? preferences.text("正在读取应用流量", "Reading Application Traffic") : emptyTitle,
                        message: emptyMessage
                    )
                } else {
                    VStack(spacing: 4) {
                        ForEach(visibleApplications) { application in
                            ApplicationTrafficRow(application: application)
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

    private var shouldShowControls: Bool {
        !appTraffic.applications.isEmpty || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyMessage: String {
        if appTraffic.isRefreshing {
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
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            AppBadge(title: application.displayName, pids: application.pids)

            VStack(alignment: .leading, spacing: 1) {
                Text(application.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(detailSubtitle)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                CompactMetric(
                    symbol: "arrow.down",
                    value: ByteFormat.speed(application.downloadBytesPerSecond),
                    tint: .blue
                )
                CompactMetric(
                    symbol: "arrow.up",
                    value: ByteFormat.speed(application.uploadBytesPerSecond),
                    tint: .orange
                )
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

private struct CompactMetric: View {
    let symbol: String
    let value: String
    let tint: Color

    var body: some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("接口明细", "Interfaces"),
                subtitle: appPreferences.text("活动接口与累计包量", "Active interfaces and cumulative packets")
            )

            if interfaces.isEmpty {
                EmptyInterfacesView(appPreferences: appPreferences, refresh: refresh)
            } else {
                VStack(spacing: 6) {
                    ForEach(interfaces) { item in
                        InterfaceRow(interface: item)
                    }
                }
            }
        }
    }
}

private struct EmptyInterfacesView: View {
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(appPreferences.text("暂无网络接口", "No Network Interfaces"))
                .font(.system(size: 12, weight: .bold))
            Text(appPreferences.text("请确认网络连接可用。", "Check that a network connection is available."))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NetBarSectionHeader(
                title: "最近 90 秒",
                subtitle: "下载 / 上传实时趋势",
                trailing: "\(points.count) pts"
            )

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                    chartGrid
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            LegendDot(title: "下载", color: .blue)
                            LegendDot(title: "上传", color: .orange)
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
