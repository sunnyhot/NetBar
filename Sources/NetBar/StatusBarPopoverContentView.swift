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

            Divider()

            // Per-interface speed list
            if !monitor.snapshot.interfaces.isEmpty {
                interfaceListSection
                Divider()
            }

            // Action buttons
            actionBar
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Total Speed

    private var totalSpeedSection: some View {
        HStack(spacing: 0) {
            // Download
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(appPreferences.text("下载", "Down"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.speed(monitor.snapshot.downloadBytesPerSecond))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Separator
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1, height: 36)
                .padding(.horizontal, 4)

            // Upload
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(appPreferences.text("上传", "Up"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.speed(monitor.snapshot.uploadBytesPerSecond))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Interface List

    private var interfaceListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text(appPreferences.text("接口明细", "Interfaces"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
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
            .buttonStyle(.borderless)
            .help(appPreferences.text("偏好设置", "Preferences"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Interface Speed Row

private struct InterfaceSpeedRow: View {
    let interface: InterfaceRate
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        HStack(spacing: 8) {
            // Interface icon
            Image(systemName: interfaceIcon)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var interfaceIcon: String {
        let name = interface.name.lowercased()
        if name.hasPrefix("en") && !name.contains("bridge") {
            return "wifi"
        } else if name.hasPrefix("bridge") {
            return "network.badge.shieldbell.fill"
        } else if name.hasPrefix("lo") {
            return "arrow.triangle.2.circlepath"
        } else if name.hasPrefix("utun") || name.hasPrefix("awdl") {
            return "antenna.radiowaves.left.and.right"
        } else {
            return "network"
        }
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
