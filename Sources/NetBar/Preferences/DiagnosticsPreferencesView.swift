import AppKit
import SwiftUI

struct DiagnosticsPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    let snapshot: DiagnosticsSnapshot

    var body: some View {
        PreferenceSection(
            title: appPreferences.text("诊断与健康", "Diagnostics & Health"),
            systemImage: "stethoscope"
        ) {
            diagnosticsRow(appPreferences.text("版本", "Version"), snapshot.appVersion)
            diagnosticsRow(appPreferences.text("Bundle ID", "Bundle ID"), snapshot.bundleIdentifier)
            diagnosticsRow(appPreferences.text("更新状态", "Update status"), snapshot.updateStatus)
            diagnosticsRow(appPreferences.text("采样状态", "Sampling"), snapshot.sampling.isRunning ? "running" : "stopped")
            diagnosticsRow(appPreferences.text("应用采样", "App sampling"), snapshot.sampling.isApplicationTrafficSamplingEnabled ? "enabled" : "paused")
            diagnosticsRow(appPreferences.text("通知权限", "Notifications"), snapshot.notificationAuthorization)
            diagnosticsRow(appPreferences.text("历史文件", "History"), snapshot.historyStatus)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    DiagnosticsCenter.copyText(for: snapshot, language: appPreferences.resolvedLanguage),
                    forType: .string
                )
            } label: {
                Label(appPreferences.text("复制诊断摘要", "Copy Diagnostics"), systemImage: "doc.on.doc")
            }

            Text(appPreferences.text(
                "诊断摘要不包含网络内容、URL、域名、聊天内容或文件内容。",
                "Diagnostics do not include network contents, URLs, domains, chat contents, or file contents."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func diagnosticsRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
