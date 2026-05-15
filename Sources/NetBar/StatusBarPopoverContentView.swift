import SwiftUI

struct StatusBarPopoverContentView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openMainWindow: () -> Void
    let openPreferences: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Total speed header
            totalSpeedSection

            Divider().opacity(0.55)

            // Per-interface speed list
            if !monitor.snapshot.interfaces.isEmpty {
                interfaceListSection
                Divider()
            }

            // Action buttons
            actionBar
        }
        .padding(10)
        .frame(width: 312)
        .netBarPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }

    // MARK: - Total Speed

    private var totalSpeedSection: some View {
        HStack(spacing: 8) {
            // Download
            HStack(spacing: 9) {
                NetBarIconTile(systemName: "arrow.down", tone: .download, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(appPreferences.text("下载", "Down"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormat.speed(monitor.snapshot.downloadBytesPerSecond))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .netBarCard(cornerRadius: 11, padding: 9, isProminent: true)

            // Upload
            HStack(spacing: 9) {
                NetBarIconTile(systemName: "arrow.up", tone: .upload, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(appPreferences.text("上传", "Up"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text(ByteFormat.speed(monitor.snapshot.uploadBytesPerSecond))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .netBarCard(cornerRadius: 11, padding: 9, isProminent: true)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Interface List

    private var interfaceListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            NetBarSectionHeader(
                title: appPreferences.text("接口明细", "Interfaces"),
                subtitle: appPreferences.text("点击打开主面板查看完整趋势", "Open main panel for full trends")
            )
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Interface rows
            ForEach(monitor.snapshot.interfaces) { interface in
                InterfaceSpeedRow(interface: interface, appPreferences: appPreferences)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                openMainWindow()
            } label: {
                Label(appPreferences.text("打开主界面", "Open Main Window"), systemImage: "square.grid.2x2")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                openPreferences()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(NetBarIconButtonStyle())
            .help(appPreferences.text("偏好设置", "Preferences"))
        }
        .padding(.top, 9)
    }
}

// MARK: - Interface Speed Row

private struct InterfaceSpeedRow: View {
    let interface: InterfaceRate
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        HStack(spacing: 8) {
            // Interface icon
            Image(systemName: InterfacePresentation.iconName(for: interface.name))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(interface.isPrimary ? .blue : .secondary)
                .frame(width: 20)

            // Name
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(interface.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)

                    if interface.isPrimary {
                        Text(appPreferences.text("主", "Pri"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                }
                Text(interface.name)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Speed pills
            VStack(alignment: .trailing, spacing: 2) {
                SpeedPill(symbol: "arrow.down", value: ByteFormat.speed(interface.downloadBytesPerSecond), tint: .blue)
                SpeedPill(symbol: "arrow.up", value: ByteFormat.speed(interface.uploadBytesPerSecond), tint: .orange)
            }
        }
        .netBarCard(cornerRadius: 10, padding: 8)
        .padding(.vertical, 3)
    }
}

// MARK: - Speed Pill

private struct SpeedPill: View {
    let symbol: String
    let value: String
    let tint: Color

    var body: some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(tint.opacity(0.12), lineWidth: 0.5)
            )
    }
}
