import SwiftUI

struct AboutPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater
    let diagnosticsSnapshot: DiagnosticsSnapshot

    private var updateStatusColor: Color {
        if updater.isChecking || updater.isDownloading {
            return .secondary
        }
        if updater.isUpdateReadyToInstall || updater.availableUpdate != nil {
            return .orange
        }
        return .green
    }

    private var updateStatusIcon: String {
        if updater.isChecking {
            return "arrow.clockwise"
        }
        if updater.isDownloading {
            return "arrow.down.circle"
        }
        if updater.isUpdateReadyToInstall {
            return "checkmark.circle.fill"
        }
        if updater.availableUpdate != nil {
            return "exclamationmark.circle"
        }
        return "checkmark.circle.fill"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                appInfoCard

                softwareUpdateSection

                DiagnosticsPreferencesView(
                    appPreferences: appPreferences,
                    snapshot: diagnosticsSnapshot
                )

                thanksFooter

                Spacer()
            }
        }
    }

    private var appInfoCard: some View {
        HStack(spacing: 16) {
            NetBarIconTile(systemName: "waveform.path.ecg.rectangle", tone: .download, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("NetBar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                HStack(spacing: 6) {
                    Text(appPreferences.text("版本", "Version"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(updater.currentVersionText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Text(appPreferences.text(
                    "菜单栏网络流量监控工具",
                    "Menu bar network traffic monitor"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

                Link(destination: URL(string: "https://github.com/sunnyhot/NetBar")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("sunnyhot/NetBar")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.blue)
                }
                .help(appPreferences.text("在浏览器中打开 GitHub 仓库", "Open GitHub repository in browser"))
            }

            Spacer()
        }
        .padding(16)
        .netBarCard(cornerRadius: 14, padding: 0, isProminent: true)
    }

    private var softwareUpdateSection: some View {
        PreferenceSection(title: appPreferences.text("软件更新", "Software Update")) {
            HStack {
                Image(systemName: updateStatusIcon)
                    .foregroundStyle(updateStatusColor)
                    .font(.system(size: 12))

                Text(updater.currentVersionText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))

                Spacer()

                if let lastCheckedAt = updater.lastCheckedAt {
                    Text("\(appPreferences.text("上次检查", "Last checked")): \(lastCheckedAt, style: .time)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Toggle(appPreferences.text("自动检测更新", "Automatically check for updates"), isOn: $updater.automaticallyChecksForUpdates)

            if updater.isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: updater.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                    HStack {
                        Text(updater.statusMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(updater.downloadProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(updater.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(updateStatusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        await updater.checkForUpdates(isManual: true)
                    }
                } label: {
                    Label(updater.isChecking ? appPreferences.text("检查中", "Checking") : appPreferences.text("检查更新", "Check for Updates"), systemImage: "arrow.clockwise")
                }
                .disabled(updater.isChecking || updater.isDownloading)

                if updater.isUpdateReadyToInstall {
                    Button {
                        Task {
                            await updater.downloadAndInstall()
                        }
                    } label: {
                        Label(appPreferences.text("安装并重启", "Install and Restart"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                } else if updater.availableUpdate != nil {
                    Button {
                        Task {
                            await updater.downloadAndInstall()
                        }
                    } label: {
                        Label(updater.isDownloading ? appPreferences.text("下载中", "Downloading") : appPreferences.text("下载并安装", "Download and Install"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(updater.isChecking || updater.isDownloading)
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                if let releasePageURL = updater.releasePageURL {
                    Link(destination: releasePageURL) {
                        Image(systemName: "safari")
                            .foregroundStyle(.secondary)
                    }
                    .help(appPreferences.text("打开 GitHub Releases", "Open GitHub Releases"))
                }
            }
        }
    }

    private var thanksFooter: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text(appPreferences.text(
                    "Built with ❤️ using Swift + SwiftUI",
                    "Built with ❤️ using Swift + SwiftUI"
                ))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

                Text(appPreferences.text(
                    "开源项目，欢迎贡献",
                    "Open source, contributions welcome"
                ))
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}
