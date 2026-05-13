import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let settings = StatusBarSettings()
    private let appPreferences = AppPreferences()
    private let updater = AppUpdater()
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        appPreferences: appPreferences,
        updater: updater
    )
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppAppearance()
        configureMainMenu()
        applyActivationPolicy()
        configurePreferenceObservers()
        statusBarController = StatusBarController(
            monitor: NetworkMonitor(),
            settings: settings,
            appPreferences: appPreferences,
            openPreferences: { [weak self] in
                self?.showPreferences(nil)
            },
            showAbout: { [weak self] in
                self?.showAbout(nil)
            }
        )
        updater.startAutomaticChecks()

        guard !appPreferences.hasCompletedOnboarding else { return }
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

    @objc private func showAbout(_ sender: Any?) {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "NetBar",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.13.1",
            .credits: NSAttributedString(
                string: "A local menu bar network monitor for macOS.",
                attributes: [.font: NSFont.systemFont(ofSize: 12)]
            )
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func showPreferences(_ sender: Any?) {
        preferencesWindowController.show()
    }

    @objc private func showNetworkWindow(_ sender: Any?) {
        statusBarController?.showDetailsWindow()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        Task { @MainActor in
            await updater.checkForUpdates(isManual: true)
            preferencesWindowController.show()
        }
    }

    private func configurePreferenceObservers() {
        appPreferences.$showsDockIcon
            .sink { [weak self] _ in
                self?.applyActivationPolicy()
            }
            .store(in: &cancellables)

        appPreferences.$language
            .sink { [weak self] _ in
                self?.configureMainMenu()
            }
            .store(in: &cancellables)

        appPreferences.$appearanceMode
            .sink { [weak self] _ in
                self?.applyAppAppearance()
            }
            .store(in: &cancellables)
    }

    private func applyActivationPolicy() {
        NSApplication.shared.setActivationPolicy(appPreferences.showsDockIcon ? .regular : .accessory)
    }

    private func applyAppAppearance() {
        let appearance = appPreferences.appearanceMode.nsAppearance
        NSApplication.shared.appearance = appearance
        NSApplication.shared.windows.forEach { window in
            window.appearance = appearance
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        appMenu.addItem(targetedMenuItem(title: text("关于 NetBar", "About NetBar"), action: #selector(showAbout(_:))))
        appMenu.addItem(.separator())
        appMenu.addItem(targetedMenuItem(title: text("偏好设置...", "Preferences..."), action: #selector(showPreferences(_:)), keyEquivalent: ","))
        appMenu.addItem(targetedMenuItem(title: text("检查更新...", "Check for Updates..."), action: #selector(checkForUpdates(_:))))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: text("隐藏 NetBar", "Hide NetBar"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: text("隐藏其他", "Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"))
        appMenu.items.last?.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(NSMenuItem(title: text("全部显示", "Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: text("退出 NetBar", "Quit NetBar"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: text("窗口", "Window"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        windowMenu.addItem(targetedMenuItem(title: text("流量窗口", "Traffic Window"), action: #selector(showNetworkWindow(_:)), keyEquivalent: "0"))
        windowMenu.addItem(NSMenuItem(title: text("最小化", "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: text("缩放", "Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        NSApplication.shared.windowsMenu = windowMenu

        NSApplication.shared.mainMenu = mainMenu
    }

    private func targetedMenuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func text(_ simplifiedChinese: String, _ english: String) -> String {
        appPreferences.text(simplifiedChinese, english)
    }
}
