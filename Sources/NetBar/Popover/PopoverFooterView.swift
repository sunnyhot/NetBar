import SwiftUI

struct PopoverFooterView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        FooterView(
            monitor: monitor,
            appPreferences: appPreferences,
            openPreferences: openPreferences
        )
    }
}
// MARK: - Footer

private struct FooterView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        HStack {
            LivingSignalStatusChip(
                text: monitor.isRunning
                    ? appPreferences.text("实时监控中", "Monitoring")
                    : appPreferences.text("已暂停", "Paused"),
                tone: monitor.isRunning ? .normal : .attention
            )

            Spacer()

            HStack(spacing: 12) {
                Button { openPreferences() } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(NetBarIconButtonStyle())
                .help(appPreferences.text("偏好设置", "Preferences"))

                Button {
                    monitor.refresh()
                    monitor.refreshApplicationTraffic()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(NetBarIconButtonStyle())
                .help(appPreferences.text("立即刷新", "Refresh Now"))

                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(NetBarIconButtonStyle(tone: .warning))
                .help(appPreferences.text("退出 NetBar", "Quit NetBar"))
            }
        }
        .livingSignalPanel(tone: monitor.isRunning ? .normal : .attention, padding: 8)
    }
}
