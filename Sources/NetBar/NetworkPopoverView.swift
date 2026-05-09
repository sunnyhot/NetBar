import SwiftUI

struct NetworkPopoverView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var updater: AppUpdater
    @State private var selectedPage = DetailsPage.traffic

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(snapshot: monitor.snapshot)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Picker("", selection: $selectedPage) {
                ForEach(DetailsPage.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            Divider()

            switch selectedPage {
            case .traffic:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TrafficChart(points: monitor.recentHistory)
                            .frame(height: 90)
                            .padding(.top, 16)

                        SummaryGrid(snapshot: monitor.snapshot)

                        ApplicationTrafficList(appTraffic: monitor.appTraffic)

                        InterfaceList(interfaces: monitor.snapshot.interfaces)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
            case .settings:
                StyleSettingsView(settings: settings, updater: updater, snapshot: monitor.snapshot)
            }

            Divider()

            FooterView(monitor: monitor)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .frame(width: 460, height: 660)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private enum DetailsPage: String, CaseIterable, Identifiable {
    case traffic
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .traffic:
            return "流量"
        case .settings:
            return "设置"
        }
    }
}

private struct HeaderView: View {
    let snapshot: NetworkSnapshot

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
                    title: "下载",
                    value: ByteFormat.speed(snapshot.downloadBytesPerSecond),
                    tint: .blue,
                    symbol: "arrow.down"
                )
                SpeedTile(
                    title: "上传",
                    value: ByteFormat.speed(snapshot.uploadBytesPerSecond),
                    tint: .orange,
                    symbol: "arrow.up"
                )
            }
        }
    }
}

private struct StyleSettingsView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var updater: AppUpdater
    let snapshot: NetworkSnapshot

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { settings.textColor.swiftUIColor },
            set: { settings.textColor = PersistedColor(color: $0) }
        )
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { settings.backgroundColor.swiftUIColor },
            set: { settings.backgroundColor = PersistedColor(color: $0) }
        )
    }

    private var transparentBackgroundBinding: Binding<Bool> {
        Binding(
            get: { !settings.showsBackground },
            set: { isTransparent in
                settings.showsBackground = !isTransparent
                if isTransparent {
                    settings.backgroundOpacity = 0
                } else if settings.backgroundOpacity == 0 {
                    settings.backgroundOpacity = 0.8
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MenuBarPreview(settings: settings, snapshot: snapshot)

                SettingsGroup(title: "文字") {
                    SliderSetting(
                        title: "字号",
                        value: $settings.fontSize,
                        range: 8...18,
                        displayValue: "\(Int(settings.fontSize.rounded()))"
                    )

                    Toggle("自动宽度", isOn: $settings.usesAutomaticWidth)

                    if !settings.usesAutomaticWidth {
                        SliderSetting(
                            title: "手动宽度",
                            value: $settings.itemWidth,
                            range: 36...220,
                            displayValue: "\(Int(settings.itemWidth.rounded()))"
                        )
                    }

                    SliderSetting(
                        title: "行距",
                        value: $settings.lineSpacing,
                        range: -5...8,
                        displayValue: String(format: "%.1f", settings.lineSpacing)
                    )

                    ColorPicker("文字颜色", selection: textColorBinding, supportsOpacity: true)

                    Toggle("加粗", isOn: $settings.isBold)
                    Toggle("显示箭头", isOn: $settings.showsArrows)
                }

                SettingsGroup(title: "布局") {
                    Picker("排列", selection: $settings.order) {
                        ForEach(StatusBarOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("对齐", selection: $settings.alignment) {
                        ForEach(StatusBarAlignment.allCases) { alignment in
                            Text(alignment.title).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SettingsGroup(title: "背景") {
                    Toggle("透明背景", isOn: transparentBackgroundBinding)

                    if settings.showsBackground {
                        ColorPicker("背景颜色", selection: backgroundColorBinding, supportsOpacity: true)

                        SliderSetting(
                            title: "不透明度",
                            value: $settings.backgroundOpacity,
                            range: 0...1,
                            displayValue: "\(Int((settings.backgroundOpacity * 100).rounded()))%"
                        )
                    }
                }

                UpdateSettingsView(updater: updater)

                HStack {
                    Spacer()
                    Button("恢复默认") {
                        settings.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(18)
        }
    }
}

private struct UpdateSettingsView: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        SettingsGroup(title: "更新") {
            HStack {
                Text("当前版本")
                Spacer()
                Text(updater.currentVersionText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium))

            Toggle("自动检测更新", isOn: $updater.automaticallyChecksForUpdates)

            VStack(alignment: .leading, spacing: 6) {
                Text(updater.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let lastCheckedAt = updater.lastCheckedAt {
                    Text("上次检查：\(lastCheckedAt, style: .time)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        await updater.checkForUpdates(isManual: true)
                    }
                } label: {
                    Label(updater.isChecking ? "检查中" : "检查更新", systemImage: "arrow.clockwise")
                }
                .disabled(updater.isChecking || updater.isDownloading)

                if updater.availableUpdate != nil {
                    Button {
                        Task {
                            await updater.downloadAndInstall()
                        }
                    } label: {
                        Label(updater.isDownloading ? "下载中" : "下载并安装", systemImage: "square.and.arrow.down")
                    }
                    .disabled(updater.isChecking || updater.isDownloading)
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                if let releasePageURL = updater.releasePageURL {
                    Link(destination: releasePageURL) {
                        Image(systemName: "safari")
                    }
                    .help("打开 GitHub Releases")
                }
            }
        }
    }
}

private struct MenuBarPreview: View {
    @ObservedObject var settings: StatusBarSettings
    let snapshot: NetworkSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("菜单栏预览")
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Spacer()
                Image(nsImage: StatusBarImageRenderer.image(snapshot: snapshot, settings: settings))
                    .frame(
                        width: StatusBarImageRenderer.width(snapshot: snapshot, settings: settings),
                        height: max(NSStatusBar.system.thickness, 24)
                    )
                Spacer()
            }
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.27, green: 0.28, blue: 0.14),
                        Color(red: 0.18, green: 0.19, blue: 0.12)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SliderSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium))

            Slider(value: $value, in: range)
        }
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

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                SummaryCell(title: "总下载", value: ByteFormat.bytes(snapshot.totalReceivedBytes))
                SummaryCell(title: "总上传", value: ByteFormat.bytes(snapshot.totalSentBytes))
            }
            GridRow {
                SummaryCell(title: "活动接口", value: "\(snapshot.interfaces.count)")
                SummaryCell(title: "采样次数", value: "\(snapshot.sampleCount)")
            }
        }
    }
}

private struct ApplicationTrafficList: View {
    let appTraffic: ApplicationTrafficState

    private var visibleApplications: [ApplicationTrafficRate] {
        Array(appTraffic.applications.prefix(18))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("应用流量")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if let timestamp = appTraffic.timestamp {
                    Text("更新于 \(timestamp, style: .time)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = appTraffic.errorMessage {
                AppTrafficNotice(
                    symbol: "exclamationmark.triangle",
                    title: "无法读取应用流量",
                    message: errorMessage
                )
            } else if visibleApplications.isEmpty {
                AppTrafficNotice(
                    symbol: appTraffic.isRefreshing ? "arrow.triangle.2.circlepath" : "app.dashed",
                    title: appTraffic.isRefreshing ? "正在读取应用流量" : "暂无应用流量",
                    message: "应用级数据来自 macOS nettop，首次采样后会显示实时速率。"
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

private struct AppTrafficNotice: View {
    let symbol: String
    let title: String
    let message: String

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("接口明细")
                .font(.system(size: 13, weight: .semibold))

            if interfaces.isEmpty {
                EmptyInterfacesView()
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
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
            Text("暂无网络接口")
                .font(.system(size: 13, weight: .semibold))
            Text("请确认网络连接可用。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
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

    var body: some View {
        HStack {
            Label(monitor.isRunning ? "实时监控中" : "已暂停", systemImage: monitor.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                monitor.refresh()
                monitor.refreshApplicationTraffic()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("立即刷新")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("退出 NetBar")
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
