import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController {
    private let monitor: NetworkMonitor
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let openPreferences: () -> Void
    private let showAbout: () -> Void
    private let statusItem: NSStatusItem
    private let detailsWindowController: DetailsWindowController
    private var cancellables: Set<AnyCancellable> = []
    private var lastRenderSignature: StatusBarRenderSignature?
    private var catAnimation: RunCatAnimation?
    private var currentCatFrameIndex: Int?
    private var currentCatCharacter: RunCatCharacter = RunCatCharacter.defaultCat
    private var lastMouseLocation: NSPoint = .zero
    private var mouseTrackingEnabled: Bool = false

    init(
        monitor: NetworkMonitor,
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        openPreferences: @escaping () -> Void,
        showAbout: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.settings = settings
        self.appPreferences = appPreferences
        self.openPreferences = openPreferences
        self.showAbout = showAbout
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.detailsWindowController = DetailsWindowController(
            monitor: monitor,
            appPreferences: appPreferences,
            openPreferences: openPreferences
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
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .noImage
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
                self?.setupCatAnimation()
                self?.updateStatusItem()
            }
        }
        .store(in: &cancellables)

        setupCatAnimation()
        setupMouseTracking()
    }

    private func setupCatAnimation() {
        let character = RunCatCharacter.byId(settings.catCharacter)
        
        if settings.showsCat {
            if catAnimation == nil {
                catAnimation = RunCatAnimation(
                    character: character,
                    speedMultiplier: settings.catSpeedMultiplier,
                    onFrameChange: { [weak self] frameIndex in
                        self?.currentCatFrameIndex = frameIndex
                        self?.updateStatusItem()
                    }
                )
                catAnimation?.onCharacterChange = { [weak self] newCharacter in
                    self?.currentCatCharacter = newCharacter
                    self?.settings.catCharacter = newCharacter.id
                }
                currentCatCharacter = character
            } else if character != currentCatCharacter {
                // Character changed, recreate animation
                catAnimation?.setActive(false)
                catAnimation = RunCatAnimation(
                    character: character,
                    speedMultiplier: settings.catSpeedMultiplier,
                    onFrameChange: { [weak self] frameIndex in
                        self?.currentCatFrameIndex = frameIndex
                        self?.updateStatusItem()
                    }
                )
                catAnimation?.onCharacterChange = { [weak self] newCharacter in
                    self?.currentCatCharacter = newCharacter
                    self?.settings.catCharacter = newCharacter.id
                }
                currentCatCharacter = character
            } else {
                // Same character, just update speed
                catAnimation?.setSpeedMultiplier(settings.catSpeedMultiplier)
            }
            // Update mouse tracking based on character
            setupMouseTracking()
            // Configure rotation
            let poolIds = settings.catRotationPool.split(separator: ",").map(String.init)
            let pool = poolIds.isEmpty ? [] : poolIds.compactMap { id in RunCatCharacter.allCharacters.first { $0.id == id } }
            catAnimation?.configureRotation(enabled: settings.catRotationEnabled, intervalMinutes: settings.catRotationIntervalMinutes, pool: pool)
            catAnimation?.setActive(true)
        } else {
            catAnimation?.setActive(false)
            catAnimation = nil
            currentCatFrameIndex = nil
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let appearanceName = button.effectiveAppearance.name.rawValue

        // Update cat animation speed based on network speed
        if settings.showsCat {
            catAnimation?.updateNetworkSpeed(
                totalBytesPerSecond: UInt64(monitor.snapshot.uploadBytesPerSecond + monitor.snapshot.downloadBytesPerSecond)
            )
            if currentCatFrameIndex == nil {
                currentCatFrameIndex = 0
            }
        }

        let signature = StatusBarDisplayRenderer.signature(
            snapshot: monitor.snapshot,
            settings: settings,
            appearanceName: appearanceName,
            catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
            mouseLocation: settings.catCharacter == "googly_cat" ? lastMouseLocation : nil
        )
        guard signature != lastRenderSignature else { return }

        let presentation = signature.presentation
        statusItem.length = presentation.width

        let scale = button.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let image = StatusBarDisplayRenderer.image(
            snapshot: monitor.snapshot,
            settings: settings,
            scale: scale,
            catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
            mouseLocation: settings.catCharacter == "googly_cat" ? lastMouseLocation : nil,
            statusItemBounds: button.bounds
        )
        button.attributedTitle = NSAttributedString(string: "")
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.image = image

        lastRenderSignature = signature
    }

    func showDetailsWindow(anchorToMenuBar: Bool = false) {
        detailsWindowController.show(anchor: anchorToMenuBar ? statusItem.button : nil)
    }

    @objc private func toggleDetailsWindow(_ sender: AnyObject?) {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }
        detailsWindowController.toggle(anchor: statusItem.button)
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: text("打开流量窗口", "Open Traffic Window"),
            action: #selector(openDetailsFromMenu(_:)),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: text("偏好设置...", "Preferences..."),
            action: #selector(openPreferencesFromMenu(_:)),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: text("关于 NetBar", "About NetBar"),
            action: #selector(showAboutFromMenu(_:)),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: text("退出 NetBar", "Quit NetBar"),
            action: #selector(quitFromMenu(_:)),
            keyEquivalent: "q"
        ))
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openDetailsFromMenu(_ sender: AnyObject?) {
        showDetailsWindow()
    }

    @objc private func openPreferencesFromMenu(_ sender: AnyObject?) {
        openPreferences()
    }

    @objc private func showAboutFromMenu(_ sender: AnyObject?) {
        showAbout()
    }

    @objc private func quitFromMenu(_ sender: AnyObject?) {
        NSApplication.shared.terminate(nil)
    }

    private func text(_ simplifiedChinese: String, _ english: String) -> String {
        appPreferences.text(simplifiedChinese, english)
    }

    private func setupMouseTracking() {
        // Check if the current character is googly_cat
        let isGooglyCat = settings.catCharacter == "googly_cat" && settings.showsCat

        if isGooglyCat && !mouseTrackingEnabled {
            // Enable mouse tracking
            mouseTrackingEnabled = true
            lastMouseLocation = NSEvent.mouseLocation

            NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.handleMouseMove(event)
            }
        } else if !isGooglyCat && mouseTrackingEnabled {
            // Disable mouse tracking (would need to store the monitor to remove it properly)
            mouseTrackingEnabled = false
        }
    }

    private func handleMouseMove(_ event: NSEvent) {
        let newLocation = event.locationInWindow
        // Quantize mouse position to avoid excessive updates (round to 10px grid)
        let newQuantized = QuantizedMousePosition(x: Int(newLocation.x / 10), y: Int(newLocation.y / 10))
        let lastQuantized = QuantizedMousePosition(x: Int(lastMouseLocation.x / 10), y: Int(lastMouseLocation.y / 10))

        if newQuantized != lastQuantized {
            lastMouseLocation = newLocation
            updateStatusItem()
        }
    }
}
