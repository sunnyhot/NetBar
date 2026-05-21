import SwiftUI

struct AboutPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceSection(title: appPreferences.text("软件更新", "Software Update")) {
                HStack {
                    Text(appPreferences.text("当前版本", "Current version"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(updater.currentVersionText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Toggle(appPreferences.text("自动检测更新", "Automatically check for updates"), isOn: $updater.automaticallyChecksForUpdates)

                if updater.isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: updater.downloadProgress)
                            .progressViewStyle(.linear)
                        Text("\(Int(updater.downloadProgress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(updater.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let lastCheckedAt = updater.lastCheckedAt {
                        Text("\(appPreferences.text("上次检查", "Last checked")): \(lastCheckedAt, style: .time)")
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
                        .help("打开 GitHub Releases")
                    }
                }
            }

            PreferenceSection(title: appPreferences.text("关于项目", "About Project")) {
                HStack {
                    Text(appPreferences.text("GitHub 仓库", "GitHub Repository"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Link(destination: URL(string: "https://github.com/sunnyhot/NetBar")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                            Text("sunnyhot/NetBar")
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    .help(appPreferences.text("在浏览器中打开 GitHub 仓库", "Open GitHub repository in browser"))
                }
            }

            Spacer()
        }
    }
}
