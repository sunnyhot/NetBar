import AppKit
import Combine
import SwiftUI

@MainActor
final class GooglyEyesClickMonitor {
    typealias MonitorInstaller = (@escaping () -> Void) -> Any?

    private static let mouseClickEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    static let mouseUpEvents: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .otherMouseUp]

    private let addGlobalDownMonitor: MonitorInstaller
    private let addLocalDownMonitor: MonitorInstaller
    private let addGlobalUpMonitor: MonitorInstaller
    private let addLocalUpMonitor: MonitorInstaller
    private let removeMonitor: (Any) -> Void
    private var monitorTokens: [Any] = []
    private var onMouseDown: (() -> Void)?
    private var onMouseUp: (() -> Void)?
    private var isActive = false

    init(
        addGlobalDownMonitor: MonitorInstaller? = nil,
        addLocalDownMonitor: MonitorInstaller? = nil,
        addGlobalUpMonitor: MonitorInstaller? = nil,
        addLocalUpMonitor: MonitorInstaller? = nil,
        removeMonitor: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
    ) {
        self.addGlobalDownMonitor = addGlobalDownMonitor ?? { handler in
            NSEvent.addGlobalMonitorForEvents(matching: Self.mouseClickEvents) { _ in
                Task { @MainActor in
                    handler()
                }
            }
        }
        self.addLocalDownMonitor = addLocalDownMonitor ?? { handler in
            NSEvent.addLocalMonitorForEvents(matching: Self.mouseClickEvents) { event in
                Task { @MainActor in
                    handler()
                }
                return event
            }
        }
        self.addGlobalUpMonitor = addGlobalUpMonitor ?? { handler in
            NSEvent.addGlobalMonitorForEvents(matching: Self.mouseUpEvents) { _ in
                Task { @MainActor in
                    handler()
                }
            }
        }
        self.addLocalUpMonitor = addLocalUpMonitor ?? { handler in
            NSEvent.addLocalMonitorForEvents(matching: Self.mouseUpEvents) { event in
                Task { @MainActor in
                    handler()
                }
                return event
            }
        }
        self.removeMonitor = removeMonitor
    }

    deinit {
        monitorTokens.forEach(removeMonitor)
    }

    func setActive(_ active: Bool, onMouseDown: @escaping () -> Void = {}, onMouseUp: @escaping () -> Void = {}) {
        if active {
            self.onMouseDown = onMouseDown
            self.onMouseUp = onMouseUp
            guard !isActive else { return }
            isActive = true
            installMonitors()
        } else {
            guard isActive else { return }
            isActive = false
            self.onMouseDown = nil
            self.onMouseUp = nil
            removeMonitors()
        }
    }

    private func installMonitors() {
        if let globalDown = addGlobalDownMonitor({ [weak self] in self?.handleMouseDown() }) {
            monitorTokens.append(globalDown)
        }
        if let localDown = addLocalDownMonitor({ [weak self] in self?.handleMouseDown() }) {
            monitorTokens.append(localDown)
        }
        if let globalUp = addGlobalUpMonitor({ [weak self] in self?.handleMouseUp() }) {
            monitorTokens.append(globalUp)
        }
        if let localUp = addLocalUpMonitor({ [weak self] in self?.handleMouseUp() }) {
            monitorTokens.append(localUp)
        }
    }

    private func removeMonitors() {
        monitorTokens.forEach(removeMonitor)
        monitorTokens.removeAll()
    }

    private func handleMouseDown() {
        onMouseDown?()
    }

    private func handleMouseUp() {
        onMouseUp?()
    }
}

private struct DisplaySpeeds: Equatable {
    let download: Double
    let upload: Double
}

@MainActor
final class StatusBarController {
    private let monitor: NetworkMonitor
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let customCharacterStore: CustomCharacterStore
    private let powerObserver: SystemPowerObserver
    private let openPreferences: () -> Void
    private let showAbout: () -> Void
    private let statusItem: NSStatusItem
    private let detailsWindowController: DetailsWindowController
    private var cancellables: Set<AnyCancellable> = []
    private var lastRenderSignature: StatusBarRenderSignature?
    private var lastColorTimeBucket: Int?  // Tracked separately for color pipeline decoupling
    private var catAnimation: RunCatAnimation?
    private var currentCatFrameIndex: Int?
    private var currentCatCharacter: CharacterAsset = CharacterAsset(builtIn: .defaultCat)
    private var mouseMovedMonitorGlobal: Any?
    private var mouseMovedMonitorLocal: Any?
    private var googlyEyesState: GooglyEyesRenderState?
    private let googlyEyesClickMonitor = GooglyEyesClickMonitor()
    private var lastPolledMouseLocation: CGPoint?
    private var renderCoalesceTimer: Timer?
    private var needsRender = false
    private var renderedImageCache: [(signature: StatusBarRenderSignature, image: NSImage)] = []
    private static let renderedImageCacheLimit = 12
    private var renderCoalesceInterval: TimeInterval = 1.0 / 15.0

    init(
        monitor: NetworkMonitor,
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        customCharacterStore: CustomCharacterStore,
        powerObserver: SystemPowerObserver,
        openPreferences: @escaping () -> Void,
        showAbout: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.settings = settings
        self.appPreferences = appPreferences
        self.customCharacterStore = customCharacterStore
        self.powerObserver = powerObserver
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
        configureDetailsWindowObserver()
        monitor.start()
        updateStatusItem()
    }

    deinit {
        if let global = mouseMovedMonitorGlobal {
            NSEvent.removeMonitor(global)
        }
        if let local = mouseMovedMonitorLocal {
            NSEvent.removeMonitor(local)
        }
        renderCoalesceTimer?.invalidate()
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
        monitor.$snapshot
            .map { snapshot in
                DisplaySpeeds(download: snapshot.downloadBytesPerSecond, upload: snapshot.uploadBytesPerSecond)
            }
            .removeDuplicates()
            .sink { [weak self] speeds in
                let total = speeds.download + speeds.upload
                if total < 100 {
                    self?.renderCoalesceInterval = 1.0
                } else if total < 10_000 {
                    self?.renderCoalesceInterval = 1.0 / 5.0
                } else {
                    self?.renderCoalesceInterval = 1.0 / 15.0
                }
                self?.requestRender()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupCatAnimation()
                self?.requestRender()
            }
            .store(in: &cancellables)

        customCharacterStore.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupCatAnimation()
                self?.requestRender()
            }
            .store(in: &cancellables)

        appPreferences.$appearanceMode.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastRenderSignature = nil
                self?.lastColorTimeBucket = nil
                self?.requestRender()
            }
        }
        .store(in: &cancellables)

        powerObserver.$isScreenLocked
            .removeDuplicates()
            .sink { [weak self] isLocked in
                guard let self else { return }
                if isLocked {
                    self.catAnimation?.pauseForScreenLock()
                    self.pauseGooglyEyesTracking()
                    self.monitor.stop()
                } else {
                    self.monitor.start()
                    self.catAnimation?.resumeFromScreenLock()
                    self.configureGooglyEyesTracking()
                    self.lastRenderSignature = nil
                    self.requestRender()
                }
            }
            .store(in: &cancellables)

        powerObserver.$isLowPowerMode
            .removeDuplicates()
            .sink { [weak self] isLowPower in
                self?.monitor.setPowerSaveMode(isLowPower)
            }
            .store(in: &cancellables)

        setupCatAnimation()
    }

    private func setupCatAnimation() {
        let validCharacterID = customCharacterStore.validCharacterID(for: settings.catCharacter)
        if validCharacterID != settings.catCharacter {
            settings.catCharacter = validCharacterID
        }
        let character = CharacterAsset.resolve(
            id: validCharacterID,
            customCharacters: customCharacterStore.characters
        )
        
        if settings.showsCat {
            if catAnimation == nil {
                catAnimation = RunCatAnimation(
                    character: character,
                    speedMultiplier: settings.catSpeedMultiplier,
                    onFrameChange: { [weak self] frameIndex in
                        self?.currentCatFrameIndex = frameIndex
                        self?.requestRender()
                    }
                )
                catAnimation?.onCharacterChange = { [weak self] newCharacter in
                    self?.currentCatCharacter = CharacterAsset(builtIn: newCharacter)
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
                        self?.requestRender()
                    }
                )
                catAnimation?.onCharacterChange = { [weak self] newCharacter in
                    self?.currentCatCharacter = CharacterAsset(builtIn: newCharacter)
                    self?.settings.catCharacter = newCharacter.id
                }
                currentCatCharacter = character
            } else {
                // Same character, just update speed
                catAnimation?.setSpeedMultiplier(settings.catSpeedMultiplier)
            }
            // Configure rotation
            let poolIds = settings.catRotationPool.split(separator: ",").map(String.init)
            let pool = poolIds.isEmpty ? [] : poolIds.compactMap { id in RunCatCharacter.allCharacters.first { $0.id == id } }
            catAnimation?.configureRotation(
                enabled: settings.catRotationEnabled && !character.isCustom,
                intervalMinutes: settings.catRotationIntervalMinutes,
                pool: pool
            )
            catAnimation?.setActive(true)
            configureGooglyEyesTracking()
        } else {
            catAnimation?.setActive(false)
            catAnimation = nil
            currentCatFrameIndex = nil
            configureGooglyEyesTracking()
        }
    }

    private var currentRenderCoalesceInterval: TimeInterval {
        if isGooglyEyesActive {
            return 1.0 / 15.0
        }
        return renderCoalesceInterval
    }

    private func requestRender() {
        needsRender = true
        guard renderCoalesceTimer == nil else { return }
        let timer = Timer(timeInterval: currentRenderCoalesceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flushRender()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        renderCoalesceTimer = timer
    }

    private func flushRender() {
        renderCoalesceTimer = nil
        guard needsRender else { return }
        needsRender = false
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard !powerObserver.isScreenLocked else { return }
        guard let button = statusItem.button else { return }
        let appearanceName = button.effectiveAppearance.name.rawValue
        let activeGooglyEyesState = activeGooglyEyesRenderState()

        // Update cat animation speed based on network speed
        if settings.showsCat {
            catAnimation?.updateNetworkSpeed(
                totalBytesPerSecond: UInt64(monitor.snapshot.uploadBytesPerSecond + monitor.snapshot.downloadBytesPerSecond)
            )
            if currentCatFrameIndex == nil {
                currentCatFrameIndex = 0
            }
        }

        // Color pipeline: compute time bucket independently from position tracking
        let currentColorBucket = StatusBarDisplayRenderer.colorTimeBucket(forMode: settings.catColorMode)

        let signature = StatusBarDisplayRenderer.signature(
            snapshot: monitor.snapshot,
            settings: settings,
            appearanceName: appearanceName,
            customCharacterStore: customCharacterStore,
            catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
            googlyEyesState: activeGooglyEyesState
        )
        guard signature != lastRenderSignature else {
            lastColorTimeBucket = currentColorBucket
            return
        }

        let presentation = signature.presentation
        statusItem.length = presentation.width

        let image: NSImage
        if let cached = renderedImageCache.first(where: { $0.signature == signature })?.image {
            image = cached
        } else {
            let scale = button.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            image = StatusBarDisplayRenderer.image(
                snapshot: monitor.snapshot,
                settings: settings,
                scale: scale,
                customCharacterStore: customCharacterStore,
                catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
                googlyEyesState: activeGooglyEyesState
            )
            renderedImageCache.append((signature: signature, image: image))
            if renderedImageCache.count > Self.renderedImageCacheLimit {
                renderedImageCache.removeFirst()
            }
        }
        button.attributedTitle = NSAttributedString(string: "")
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.image = image

        lastRenderSignature = signature
        lastColorTimeBucket = currentColorBucket
    }

    func showDetailsWindow(anchorToMenuBar: Bool = false) {
        monitor.resumeApplicationTrafficSampling()
        detailsWindowController.show(anchor: anchorToMenuBar ? statusItem.button : nil)
    }

    private var applicationTrafficPauseTask: Task<Void, Never>?

    private func configureDetailsWindowObserver() {
        detailsWindowController.onWindowClosed = { [weak self] in
            self?.scheduleApplicationTrafficPause()
        }
    }

    private func scheduleApplicationTrafficPause() {
        applicationTrafficPauseTask?.cancel()
        applicationTrafficPauseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !self.detailsWindowController.isVisible else { return }
            self.monitor.pauseApplicationTrafficSampling()
        }
    }

    @objc private func toggleDetailsWindow(_ sender: AnyObject?) {
        if NSApplication.shared.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }
        if detailsWindowController.isVisible {
            detailsWindowController.toggle(anchor: statusItem.button)
        } else {
            applicationTrafficPauseTask?.cancel()
            monitor.resumeApplicationTrafficSampling()
            detailsWindowController.toggle(anchor: statusItem.button)
        }
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

    private var isGooglyEyesActive: Bool {
        settings.showsCat && CharacterAsset.resolve(
            id: customCharacterStore.validCharacterID(for: settings.catCharacter),
            customCharacters: customCharacterStore.characters
        ).isGooglyEyes
    }

    private func pauseGooglyEyesTracking() {
        if let global = mouseMovedMonitorGlobal {
            NSEvent.removeMonitor(global)
            mouseMovedMonitorGlobal = nil
        }
        if let local = mouseMovedMonitorLocal {
            NSEvent.removeMonitor(local)
            mouseMovedMonitorLocal = nil
        }
        googlyEyesClickMonitor.setActive(false)
        lastPolledMouseLocation = nil
    }

    private func resumeGooglyEyesTracking() {
        guard isGooglyEyesActive else { return }
        
        googlyEyesClickMonitor.setActive(
            true,
            onMouseDown: { [weak self] in self?.triggerGooglyEyesBlink() },
            onMouseUp: { [weak self] in self?.endGooglyEyesBlink() }
        )
        
        guard mouseMovedMonitorGlobal == nil else { return }
        
        mouseMovedMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGooglyEyesState()
            }
        }
        
        mouseMovedMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.refreshGooglyEyesState()
            }
            return event
        }
    }

    private func configureGooglyEyesTracking() {
        guard isGooglyEyesActive else {
            pauseGooglyEyesTracking()
            googlyEyesState = nil
            return
        }

        refreshGooglyEyesState()
        resumeGooglyEyesTracking()
    }

    private func refreshGooglyEyesState() {
        guard isGooglyEyesActive else { return }

        let mouseLocation = NSEvent.mouseLocation

        // Skip if mouse moved < 1pt (position dedup)
        if let last = lastPolledMouseLocation {
            if hypot(mouseLocation.x - last.x, mouseLocation.y - last.y) < 1.0 { return }
        }
        lastPolledMouseLocation = mouseLocation

        let isBlinking = googlyEyesState?.isBlinking == true
        guard let nextState = makeGooglyEyesState(isBlinking: isBlinking) else { return }
        guard nextState != googlyEyesState else { return }
        googlyEyesState = nextState
        requestRender()
    }

    private func activeGooglyEyesRenderState() -> GooglyEyesRenderState? {
        guard isGooglyEyesActive else { return nil }
        if googlyEyesState == nil {
            googlyEyesState = makeGooglyEyesState(isBlinking: false)
        }
        return googlyEyesState
    }

    private func makeGooglyEyesState(isBlinking: Bool) -> GooglyEyesRenderState? {
        guard
            let button = statusItem.button,
            let statusItemFrame = button.window?.convertToScreen(button.frame)
        else {
            return nil
        }

        return GooglyEyesRenderState(
            mouseLocation: NSEvent.mouseLocation,
            statusItemFrame: statusItemFrame,
            isBlinking: isBlinking
        )
    }

    private func triggerGooglyEyesBlink() {
        guard isGooglyEyesActive else { return }
        googlyEyesState = makeGooglyEyesState(isBlinking: true)
        requestRender()
    }

    private func endGooglyEyesBlink() {
        guard isGooglyEyesActive else { return }
        googlyEyesState = makeGooglyEyesState(isBlinking: false)
        requestRender()
    }
}
