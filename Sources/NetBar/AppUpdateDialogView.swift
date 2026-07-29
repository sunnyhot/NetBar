import SwiftUI

// MARK: - Update Dialog View

struct UpdateDialogView: View {
    @ObservedObject var updater: AppUpdater
    let appPreferences: AppPreferences
    let currentVersion: String
    let onClose: () -> Void

    private var dialogState: UpdateDialogState {
        if updater.isDownloading { return .downloading }
        if updater.isUpdateReadyToInstall { return .readyToInstall }
        return .ready
    }

    var body: some View {
        VStack(spacing: 0) {
            titleSection
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if let body = changelogBody {
                changelogSection(body)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if dialogState == .downloading {
                progressSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if dialogState == .downloading {
                Text(appPreferences.text("正在下载...", "Downloading..."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            } else if dialogState == .readyToInstall {
                Text(appPreferences.text("下载完成，点击安装并重启", "Download complete, click to install and restart"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            Divider()
                .padding(.bottom, 12)

            buttonSection(dialogState)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(width: 440)
    }

    private var changelogBody: String? {
        guard let body = updater.availableUpdate?.release.body?
            .trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else {
            return nil
        }
        return body
    }

    private var titleSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(appPreferences.text(
                    "发现新版本 \(updater.availableUpdate?.versionText ?? "")",
                    "New Version Available: \(updater.availableUpdate?.versionText ?? "")"
                ))
                .font(.headline)
                Text(appPreferences.text(
                    "当前版本：\(currentVersion)",
                    "Current version: \(currentVersion)"
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private func changelogSection(_ body: String) -> some View {
        GroupBox(appPreferences.text("更新内容", "What's New")) {
            ScrollView {
                Text(body)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 180)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            ProgressView(value: updater.downloadProgress)
                .progressViewStyle(.linear)
            HStack {
                Text("\(Int(updater.downloadProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func buttonSection(_ state: UpdateDialogState) -> some View {
        HStack {
            switch state {
            case .ready:
                Button(appPreferences.text("取消", "Cancel")) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(appPreferences.text("下载更新", "Download Update")) {
                    Task { @MainActor in
                        await updater.downloadForDialog()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

            case .downloading:
                Spacer()
                Button(appPreferences.text("取消", "Cancel")) { onClose() }
                    .keyboardShortcut(.cancelAction)

            case .readyToInstall:
                Button(appPreferences.text("稍后", "Later")) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(appPreferences.text("安装并重启", "Install and Restart")) {
                    try? updater.installPreparedUpdate()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private enum UpdateDialogState {
    case ready
    case downloading
    case readyToInstall
}
