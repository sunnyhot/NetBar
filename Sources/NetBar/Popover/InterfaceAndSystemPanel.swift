import SwiftUI

struct InterfaceAndSystemPanel: View {
    let snapshot: NetworkSnapshot
    let systemResources: SystemResourceSummary
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void
    @State private var showsAdvancedDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: LivingSignalLayout.verticalSectionSpacing) {
            if systemResources.totalMemory > 0 {
                SystemResourceCard(summary: systemResources, appPreferences: appPreferences)
            }
            PrimaryInterfaceSection(
                interfaces: snapshot.interfaces,
                appPreferences: appPreferences,
                refresh: refresh
            )
            AdvancedInterfaceDiagnostics(
                interfaces: snapshot.interfaces,
                appPreferences: appPreferences,
                isExpanded: $showsAdvancedDiagnostics
            )
        }
    }
}

// MARK: - Primary Interface

private struct PrimaryInterfaceSection: View {
    let interfaces: [InterfaceRate]
    @ObservedObject var appPreferences: AppPreferences
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetBarSectionHeader(
                title: appPreferences.text("主网络接口", "Primary Interface"),
                subtitle: appPreferences.text("当前默认网络路径", "Current default network path")
            )

            if let primaryInterface = InterfacePresentation.preferredPrimaryInterface(in: interfaces) {
                InterfaceRow(
                    interface: primaryInterface,
                    appPreferences: appPreferences,
                    showsPacketCounts: false
                )
            } else {
                EmptyInterfacesView(
                    hasKnownInterfaces: false,
                    appPreferences: appPreferences,
                    refresh: refresh
                )
            }
        }
    }
}

// MARK: - Advanced Interface Diagnostics

private struct AdvancedInterfaceDiagnostics: View {
    let interfaces: [InterfaceRate]
    @ObservedObject var appPreferences: AppPreferences
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appPreferences.text(
                    "所有已识别接口、累计流量与收发包数",
                    "All known interfaces, cumulative traffic, and packet counts"
                ))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

                if interfaces.isEmpty {
                    Text(appPreferences.text("暂无接口数据", "No interface data"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    VStack(spacing: 6) {
                        ForEach(interfaces) { item in
                            InterfaceRow(
                                interface: item,
                                appPreferences: appPreferences,
                                showsPacketCounts: true
                            )
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label(
                appPreferences.text("高级接口诊断", "Advanced Interface Diagnostics"),
                systemImage: "network"
            )
            .font(.system(size: 11, weight: .semibold))
        }
        .livingSignalRow(tone: .neutral, padding: 10)
        .accessibilityHint(appPreferences.text(
            "展开后显示所有网络接口和包计数",
            "Expand to show all network interfaces and packet counts"
        ))
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
        .livingSignalRow(tone: hasKnownInterfaces ? .idle : .attention, padding: 12)
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
    @ObservedObject var appPreferences: AppPreferences
    let showsPacketCounts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: InterfacePresentation.iconName(for: interface.name))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(interface.isPrimary ? LivingSignalTone.active.color : LivingSignalTone.neutral.color)
                    .frame(width: 18)

                Text(interface.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)

                if interface.isPrimary {
                    NetBarBadge(text: appPreferences.text("主接口", "Primary"), tone: .download)
                }

                Spacer()

                Text(interface.name)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                MetricPill(
                    symbol: "arrow.down",
                    value: ByteFormat.speed(interface.downloadBytesPerSecond),
                    tint: LivingSignalTone.active.color
                )
                MetricPill(
                    symbol: "arrow.up",
                    value: ByteFormat.speed(interface.uploadBytesPerSecond),
                    tint: LivingSignalTone.uploadHeavy.color
                )
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(appPreferences.text("累计接收", "Received"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormat.bytes(interface.totalReceivedBytes))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(appPreferences.text("累计发送", "Sent"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormat.bytes(interface.totalSentBytes))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }

                if showsPacketCounts {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(appPreferences.text("收 / 发包", "Packets In / Out"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.quaternary)
                        Text(
                            "\(ByteFormat.packets(interface.receivedPackets)) / \(ByteFormat.packets(interface.sentPackets))"
                        )
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .livingSignalRow(tone: interface.isPrimary ? .active : .neutral, padding: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        )
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
                                .fill(LivingSignalTone.neutral.color.opacity(0.45))
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
                                    .fill(LivingSignalTone.attention.color.opacity(0.45))
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
        }
        .livingSignalRow(tone: .neutral, padding: 10)
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
                    .fill(Color.primary.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.08)))
            )
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.15), lineWidth: 0.5))
    }
}
