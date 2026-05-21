import SwiftUI

struct AboutPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                appInfoCard

                softwareUpdateSection

                thanksSection

                Spacer()
            }
            .padding(.trailing, 2)
        }
    }

    // MARK: - App Info Card

    private var appInfoCard: some View {
        HStack(spacing: 16) {
            NetBarIconTile(systemName: "waveform.path.ecg.rectangle", tone: .download, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("NetBar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(appPreferences.text(
                    "版本 \(updater.currentVersionText)",
                    "Version \(updater.currentVersionText)"
                ))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

                Text(appPreferences.text(
                    "菜单栏网络流量监控工具",
                    "Menu bar network traffic monitor"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Link(destination: URL(string: "https://github.com/sunnyhot/NetBar")!) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11))
                    Text("GitHub")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help(appPreferences.text("在浏览器中打开 GitHub 仓库", "Open GitHub repository in browser"))
        }
        .padding(16)
        .netBarCard(cornerRadius: 14, padding: 0, isProminent: true)
    }

    // MARK: - Software Update

    private var updateStatusTone: NetBarTone {
        if updater.isChecking { return .neutral }
        if updater.isDownloading { return .download }
        if updater.availableUpdate != nil { return .warning }
        return .success
    }

    private var softwareUpdateSection: some View {
        PreferenceSection(title: appPreferences.text("软件更新", "Software Update")) {
            HStack {
                Text(appPreferences.text("当前版本", "Current version"))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(updater.currentVersionText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))

                if let lastCheckedAt = updater.lastCheckedAt {
                    Text("\(appPreferences.text("上次检查", "Last checked")): \(lastCheckedAt, style: .time)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Toggle(appPreferences.text("自动检测更新", "Automatically check for updates"), isOn: $updater.automaticallyChecksForUpdates)

            HStack(spacing: 4) {
                Circle()
                    .fill(updateStatusTone.color)
                    .frame(width: 6, height: 6)
                Text(updater.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(updateStatusTone.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if updater.isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: updater.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(NetBarTone.download.color)
                    Text("\(Int(updater.downloadProgress * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
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
                    .help(appPreferences.text("在浏览器中打开 GitHub Releases", "Open GitHub Releases in browser"))
                }
            }
        }
    }

    // MARK: - Thanks

    private var thanksSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text(appPreferences.text(
                    "Built with \u{2764}\u{FE0F} using Swift + SwiftUI",
                    "Built with \u{2764}\u{FE0F} using Swift + SwiftUI"
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
        .padding(.vertical, 8)
    }
}
