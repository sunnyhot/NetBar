import SwiftUI

struct InterfaceAndSystemPanel: View {
    let snapshot: NetworkSnapshot
    let systemResources: SystemResourceSummary
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LivingSignalLayout.verticalSectionSpacing) {
            if systemResources.totalMemory > 0 {
                SystemResourceCard(summary: systemResources, appPreferences: appPreferences)
            }
            InterfaceList(
                interfaces: snapshot.interfaces,
                appPreferences: appPreferences,
                refresh: refresh
            )
        }
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
        .livingSignalPanel(tone: hasKnownInterfaces ? .idle : .attention, padding: 12)
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
        .livingSignalPanel(tone: interface.isPrimary ? .active : .neutral, padding: 10)
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
        .livingSignalPanel(tone: .neutral, padding: 10)
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
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
