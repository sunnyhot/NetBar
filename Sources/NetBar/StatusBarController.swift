import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController {
    private let monitor: NetworkMonitor
    private let settings: StatusBarSettings
    private let updater: AppUpdater
    private let statusItem: NSStatusItem
    private let detailsWindowController: DetailsWindowController
    private var cancellables: Set<AnyCancellable> = []

    init(monitor: NetworkMonitor, settings: StatusBarSettings, updater: AppUpdater) {
        self.monitor = monitor
        self.settings = settings
        self.updater = updater
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.detailsWindowController = DetailsWindowController(
            monitor: monitor,
            settings: settings,
            updater: updater
        )

        configureStatusItem()
        configureObservers()
        monitor.start()
        updateStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.action = #selector(toggleDetailsWindow(_:))
        button.target = self
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.title = ""
        button.wantsLayer = false
        button.toolTip = "NetBar 网络流量，点击查看明细"
    }

    private func configureObservers() {
        monitor.$snapshot.sink { [weak self] _ in
            self?.updateStatusItem()
        }
        .store(in: &cancellables)

        settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let image = StatusBarImageRenderer.image(snapshot: monitor.snapshot, settings: settings)
        statusItem.length = image.size.width
        button.image = image
    }

    func showDetailsWindow(anchorToMenuBar: Bool = false) {
        detailsWindowController.show(anchor: anchorToMenuBar ? statusItem.button : nil)
    }

    @objc private func toggleDetailsWindow(_ sender: AnyObject?) {
        detailsWindowController.toggle(anchor: statusItem.button)
    }
}
