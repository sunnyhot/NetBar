import AppKit
import SwiftUI

enum UpdateDialogState: Equatable {
    case idle
    case downloading
    case completed
    case failed(String)
}

struct UpdateDialogView: View {
    @ObservedObject var updater: AppUpdater
    @State private var state: UpdateDialogState = .idle
    let onDismiss: () -> Void

    private var update: AvailableUpdate? {
        updater.availableUpdate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            if let body = update?.release.body,
               !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                changelogSection
            }

            if state == .downloading {
                progressSection
            }

            if case .failed(let message) = state {
                errorSection(message: message)
            }

            Divider()
                .padding(.vertical, 14)

            buttonSection
        }
        .padding(20)
        .frame(width: 460)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            NetBarIconTile(systemName: "arrow.down.circle.fill", tone: .download, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("发现新版本")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                if let update {
                    Text("v\(update.versionText)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }

            Spacer()
        }
        .padding(.bottom, 14)
    }

    // MARK: - Changelog

    private var changelogSection: some View {
        ScrollView {
            Text(verbatim: update!.release.body!.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 12))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.bottom, 14)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: updater.downloadProgress, total: 1.0)
                .progressViewStyle(.linear)
            HStack {
                Text(updater.statusMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(updater.downloadProgress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Error

    private func errorSection(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HStack {
            Button("取消") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            switch state {
            case .idle:
                Button("下载更新") {
                    startDownload()
                }
                .buttonStyle(.borderedProminent)

            case .downloading:
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 20, height: 20)

            case .completed:
                Button("安装并重启") {
                    Task { await updater.downloadAndInstall() }
                }
                .buttonStyle(.borderedProminent)

            case .failed:
                Button("重试") {
                    startDownload()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func startDownload() {
        state = .downloading
        Task {
            do {
                try await updater.downloadUpdateOnly()
                state = .completed
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Presenter

@MainActor
final class UpdateDialogPresenter {
    private var window: NSWindow?

    func present(updater: AppUpdater) {
        let view = UpdateDialogView(updater: updater) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingController(rootView: view)
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "软件更新"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = true
        newWindow.level = .floating
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        NSApplication.shared.activate(ignoringOtherApps: true)
        window = newWindow
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}
