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

            Divider()

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
                            .frame(height: 90)
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

            Divider()

            FooterView(monitor: monitor, appPreferences: appPreferences, openPreferences: openPreferences)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 540, idealHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct HeaderView: View {
    let snapshot: NetworkSnapshot
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("NetBar")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Text(snapshot.timestamp, style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                SpeedTile(
                    title: appPreferences.text("下载", "Download"),
                    value: ByteFormat.speed(snapshot.downloadBytesPerSecond),
                    tint: .blue,
                    symbol: "arrow.down"
                )
                SpeedTile(
                    title: appPreferences.text("上传", "Upload"),
                    value: ByteFormat.speed(snapshot.uploadBytesPerSecond),
                    tint: .orange,
                    symbol: "arrow.up"
                )
            }
        }
    }
}

private struct FirstLaunchGuide: View {
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void
    let completeOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 5) {
                    Text(appPreferences.text("欢迎使用 NetBar", "Welcome to NetBar"))
                        .font(.system(size: 15, weight: .semibold))
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
                Button {
                    openPreferences()
                } label: {
                    Label(appPreferences.text("打开偏好设置", "Open Preferences"), systemImage: "gearshape")
                }

                Button(appPreferences.text("知道了", "Got It")) {
                    completeOnboarding()
                }
                .keyboardShortcut(.defaultAction)

                Spacer()
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SpeedTile: View {
    let title: String
    let value: String
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 26, height: 26)
                .foregroundStyle(.white)
                .background(tint, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryGrid: View {
    let snapshot: NetworkSnapshot
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                SummaryCell(title: appPreferences.text("总下载", "Total Download"), value: ByteFormat.bytes(snapshot.totalReceivedBytes))
                SummaryCell(title: appPreferences.text("总上传", "Total Upload"), value: ByteFormat.bytes(snapshot.totalSentBytes))
            }
            GridRow {
                SummaryCell(title: appPreferences.text("活动接口", "Active Interfaces"), value: "\(snapshot.interfaces.count)")
                SummaryCell(title: appPreferences.text("采样次数", "Samples"), value: "\(snapshot.sampleCount)")
            }
        }
    }
}

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
            HStack(alignment: .firstTextBaseline) {
                Text(preferences.text("应用流量", "Application Traffic"))
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if let timestamp = appTraffic.timestamp {
                    Text("\(preferences.text("更新于", "Updated")) \(timestamp, style: .time)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

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
                    HStack(spacing: 10) {
                        TextField(preferences.text("搜索应用或进程", "Search apps or processes"), text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        Picker(preferences.text("排序", "Sort"), selection: $preferences.applicationSort) {
                            ForEach(ApplicationSortMode.allCases) { sortMode in
                                Text(sortMode.title(language: preferences.resolvedLanguage)).tag(sortMode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 118)
                    }
                }

                if visibleApplications.isEmpty {
                    AppTrafficNotice(
                        symbol: appTraffic.isRefreshing ? "arrow.triangle.2.circlepath" : "line.3.horizontal.decrease.circle",
                        title: appTraffic.isRefreshing ? preferences.text("正在读取应用流量", "Reading Application Traffic") : emptyTitle,
                        message: emptyMessage
                    )
                } else {
                    VStack(spacing: 8) {
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
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
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ApplicationTrafficRow: View {
    let application: ApplicationTrafficRate

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                AppBadge(title: application.displayName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(application.processNames.prefix(2).joined(separator: ", "))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if !application.processLabel.isEmpty {
                    Text("PID \(application.processLabel)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                MetricPill(symbol: "arrow.down", value: ByteFormat.speed(application.downloadBytesPerSecond), tint: .blue)
                MetricPill(symbol: "arrow.up", value: ByteFormat.speed(application.uploadBytesPerSecond), tint: .orange)
            }

            HStack {
                Text("接收 \(ByteFormat.bytes(application.totalReceivedBytes))")
                Spacer()
                Text("发送 \(ByteFormat.bytes(application.totalSentBytes))")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AppBadge: View {
    let title: String

    var body: some View {
        Text(initial)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color(nsColor: .controlAccentColor), in: RoundedRectangle(cornerRadius: 7))
    }

    private var initial: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }
}

private struct SummaryCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct InterfaceList: View {
    let interfaces: [InterfaceRate]
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appPreferences.text("接口明细", "Interfaces"))
                .font(.system(size: 13, weight: .semibold))

            if interfaces.isEmpty {
                EmptyInterfacesView(appPreferences: appPreferences, refresh: refresh)
            } else {
                VStack(spacing: 8) {
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
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
            Text(appPreferences.text("暂无网络接口", "No Network Interfaces"))
                .font(.system(size: 13, weight: .semibold))
            Text(appPreferences.text("请确认网络连接可用。", "Check that a network connection is available."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button {
                refresh()
            } label: {
                Label(appPreferences.text("重新读取接口", "Read Interfaces Again"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct InterfaceRow: View {
    let interface: InterfaceRate

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(interface.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if interface.isPrimary {
                    Text("主接口")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }

                Spacer()

                Text(interface.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MetricPill(symbol: "arrow.down", value: ByteFormat.speed(interface.downloadBytesPerSecond), tint: .blue)
                MetricPill(symbol: "arrow.up", value: ByteFormat.speed(interface.uploadBytesPerSecond), tint: .orange)
            }

            HStack {
                Text("接收 \(ByteFormat.bytes(interface.totalReceivedBytes))")
                Spacer()
                Text("发送 \(ByteFormat.bytes(interface.totalSentBytes))")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

            HStack {
                Text("入包 \(ByteFormat.packets(interface.receivedPackets))")
                Spacer()
                Text("出包 \(ByteFormat.packets(interface.sentPackets))")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricPill: View {
    let symbol: String
    let value: String
    let tint: Color

    var body: some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct FooterView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        HStack {
            Label(
                monitor.isRunning ? appPreferences.text("实时监控中", "Monitoring") : appPreferences.text("已暂停", "Paused"),
                systemImage: monitor.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle"
            )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                openPreferences()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(appPreferences.text("偏好设置", "Preferences"))

            Button {
                monitor.refresh()
                monitor.refreshApplicationTraffic()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(appPreferences.text("立即刷新", "Refresh Now"))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help(appPreferences.text("退出 NetBar", "Quit NetBar"))
        }
    }
}

private struct TrafficChart: View {
    let points: [RatePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近 90 秒")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 12) {
                    LegendDot(title: "下载", color: .blue)
                    LegendDot(title: "上传", color: .orange)
                }
            }

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))

                    ChartLine(
                        points: points.map(\.downloadBytesPerSecond),
                        size: geometry.size,
                        color: .blue
                    )
                    ChartLine(
                        points: points.map(\.uploadBytesPerSecond),
                        size: geometry.size,
                        color: .orange
                    )
                }
            }
        }
    }
}

private struct LegendDot: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ChartLine: View {
    let points: [Double]
    let size: CGSize
    let color: Color

    var body: some View {
        Path { path in
            guard points.count > 1 else { return }
            let maxValue = max(points.max() ?? 1, 1)
            let step = size.width / CGFloat(points.count - 1)

            for index in points.indices {
                let x = CGFloat(index) * step
                let ratio = CGFloat(points[index] / maxValue)
                let y = size.height - (ratio * (size.height - 12)) - 6
                if index == points.startIndex {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}
