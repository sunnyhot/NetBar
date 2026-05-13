import AppKit
import SwiftUI

@MainActor
final class DetailsWindowController: NSObject, NSWindowDelegate {
    private let monitor: NetworkMonitor
    private let appPreferences: AppPreferences
    private let openPreferences: () -> Void
    private var window: NSWindow?
    private let defaultWindowSize = NSSize(width: 520, height: 680)
    private let minimumWindowSize = NSSize(width: 460, height: 500)

    /// Auto-dismiss after this many seconds without user interaction.
    private static let autoDismissInterval: TimeInterval = 30
    private var autoDismissTimer: Timer?
    private var localEventMonitor: Any?

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
        resetAutoDismissTimer()
    }

    private func makeWindowIfNeeded() -> NSWindow {
        if let window {
            return window
        }

        let detailsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        detailsWindow.title = "NetBar 网络流量"
        detailsWindow.isReleasedWhenClosed = false
        detailsWindow.minSize = minimumWindowSize
        detailsWindow.delegate = self
        detailsWindow.contentViewController = NSHostingController(
            rootView: NetworkPopoverView(
                monitor: monitor,
                appPreferences: appPreferences,
                openPreferences: openPreferences
            )
        )
        detailsWindow.collectionBehavior = [.moveToActiveSpace]

        // Ensure mouse-moved events are delivered so we can track hover activity
        detailsWindow.acceptsMouseMovedEvents = true

        window = detailsWindow
        return detailsWindow
    }

    // MARK: - Auto-Dismiss

    private func resetAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoDismissInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.autoDismiss()
            }
        }

        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
                .mouseMoved, .leftMouseDown, .rightMouseDown,
                .keyDown, .scrollWheel
            ]) { [weak self] event in
                Task { @MainActor in
                    self?.handleUserEvent(event)
                }
                return event
            }
        }
    }

    private func handleUserEvent(_ event: NSEvent) {
        guard let window, window.isVisible else { return }
        // Only reset for events within our window
        if event.window === window {
            resetAutoDismissTimer()
        }
    }

    private func autoDismiss() {
        guard let window, window.isVisible else { return }
        window.orderOut(nil)
        invalidateAutoDismiss()
    }

    private func invalidateAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            invalidateAutoDismiss()
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
