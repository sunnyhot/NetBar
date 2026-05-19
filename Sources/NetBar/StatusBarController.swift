import AppKit
import Combine
import SwiftUI

@MainActor
final class GooglyEyesClickMonitor {
    typealias MonitorInstaller = (@escaping () -> Void) -> Any?

    private static let mouseClickEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

    private let addGlobalMonitor: MonitorInstaller
    private let addLocalMonitor: MonitorInstaller
    private let removeMonitor: (Any) -> Void
    private var monitorTokens: [Any] = []
    private var onClick: (() -> Void)?
    private var isActive = false

    init(
        addGlobalMonitor: MonitorInstaller? = nil,
        addLocalMonitor: MonitorInstaller? = nil,
        removeMonitor: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
    ) {
        self.addGlobalMonitor = addGlobalMonitor ?? { handler in
            NSEvent.addGlobalMonitorForEvents(matching: Self.mouseClickEvents) { _ in
                Task { @MainActor in
                    handler()
                }
            }
        }
        self.addLocalMonitor = addLocalMonitor ?? { handler in
            NSEvent.addLocalMonitorForEvents(matching: Self.mouseClickEvents) { event in
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

    func setActive(_ active: Bool, onClick: @escaping () -> Void = {}) {
        if active {
            self.onClick = onClick
            guard !isActive else { return }
            isActive = true
            installMonitors()
        } else {
            guard isActive else { return }
            isActive = false
            self.onClick = nil
            removeMonitors()
        }
    }

    private func installMonitors() {
        if let globalMonitor = addGlobalMonitor({ [weak self] in self?.handleClick() }) {
            monitorTokens.append(globalMonitor)
        }
        if let localMonitor = addLocalMonitor({ [weak self] in self?.handleClick() }) {
            monitorTokens.append(localMonitor)
        }
    }

    private func removeMonitors() {
        monitorTokens.forEach(removeMonitor)
        monitorTokens.removeAll()
    }

    private func handleClick() {
        onClick?()
    }
}

@MainActor
final class StatusBarController {
    private let monitor: NetworkMonitor
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let customCharacterStore: CustomCharacterStore
    private let powerStateManager: PowerStateManager
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
    private var googlyEyesTimer: Timer?
    private var googlyEyesState: GooglyEyesRenderState?
    private var blinkResetTask: Task<Void, Never>?
    private let googlyEyesClickMonitor = GooglyEyesClickMonitor()
    private var renderCoalesceTimer: Timer?
    private var needsRender = false
    private var renderedImageCache: [(signature: StatusBarRenderSignature, image: NSImage)] = []
    private static let renderedImageCacheLimit = 12

    init(
        monitor: NetworkMonitor,
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        customCharacterStore: CustomCharacterStore,
        powerStateManager: PowerStateManager,
        openPreferences: @escaping () -> Void,
        showAbout: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.settings = settings
        self.appPreferences = appPreferences
        self.customCharacterStore = customCharacterStore
        self.powerStateManager = powerStateManager
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

    deinit {
        googlyEyesTimer?.invalidate()
        renderCoalesceTimer?.invalidate()
        blinkResetTask?.cancel()
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
            .removeDuplicates()
            .sink { [weak self] _ in
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

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.pauseGooglyEyesTimer()
            }
        }
        nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.resumeGooglyEyesTimer()
            }
        }

        powerStateManager.$isScreenLocked
            .removeDuplicates()
            .sink { [weak self] locked in
                Task { @MainActor in
                    self?.handleScreenLockChanged(locked)
                }
            }
            .store(in: &cancellables)

        powerStateManager.$isLowPowerMode
            .merge(with: powerStateManager.$isOnBattery)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.applyAnimationPowerState()
                }
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

    private func requestRender() {
        needsRender = true
        guard renderCoalesceTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: false) { [weak self] _ in
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
        detailsWindowController.show(anchor: anchorToMenuBar ? statusItem.button : nil)
    }

    @objc private func toggleDetailsWindow(_ sender: AnyObject?) {
        triggerGooglyEyesBlink()
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

    private var isGooglyEyesActive: Bool {
        settings.showsCat && CharacterAsset.resolve(
            id: customCharacterStore.validCharacterID(for: settings.catCharacter),
            customCharacters: customCharacterStore.characters
        ).isGooglyEyes
    }

    private func pauseGooglyEyesTimer() {
        googlyEyesTimer?.invalidate()
        googlyEyesTimer = nil
    }

    private func resumeGooglyEyesTimer() {
        guard isGooglyEyesActive, googlyEyesTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGooglyEyesState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        googlyEyesTimer = timer
    }

    private func configureGooglyEyesTracking() {
        guard isGooglyEyesActive else {
            googlyEyesTimer?.invalidate()
            googlyEyesTimer = nil
            googlyEyesState = nil
            blinkResetTask?.cancel()
            blinkResetTask = nil
            googlyEyesClickMonitor.setActive(false)
            return
        }

        refreshGooglyEyesState()
        googlyEyesClickMonitor.setActive(true) { [weak self] in
            self?.triggerGooglyEyesBlink()
        }
        guard googlyEyesTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGooglyEyesState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        googlyEyesTimer = timer
    }

    private func refreshGooglyEyesState() {
        guard isGooglyEyesActive else { return }
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
        blinkResetTask?.cancel()
        googlyEyesState = makeGooglyEyesState(isBlinking: true)
        requestRender()

        blinkResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(160))
            guard let self, self.isGooglyEyesActive else { return }
            self.googlyEyesState = self.makeGooglyEyesState(isBlinking: false)
            self.requestRender()
        }
    }

    // MARK: - Power State Animation Control

    private func handleScreenLockChanged(_ locked: Bool) {
        if locked {
            catAnimation?.setActive(false)
            googlyEyesClickMonitor.setActive(false)
            googlyEyesTimer?.invalidate()
            googlyEyesTimer = nil
        } else {
            setupCatAnimation()
        }
        requestRender()
    }

    private func applyAnimationPowerState() {
        let factor = powerStateManager.animationSpeedFactor
        catAnimation?.setSpeedMultiplier(settings.catSpeedMultiplier * factor)
    }
}
