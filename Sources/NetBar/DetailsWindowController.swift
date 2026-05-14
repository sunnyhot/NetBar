import AppKit
import SwiftUI

@MainActor
final class DetailsWindowController: NSObject, NSWindowDelegate {
    private let monitor: NetworkMonitor
    private let appPreferences: AppPreferences
    private let openPreferences: () -> Void
    private var panel: NSPanel?
    private let defaultWindowSize = NSSize(width: 520, height: 680)
    private let minimumWindowSize = NSSize(width: 460, height: 500)

    /// Auto-dismiss after this many seconds without focus.
    private static let autoDismissInterval: TimeInterval = 10
    private var autoDismissTimer: Timer?
    private var resignKeyObserver: Any?
    private var becomeKeyObserver: Any?
    private var escapeMonitor: Any?

    init(
        monitor: NetworkMonitor,
        appPreferences: AppPreferences,
        openPreferences: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.appPreferences = appPreferences
        self.openPreferences = openPreferences
    }

    func toggle(anchor: NSStatusBarButton?) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show(anchor: anchor)
    }

    func show(anchor: NSStatusBarButton? = nil) {
        monitor.refresh()

        let floatingPanel = makePanelIfNeeded()
        position(floatingPanel, near: anchor)
        NSApplication.shared.activate(ignoringOtherApps: true)
        floatingPanel.makeKeyAndOrderFront(nil)
        cancelAutoDismissTimer()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let floatingPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: defaultWindowSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        floatingPanel.title = "NetBar"
        floatingPanel.isFloatingPanel = true
        floatingPanel.level = .floating
        floatingPanel.hasShadow = true
        floatingPanel.isMovableByWindowBackground = true
        floatingPanel.isReleasedWhenClosed = false
        floatingPanel.minSize = minimumWindowSize
        floatingPanel.delegate = self
        floatingPanel.hidesOnDeactivate = false
        floatingPanel.collectionBehavior = [.moveToActiveSpace]
        floatingPanel.acceptsMouseMovedEvents = true

        // Transparent window background so rounded corners render correctly
        floatingPanel.backgroundColor = .clear
        floatingPanel.isOpaque = false

        let hostingController = NSHostingController(
            rootView: NetworkPopoverView(
                monitor: monitor,
                appPreferences: appPreferences,
                openPreferences: openPreferences
            )
        )
        floatingPanel.contentViewController = hostingController

        // Rounded corners on the hosting view
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 12
        hostingController.view.layer?.masksToBounds = true

        // Auto-dismiss when the panel loses focus
        let center = NotificationCenter.default
        resignKeyObserver = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: floatingPanel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleAutoDismiss()
            }
        }
        becomeKeyObserver = center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: floatingPanel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancelAutoDismissTimer()
            }
        }

        // Escape key closes the panel
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in
                self?.handleEscapeKey()
            }
            return event
        }

        panel = floatingPanel
        return floatingPanel
    }

    // MARK: - Auto-Dismiss on Focus Loss

    private func scheduleAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoDismissInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePanel()
            }
        }
    }

    private func cancelAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }

    private func closePanel() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func handleEscapeKey() {
        guard let panel, panel.isVisible, panel.isKeyWindow else { return }
        closePanel()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            cancelAutoDismissTimer()
        }
    }

    // MARK: - Layout

    private func position(_ window: NSWindow, near anchor: NSStatusBarButton?) {
        let screen = anchor?.window?.screen ?? window.screen ?? NSScreen.main
        guard let screen else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 10
        let minimumSize = DetailsWindowLayout.minimumSize(
            baseMinimumSize: minimumWindowSize,
            visibleFrame: visibleFrame,
            padding: padding
        )
        window.minSize = minimumSize

        let anchorFrame = anchor.flatMap { anchor in
            anchor.window?.convertToScreen(anchor.frame)
        }
        let frame = DetailsWindowLayout.frame(
            forWindowSize: window.frame.size,
            minimumSize: minimumSize,
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            padding: padding
        )

        window.setFrame(frame, display: true)
    }
}

enum DetailsWindowLayout {
    static func minimumSize(
        baseMinimumSize: NSSize,
        visibleFrame: NSRect,
        padding: CGFloat
    ) -> NSSize {
        let availableWidth = max(visibleFrame.width - padding * 2, 1)
        let availableHeight = max(visibleFrame.height - padding * 2, 1)

        return NSSize(
            width: min(baseMinimumSize.width, availableWidth),
            height: min(baseMinimumSize.height, availableHeight)
        )
    }

    static func frame(
        forWindowSize windowSize: NSSize,
        minimumSize: NSSize = .zero,
        visibleFrame: NSRect,
        anchorFrame: NSRect?,
        padding: CGFloat
    ) -> NSRect {
        let availableWidth = max(visibleFrame.width - padding * 2, 1)
        let availableHeight = max(visibleFrame.height - padding * 2, 1)
        let fittedSize = NSSize(
            width: min(max(windowSize.width, minimumSize.width), availableWidth),
            height: min(max(windowSize.height, minimumSize.height), availableHeight)
        )
        let x: CGFloat
        let y: CGFloat

        if let anchorFrame {
            x = clamp(
                anchorFrame.midX - fittedSize.width / 2,
                min: visibleFrame.minX + padding,
                max: visibleFrame.maxX - fittedSize.width - padding
            )
            y = clamp(
                anchorFrame.minY - fittedSize.height - padding,
                min: visibleFrame.minY + padding,
                max: visibleFrame.maxY - fittedSize.height - padding
            )
        } else {
            x = clamp(
                visibleFrame.midX - fittedSize.width / 2,
                min: visibleFrame.minX + padding,
                max: visibleFrame.maxX - fittedSize.width - padding
            )
            y = clamp(
                visibleFrame.midY - fittedSize.height / 2,
                min: visibleFrame.minY + padding,
                max: visibleFrame.maxY - fittedSize.height - padding
            )
        }

        return NSRect(origin: CGPoint(x: x, y: y), size: fittedSize)
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(value, maximum))
    }
}
