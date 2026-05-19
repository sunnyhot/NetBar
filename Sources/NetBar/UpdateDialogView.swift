import SwiftUI

enum UpdateDialogState: Equatable {
    case idle
    case downloading
    case completed
    case failed(String)
}

struct UpdateDialogView: View {
    @ObservedObject var updater: AppUpdater
    let onUpdate: () -> Void
    let onCancel: () -> Void

    private var version: String {
        updater.availableUpdate?.versionText ?? ""
    }

    private var changelog: String {
        updater.availableUpdate?.release.body?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var dialogState: UpdateDialogState {
        if updater.isUpdateReadyToInstall {
            return .completed
        }
        if updater.isDownloading {
            return .downloading
        }
        if let error = updater.updateError {
            return .failed(error)
        }
        return .idle
    }

    private var isZh: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            if !changelog.isEmpty {
                changelogSection
            }
            progressSection
            buttonSection
        }
        .padding(20)
        .frame(width: 480)
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(isZh ? "发现新版本" : "New Version Available")
                    .font(.system(size: 15, weight: .semibold))
                Text("v\(version)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isZh ? "更新日志" : "Release Notes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(changelog)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        switch dialogState {
        case .downloading:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: updater.downloadProgress, total: 1.0)
                    .progressViewStyle(.linear)
                HStack {
                    Text(isZh ? "正在下载更新..." : "Downloading update...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(updater.downloadProgress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        case .completed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(isZh ? "下载完成" : "Download Complete")
                    .font(.system(size: 12, weight: .medium))
            }
        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case .idle:
            EmptyView()
        }
    }

    private var buttonSection: some View {
        HStack {
            Button(isZh ? "取消" : "Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            switch dialogState {
            case .idle:
                Button(isZh ? "下载更新" : "Download Update") {
                    onUpdate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

            case .downloading:
                Button(isZh ? "下载中..." : "Downloading...") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)

            case .completed:
                Button(isZh ? "安装并重启" : "Install and Restart") {
                    onUpdate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

            case .failed:
                Button(isZh ? "重试" : "Retry") {
                    updater.clearUpdateError()
                    onUpdate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

@MainActor
final class UpdateDialogWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var updater: AppUpdater
    private var hostingView: NSHostingView<UpdateDialogView>?

    init(updater: AppUpdater) {
        self.updater = updater
    }

    func show() {
        let view = UpdateDialogView(
            updater: updater,
            onUpdate: { [weak self] in
                self?.handleUpdateAction()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hostingView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = updater.availableUpdate.map { "v\($0.versionText)" } ?? ""
        window.contentView = hostingView
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        updater.cancelDownloadIfNeeded()
    }

    private func handleUpdateAction() {
        if updater.isUpdateReadyToInstall {
            close()
            Task { @MainActor in
                await updater.downloadAndInstall()
            }
        } else {
            Task { @MainActor in
                await updater.downloadAndInstall()
            }
        }
    }
}
