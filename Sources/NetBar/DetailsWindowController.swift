import AppKit
import SwiftUI

enum DetailsWindowDismissalPolicy {
    static let autoDismissInterval: TimeInterval = 10

    static func shouldDismissClick(panelFrame: NSRect?, clickLocation: CGPoint) -> Bool {
        guard let panelFrame else { return false }
        return !panelFrame.contains(clickLocation)
    }
}

@MainActor
final class DetailsWindowOutsideClickMonitor {
    typealias ClickHandler = (CGPoint) -> Void
    typealias MonitorInstaller = (@escaping ClickHandler) -> Any?

    private static let mouseClickEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

    private let panelFrameProvider: () -> NSRect?
    private let addGlobalMonitor: MonitorInstaller
    private let addLocalMonitor: MonitorInstaller
    private let removeMonitor: (Any) -> Void
    private var monitorTokens: [Any] = []
    private var onOutsideClick: (() -> Void)?
    private var isActive = false

    init(
        panelFrameProvider: @escaping () -> NSRect?,
        addGlobalMonitor: MonitorInstaller? = nil,
        addLocalMonitor: MonitorInstaller? = nil,
        removeMonitor: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
    ) {
        self.panelFrameProvider = panelFrameProvider
        self.addGlobalMonitor = addGlobalMonitor ?? { handler in
            NSEvent.addGlobalMonitorForEvents(matching: Self.mouseClickEvents) { _ in
                Task { @MainActor in
                    handler(NSEvent.mouseLocation)
                }
            }
        }
        self.addLocalMonitor = addLocalMonitor ?? { handler in
            NSEvent.addLocalMonitorForEvents(matching: Self.mouseClickEvents) { event in
                Task { @MainActor in
                    handler(NSEvent.mouseLocation)
                }
                return event
            }
        }
        self.removeMonitor = removeMonitor
    }

    func setActive(_ active: Bool, onOutsideClick: @escaping () -> Void = {}) {
        if active {
            self.onOutsideClick = onOutsideClick
            guard !isActive else { return }
            isActive = true
            installMonitors()
        } else {
            guard isActive else { return }
            isActive = false
            self.onOutsideClick = nil
            removeMonitors()
        }
    }

    private func installMonitors() {
        if let globalMonitor = addGlobalMonitor({ [weak self] location in
            self?.handleClick(at: location)
        }) {
            monitorTokens.append(globalMonitor)
        }
        if let localMonitor = addLocalMonitor({ [weak self] location in
            self?.handleClick(at: location)
        }) {
            monitorTokens.append(localMonitor)
        }
    }

    private func removeMonitors() {
        monitorTokens.forEach(removeMonitor)
        monitorTokens.removeAll()
    }

    private func handleClick(at location: CGPoint) {
        guard DetailsWindowDismissalPolicy.shouldDismissClick(
            panelFrame: panelFrameProvider(),
            clickLocation: location
        ) else { return }

        onOutsideClick?()
    }
}

@MainActor
final class DetailsWindowController: NSObject, NSWindowDelegate {
    private let monitor: NetworkMonitor
    private let appPreferences: AppPreferences
    private let openPreferences: () -> Void
    private var panel: NSPanel?
    private let defaultWindowSize = NSSize(width: 440, height: 720)
    private let minimumWindowSize = NSSize(width: 440, height: 500)

    private var autoDismissTimer: Timer?
    private var resignKeyObserver: Any?
    private var becomeKeyObserver: Any?
    private var escapeMonitor: Any?
    private lazy var outsideClickMonitor = DetailsWindowOutsideClickMonitor { [weak self] in
        self?.panel?.frame
    }

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
            closePanel()
            return
        }
        show(anchor: anchor)
    }

    func show(anchor: NSStatusBarButton? = nil) {
        monitor.isApplicationTrafficVisible = true
        monitor.refresh()

        let floatingPanel = makePanelIfNeeded()
        position(floatingPanel, near: anchor)
        NSApplication.shared.activate(ignoringOtherApps: true)
        floatingPanel.makeKeyAndOrderFront(nil)
        outsideClickMonitor.setActive(true) { [weak self] in
            self?.closePanel()
        }
        scheduleAutoDismiss()
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
        floatingPanel.isMovableByWindowBackground = false
        floatingPanel.isReleasedWhenClosed = false
        floatingPanel.minSize = minimumWindowSize
        floatingPanel.maxSize = defaultWindowSize
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
        hostingController.view.layer?.cornerRadius = 16
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
                self?.scheduleAutoDismiss()
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
            withTimeInterval: DetailsWindowDismissalPolicy.autoDismissInterval,
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
        cancelAutoDismissTimer()
        outsideClickMonitor.setActive(false)
        panel.orderOut(nil)
        monitor.isApplicationTrafficVisible = false
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
        let maximumSize = DetailsWindowLayout.maximumSize(
            fixedWidth: defaultWindowSize.width,
            minimumSize: minimumSize,
            visibleFrame: visibleFrame,
            padding: padding
        )
        window.minSize = minimumSize
        window.maxSize = maximumSize
        let targetHeight = min(max(window.frame.height, minimumSize.height), maximumSize.height)
        let targetSize = NSSize(width: maximumSize.width, height: targetHeight)

        let anchorFrame = anchor.flatMap { anchor in
            anchor.window?.convertToScreen(anchor.frame)
        }
        let frame = DetailsWindowLayout.frame(
            forWindowSize: targetSize,
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

    static func maximumSize(
        fixedWidth: CGFloat,
        minimumSize: NSSize,
        visibleFrame: NSRect,
        padding: CGFloat
    ) -> NSSize {
        let availableWidth = max(visibleFrame.width - padding * 2, 1)
        let availableHeight = max(visibleFrame.height - padding, minimumSize.height)

        return NSSize(
            width: min(fixedWidth, availableWidth),
            height: max(minimumSize.height, availableHeight)
        )
    }

    static func frame(
        forWindowSize windowSize: NSSize,
        minimumSize: NSSize = .zero,
        visibleFrame: NSRect,
        anchorFrame: NSRect?,
        padding: CGFloat,
        anchorGap: CGFloat = 0
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
            let topEdge = min(anchorFrame.minY - anchorGap, visibleFrame.maxY)
            x = clamp(
                anchorFrame.midX - fittedSize.width / 2,
                min: visibleFrame.minX + padding,
                max: visibleFrame.maxX - fittedSize.width - padding
            )
            y = clamp(
                topEdge - fittedSize.height,
                min: visibleFrame.minY + padding,
                max: topEdge - fittedSize.height
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
