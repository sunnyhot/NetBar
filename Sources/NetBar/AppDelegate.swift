import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let settings = StatusBarSettings()
    private let updater = AppUpdater()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        statusBarController = StatusBarController(
            monitor: NetworkMonitor(),
            settings: settings,
            updater: updater
        )
        updater.startAutomaticChecks()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.statusBarController?.showDetailsWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showDetailsWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
