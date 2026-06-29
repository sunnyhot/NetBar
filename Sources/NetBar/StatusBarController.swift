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
struct StatusBarCatAnimationConfiguration: Equatable {
    let showsCat: Bool
    let catCharacter: String
    let catSpeedMultiplier: Double
    let catRotationEnabled: Bool
    let catRotationIntervalMinutes: Double
    let catRotationPool: String
    let customCharacterRevision: Int

    init(settings: StatusBarSettings, customCharacterRevision: Int) {
        self.showsCat = settings.showsCat
        self.catCharacter = settings.catCharacter
        self.catSpeedMultiplier = settings.catSpeedMultiplier
        self.catRotationEnabled = settings.catRotationEnabled
        self.catRotationIntervalMinutes = settings.catRotationIntervalMinutes
        self.catRotationPool = settings.catRotationPool
        self.customCharacterRevision = customCharacterRevision
    }
}

@MainActor
final class ApplicationTrafficVisibilityScheduler {
    private let resumeDelay: Duration
    private let pauseDelay: Duration
    private let isDetailWindowVisible: () -> Bool
    private let setApplicationTrafficVisible: (Bool) -> Void
    private var resumeTask: Task<Void, Never>?
    private var pauseTask: Task<Void, Never>?

    init(
        resumeDelay: Duration = .milliseconds(500),
        pauseDelay: Duration = .seconds(30),
        isDetailWindowVisible: @escaping () -> Bool,
        setApplicationTrafficVisible: @escaping (Bool) -> Void
    ) {
        self.resumeDelay = resumeDelay
        self.pauseDelay = pauseDelay
        self.isDetailWindowVisible = isDetailWindowVisible
        self.setApplicationTrafficVisible = setApplicationTrafficVisible
    }

    func scheduleResume() {
        pauseTask?.cancel()
        pauseTask = nil
        resumeTask?.cancel()
        let resumeDelay = self.resumeDelay
        resumeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: resumeDelay)
            guard let self, self.isDetailWindowVisible() else { return }
            self.setApplicationTrafficVisible(true)
        }
    }

    func schedulePause() {
        resumeTask?.cancel()
        resumeTask = nil
        pauseTask?.cancel()
        let pauseDelay = self.pauseDelay
        pauseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: pauseDelay)
            guard let self, !self.isDetailWindowVisible() else { return }
            self.setApplicationTrafficVisible(false)
        }
    }

    func invalidate() {
        resumeTask?.cancel()
        resumeTask = nil
        pauseTask?.cancel()
        pauseTask = nil
    }
}

@MainActor
final class StatusBarController {
    private let monitor: NetworkMonitor
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let notificationController: NetworkNotificationController
    private let petController: PetController
    private let customCharacterStore: CustomCharacterStore
    private let powerObserver: SystemPowerObserver
    private let openPreferences: () -> Void
    private let showAbout: () -> Void
    private let statusItem: NSStatusItem
    private let detailsWindowController: DetailsWindowController
    private var applicationTrafficVisibilityScheduler: ApplicationTrafficVisibilityScheduler?
    private var cancellables: Set<AnyCancellable> = []
    private var lastRenderSignature: StatusBarRenderSignature?
    private var lastColorTimeBucket: Int?  // Tracked separately for color pipeline decoupling
    private var catAnimation: RunCatAnimation?
    private var lastCatAnimationConfiguration: StatusBarCatAnimationConfiguration?
    private var currentCatFrameIndex: Int?
    private var currentCatCharacter: CharacterAsset = CharacterAsset(builtIn: .defaultCat)
    private var mouseMovedMonitorGlobal: Any?
    private var mouseMovedMonitorLocal: Any?
    private var googlyEyesState: GooglyEyesRenderState?
    private let googlyEyesClickMonitor = GooglyEyesClickMonitor()
    private var lastPolledMouseLocation: CGPoint?
    private var renderCoalesceTimer: Timer?
    private var needsRender = false
    private var pendingAnimationPlaybackCountsByCharacter: [String: UInt64] = [:]
    private var animationPlaybackFlushTimer: Timer?
    private let renderedImageCache = StatusBarRenderedImageCache(limit: 12)
    private var renderCoalesceInterval: TimeInterval = 1.0 / 15.0
    private lazy var networkIntelligenceCoordinator = NetworkIntelligenceCoordinator(
        notify: { [weak self] event, settings in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.notificationController.handle(event, settings: settings)
            }
        },
        petCue: { [weak self] event in
            self?.petController.observe(anomaly: event)
        },
        petDailySummary: { [weak self] summary in
            self?.petController.observe(todaySummary: summary)
        }
    )

    var samplingDiagnostics: NetworkSamplingDiagnostics {
        monitor.samplingDiagnostics
    }

    init(
        monitor: NetworkMonitor,
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        customCharacterStore: CustomCharacterStore,
        powerObserver: SystemPowerObserver,
        notificationController: NetworkNotificationController,
        petController: PetController,
        openPreferences: @escaping () -> Void,
        showAbout: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.settings = settings
        self.appPreferences = appPreferences
        self.notificationController = notificationController
        self.petController = petController
        self.customCharacterStore = customCharacterStore
        self.powerObserver = powerObserver
        self.openPreferences = openPreferences
        self.showAbout = showAbout
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.detailsWindowController = DetailsWindowController(
            monitor: monitor,
            appPreferences: appPreferences,
            customCharacterStore: customCharacterStore,
            openPreferences: openPreferences
        )
        let detailsWindowController = self.detailsWindowController
        self.applicationTrafficVisibilityScheduler = ApplicationTrafficVisibilityScheduler(
            isDetailWindowVisible: { [weak detailsWindowController] in
                detailsWindowController?.isVisible == true
            },
            setApplicationTrafficVisible: { [weak monitor] visible in
                monitor?.isApplicationTrafficVisible = visible
            }
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
        animationPlaybackFlushTimer?.invalidate()
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

        Publishers.CombineLatest(monitor.$snapshot, monitor.$appTraffic)
            .removeDuplicates { previous, current in
                previous.0 == current.0 && previous.1 == current.1
            }
            .sink { [weak self] _ in
                self?.handleNetworkIntelligenceUpdate()
            }
            .store(in: &cancellables)

        monitor.$systemResources
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.settings.showsCat else { return }
                guard self.settings.resolvedAnimationSpeedSource != .networkSpeed else { return }
                self.requestRender()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupCatAnimationIfNeeded()
                self?.requestRender()
            }
            .store(in: &cancellables)

        customCharacterStore.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupCatAnimationIfNeeded(force: true)
                self?.requestRender()
            }
            .store(in: &cancellables)

        appPreferences.$appearanceMode.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastRenderSignature = nil
                self?.lastColorTimeBucket = nil
                self?.renderedImageCache.removeAll()
                self?.requestRender()
            }
        }
        .store(in: &cancellables)

        appPreferences.$networkIntelligenceSettings
            .sink { [weak self] settings in
                self?.monitor.configureHistory(settings: settings)
                self?.requestRender()
            }
            .store(in: &cancellables)

        powerObserver.$isScreenLocked
            .removeDuplicates()
            .sink { [weak self] isLocked in
                guard let self else { return }
                if isLocked {
                    self.flushAnimationPlaybackCount()
                    self.catAnimation?.pauseForScreenLock()
                    self.pauseGooglyEyesTracking()
                    self.monitor.setScreenLockedForSampling(true)
                } else {
                    self.monitor.setScreenLockedForSampling(false)
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

        setupCatAnimationIfNeeded(force: true)
    }

    private func handleNetworkIntelligenceUpdate() {
        let settings = appPreferences.networkIntelligenceSettings
        monitor.configureHistory(settings: settings)
        let events = monitor.refreshIntelligence(
            settings: settings,
            language: appPreferences.resolvedLanguage
        )
        networkIntelligenceCoordinator.handle(
            events: events,
            todaySummary: monitor.intelligenceSummary.today,
            settings: settings
        )
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
                catAnimation?.onPlaybackComplete = { [weak self] characterID in
                    self?.recordAnimationPlaybackCompleted(characterID: characterID)
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
                catAnimation?.onPlaybackComplete = { [weak self] characterID in
                    self?.recordAnimationPlaybackCompleted(characterID: characterID)
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
            flushAnimationPlaybackCount()
            configureGooglyEyesTracking()
        }
    }

    private func setupCatAnimationIfNeeded(force: Bool = false) {
        let configuration = StatusBarCatAnimationConfiguration(
            settings: settings,
            customCharacterRevision: customCharacterStore.revision
        )
        guard force || configuration != lastCatAnimationConfiguration else { return }
        setupCatAnimation()
        lastCatAnimationConfiguration = StatusBarCatAnimationConfiguration(
            settings: settings,
            customCharacterRevision: customCharacterStore.revision
        )
    }

    private func recordAnimationPlaybackCompleted(characterID: String) {
        pendingAnimationPlaybackCountsByCharacter[characterID, default: 0] += 1
        guard animationPlaybackFlushTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flushAnimationPlaybackCount()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationPlaybackFlushTimer = timer
    }

    private func flushAnimationPlaybackCount() {
        animationPlaybackFlushTimer?.invalidate()
        animationPlaybackFlushTimer = nil
        guard !pendingAnimationPlaybackCountsByCharacter.isEmpty else { return }
        let counts = pendingAnimationPlaybackCountsByCharacter
        pendingAnimationPlaybackCountsByCharacter = [:]
        for (characterID, count) in counts {
            monitor.recordAnimationPlayback(count: count, characterID: characterID)
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

        // Update cat animation speed based on selected speed source
        if settings.showsCat {
            let source = settings.resolvedAnimationSpeedSource
            switch source {
            case .networkSpeed:
                catAnimation?.updateNetworkSpeed(
                    totalBytesPerSecond: UInt64(monitor.snapshot.uploadBytesPerSecond + monitor.snapshot.downloadBytesPerSecond)
                )
            case .cpuUsage, .memoryUsage, .thermalState:
                let level = AnimationSpeedMapper.activityLevel(
                    fromSystemResources: monitor.systemResources,
                    source: source
                )
                catAnimation?.updateActivityLevel(level)
            case .autoComposite:
                let totalBps = monitor.snapshot.uploadBytesPerSecond + monitor.snapshot.downloadBytesPerSecond
                let networkLevel: ActivityLevel
                if totalBps < 100 {
                    networkLevel = .idle
                } else if totalBps < 1_000 {
                    networkLevel = .low
                } else if totalBps < 100_000 {
                    networkLevel = .moderate
                } else {
                    networkLevel = .high
                }
                let compositeLevel = AnimationSpeedMapper.activityLevel(
                    fromSystemResources: monitor.systemResources,
                    source: .autoComposite,
                    networkActivityLevel: networkLevel
                )
                catAnimation?.updateActivityLevel(compositeLevel)
            }
            if currentCatFrameIndex == nil {
                currentCatFrameIndex = 0
            }
        }

        // Color pipeline: compute time bucket independently from position tracking
        let currentColorBucket = StatusBarDisplayRenderer.colorTimeBucket(forMode: settings.catColorMode)
        let intelligenceSettings = appPreferences.networkIntelligenceSettings
        let smartContext = StatusBarContextEvaluator.evaluate(
            snapshot: monitor.snapshot,
            appTraffic: monitor.appTraffic,
            intelligenceSummary: monitor.intelligenceSummary,
            settings: intelligenceSettings,
            language: appPreferences.resolvedLanguage
        )
        let characterOverrideID = settings.showsCat ? SmartCharacterSuggestionEvaluator.suggestedCharacterID(
            snapshot: monitor.snapshot,
            appTraffic: monitor.appTraffic,
            intelligenceSummary: monitor.intelligenceSummary,
            settings: intelligenceSettings
        ) : nil
        let renderTime = Date().timeIntervalSince1970

        let signature = StatusBarDisplayRenderer.signature(
            snapshot: monitor.snapshot,
            settings: settings,
            appearanceName: appearanceName,
            customCharacterStore: customCharacterStore,
            catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
            characterOverrideID: characterOverrideID,
            googlyEyesState: activeGooglyEyesState,
            smartContext: smartContext,
            renderTime: renderTime
        )
        guard signature != lastRenderSignature else {
            lastColorTimeBucket = currentColorBucket
            return
        }

        let presentation = signature.presentation
        statusItem.length = presentation.width

        let image: NSImage
        if let cached = renderedImageCache.image(for: signature) {
            image = cached
        } else {
            let scale = button.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            image = StatusBarDisplayRenderer.image(
                snapshot: monitor.snapshot,
                settings: settings,
                scale: scale,
                customCharacterStore: customCharacterStore,
                catFrameIndex: settings.showsCat ? currentCatFrameIndex : nil,
                characterOverrideID: characterOverrideID,
                googlyEyesState: activeGooglyEyesState,
                smartContext: smartContext,
                renderTime: renderTime
            )
            renderedImageCache.store(image, for: signature)
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
        applicationTrafficVisibilityScheduler?.scheduleResume()
    }

    func clearNetworkHistory() {
        monitor.clearNetworkHistory()
    }

    func flushNetworkHistory() {
        monitor.flushNetworkHistory()
    }

    private func configureDetailsWindowObserver() {
        detailsWindowController.onWindowClosed = { [weak self] in
            self?.applicationTrafficVisibilityScheduler?.schedulePause()
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
            detailsWindowController.toggle(anchor: statusItem.button)
            applicationTrafficVisibilityScheduler?.scheduleResume()
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
