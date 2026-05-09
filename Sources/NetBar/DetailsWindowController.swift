import AppKit
import SwiftUI

@MainActor
final class DetailsWindowController: NSObject, NSWindowDelegate {
    private let monitor: NetworkMonitor
    private let settings: StatusBarSettings
    private let updater: AppUpdater
    private var window: NSWindow?
    private let windowSize = NSSize(width: 460, height: 660)

    init(monitor: NetworkMonitor, settings: StatusBarSettings, updater: AppUpdater) {
        self.monitor = monitor
        self.settings = settings
        self.updater = updater
    }

    func toggle(anchor: NSStatusBarButton?) {
        if let window, window.isVisible {
            window.orderOut(nil)
            return
        }
        show(anchor: anchor)
    }

    func show(anchor: NSStatusBarButton? = nil) {
        monitor.refresh()

        let detailsWindow = makeWindowIfNeeded()
        position(detailsWindow, near: anchor)
        NSApplication.shared.activate(ignoringOtherApps: true)
        detailsWindow.makeKeyAndOrderFront(nil)
    }

    private func makeWindowIfNeeded() -> NSWindow {
        if let window {
            return window
        }

        let detailsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        detailsWindow.title = "NetBar 网络流量"
        detailsWindow.isReleasedWhenClosed = false
        detailsWindow.delegate = self
        detailsWindow.contentViewController = NSHostingController(
            rootView: NetworkPopoverView(monitor: monitor, settings: settings, updater: updater)
        )
        detailsWindow.collectionBehavior = [.moveToActiveSpace]

        window = detailsWindow
        return detailsWindow
    }

    private func position(_ window: NSWindow, near anchor: NSStatusBarButton?) {
        guard
            let anchor,
            let anchorWindow = anchor.window,
            let screen = anchorWindow.screen
        else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let anchorFrame = anchorWindow.convertToScreen(anchor.frame)
        let padding: CGFloat = 10
        let x = clamp(
            anchorFrame.midX - windowSize.width / 2,
            min: visibleFrame.minX + padding,
            max: visibleFrame.maxX - windowSize.width - padding
        )
        let y = clamp(
            anchorFrame.minY - windowSize.height - padding,
            min: visibleFrame.minY + padding,
            max: visibleFrame.maxY - windowSize.height - padding
        )

        window.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: windowSize), display: true)
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(value, maximum))
    }
}
