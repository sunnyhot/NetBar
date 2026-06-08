import AppKit
import Combine
import XCTest
@testable import NetBar

@MainActor
final class PreferencesAndPresentationTests: XCTestCase {
    private var isolatedDefaultSuiteNames: Set<String> = []

    override func tearDown() {
        for suiteName in isolatedDefaultSuiteNames {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        isolatedDefaultSuiteNames.removeAll()
        super.tearDown()
    }

    func testStatusBarAlwaysUsesRetinaImage() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsBackground = false

        let presentation = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings
        )

        XCTAssertEqual(presentation.kind, .retinaImage)
        XCTAssertEqual(presentation.lines.count, 2)
        XCTAssertGreaterThanOrEqual(
            presentation.width,
            StatusBarDisplayRenderer.stableMinimumWidth(settings: settings)
        )
    }

    func testStatusBarTrafficDisplayModeControlsRenderedLines() {
        let snapshot = sampleSnapshot(download: 42_000, upload: 9_500)
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsArrows = true

        settings.trafficDisplayMode = .upDown
        XCTAssertEqual(
            StatusBarDisplayRenderer.presentation(snapshot: snapshot, settings: settings).lines,
            ["↑ 9.28 KB/s", "↓ 41.0 KB/s"]
        )

        settings.trafficDisplayMode = .downloadOnly
        XCTAssertEqual(
            StatusBarDisplayRenderer.presentation(snapshot: snapshot, settings: settings).lines,
            ["↓ 41.0 KB/s"]
        )

        settings.trafficDisplayMode = .uploadOnly
        XCTAssertEqual(
            StatusBarDisplayRenderer.presentation(snapshot: snapshot, settings: settings).lines,
            ["↑ 9.28 KB/s"]
        )

        settings.trafficDisplayMode = .total
        XCTAssertEqual(
            StatusBarDisplayRenderer.presentation(snapshot: snapshot, settings: settings).lines,
            ["↕ 50.3 KB/s"]
        )
    }

    func testStatusBarTrafficDisplayModePersistsAndResets() {
        let defaults = isolatedDefaults()
        let settings = StatusBarSettings(defaults: defaults)

        settings.trafficDisplayMode = .downloadOnly

        XCTAssertEqual(defaults.string(forKey: "statusBar.trafficDisplayMode"), "downloadOnly")
        XCTAssertEqual(StatusBarSettings(defaults: defaults).trafficDisplayMode, .downloadOnly)

        settings.reset()

        XCTAssertEqual(settings.trafficDisplayMode, .upDown)
    }

    func testStatusBarRetinaImageWithBackground() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsBackground = true
        settings.backgroundOpacity = 0.7

        let presentation = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 1_500_000, upload: 750_000),
            settings: settings
        )

        XCTAssertEqual(presentation.kind, .retinaImage)
    }

    func testMenuBarPreferenceGroupsFollowPreviewToLayoutWorkflow() {
        XCTAssertEqual(
            MenuBarPreferenceGroup.allCases,
            [.preview, .display, .character, .animation, .layout]
        )
        XCTAssertEqual(MenuBarPreferenceGroup.display.title(language: .simplifiedChinese), "显示内容")
        XCTAssertEqual(MenuBarPreferenceGroup.animation.title(language: .english), "Animation & Rotation")
    }

    func testMenuBarPresetAppliesTotalTrafficMode() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())

        MenuBarPreset.totalTraffic.apply(to: settings)

        XCTAssertEqual(settings.trafficDisplayMode, .total)
        XCTAssertFalse(settings.showsArrows)
    }

    func testMenuBarPresetDetectsCustomAfterManualEdit() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        MenuBarPreset.upDown.apply(to: settings)

        XCTAssertEqual(MenuBarPreset.matching(settings: settings), .upDown)

        settings.fontSize = settings.fontSize + 1

        XCTAssertNil(MenuBarPreset.matching(settings: settings))
    }

    func testMenuBarPresetTitlesAreLocalized() {
        XCTAssertEqual(MenuBarPreset.minimal.title(language: .simplifiedChinese), "极简")
        XCTAssertEqual(MenuBarPreset.petMode.title(language: .english), "Pet Mode")
    }

    func testRetinaStatusBarImageCentersTextVertically() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsBackground = true
        settings.backgroundOpacity = 1
        settings.usesSystemTextColor = false
        settings.textColor = .white
        settings.backgroundColor = .olive

        let image = StatusBarDisplayRenderer.image(
            snapshot: sampleSnapshot(download: 310_000, upload: 153_000),
            settings: settings,
            scale: 2
        )
        let textBounds = foregroundPixelBounds(in: image, background: settings.backgroundColor)

        XCTAssertLessThanOrEqual(abs(textBounds.topMargin - textBounds.bottomMargin), 2)
    }

    func testDetailsWindowLayoutKeepsTallAnchoredWindowVisible() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 960, height: 560)
        let anchorFrame = NSRect(x: 470, y: 540, width: 20, height: 20)

        let frame = DetailsWindowLayout.frame(
            forWindowSize: NSSize(width: 440, height: 700),
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            padding: 10
        )

        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY + 10)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY - 10)
    }

    func testDetailsWindowLayoutTouchesStatusItemAnchorWhenSpaceAllows() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1200, height: 900)
        let anchorFrame = NSRect(x: 590, y: 880, width: 20, height: 20)

        let frame = DetailsWindowLayout.frame(
            forWindowSize: NSSize(width: 440, height: 720),
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            padding: 10
        )

        XCTAssertEqual(frame.width, 440)
        XCTAssertEqual(frame.maxY, anchorFrame.minY, accuracy: 0.5)
    }

    func testDetailsWindowLayoutTouchesVisibleFrameTopWhenAnchoredAtMenuBarEdge() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1200, height: 878)
        let anchorFrame = NSRect(x: 590, y: 878, width: 20, height: 20)

        let frame = DetailsWindowLayout.frame(
            forWindowSize: NSSize(width: 440, height: 720),
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            padding: 10
        )

        XCTAssertEqual(frame.width, 440)
        XCTAssertEqual(frame.maxY, visibleFrame.maxY, accuracy: 0.5)
    }

    func testDetailsWindowDismissesForOutsideClickButKeepsInsideClick() {
        let panelFrame = NSRect(x: 100, y: 100, width: 240, height: 320)
        var globalClick: ((CGPoint) -> Void)?
        var localClick: ((CGPoint) -> Void)?
        let monitor = DetailsWindowOutsideClickMonitor(
            panelFrameProvider: { panelFrame },
            addGlobalMonitor: { handler in
                globalClick = handler
                return MonitorToken(name: "global-details")
            },
            addLocalMonitor: { handler in
                localClick = handler
                return MonitorToken(name: "local-details")
            },
            removeMonitor: { _ in }
        )

        var dismissCount = 0
        monitor.setActive(true) {
            dismissCount += 1
        }

        globalClick?(CGPoint(x: 120, y: 120))
        localClick?(CGPoint(x: 500, y: 500))

        XCTAssertEqual(dismissCount, 1)
    }

    func testDetailsWindowOutsideClickMonitorDoesNotDuplicateAndRemovesMonitors() {
        var installCount = 0
        var removedTokens: [String] = []
        let monitor = DetailsWindowOutsideClickMonitor(
            panelFrameProvider: { NSRect(x: 0, y: 0, width: 100, height: 100) },
            addGlobalMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "global-details")
            },
            addLocalMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "local-details")
            },
            removeMonitor: { token in
                removedTokens.append((token as? MonitorToken)?.name ?? "unknown")
            }
        )

        monitor.setActive(true) {}
        monitor.setActive(true) {}
        monitor.setActive(false)
        monitor.setActive(false)

        XCTAssertEqual(installCount, 2)
        XCTAssertEqual(removedTokens.sorted(), ["global-details", "local-details"])
    }

    func testDetailsWindowAutoDismissIntervalMatchesTransientPopoverBehavior() {
        XCTAssertEqual(DetailsWindowDismissalPolicy.autoDismissInterval, 30)
    }

    // MARK: - DockIconVisibility model tests

    func testDockIconVisibilityMapsVisibleToRegularPolicy() {
        XCTAssertEqual(DockIconVisibility.visible.activationPolicy, .regular)
        XCTAssertTrue(DockIconVisibility.visible.isDockVisible)
        XCTAssertTrue(DockIconVisibility.visible.boolValue)
    }

    func testDockIconVisibilityMapsHiddenToAccessoryPolicy() {
        XCTAssertEqual(DockIconVisibility.menuBarOnly.activationPolicy, .accessory)
        XCTAssertFalse(DockIconVisibility.menuBarOnly.isDockVisible)
        XCTAssertFalse(DockIconVisibility.menuBarOnly.boolValue)
    }

    func testDockIconVisibilityInitFromBool() {
        XCTAssertEqual(DockIconVisibility(showsDockIcon: true), .visible)
        XCTAssertEqual(DockIconVisibility(showsDockIcon: false), .menuBarOnly)
    }

    func testDockIconVisibilityBoolValueRoundTrip() {
        for visibility in DockIconVisibility.allCases {
            XCTAssertEqual(DockIconVisibility(showsDockIcon: visibility.boolValue), visibility)
        }
    }

    func testDockIconVisibilityIsCaseIterableWithExactlyTwoCases() {
        XCTAssertEqual(DockIconVisibility.allCases, [.visible, .menuBarOnly])
    }

    func testDockIconVisibilityRawValueRoundTrip() {
        for visibility in DockIconVisibility.allCases {
            XCTAssertEqual(DockIconVisibility(rawValue: visibility.rawValue), visibility)
        }
    }

    func testDockIconVisibilityLocalizedTitles() {
        XCTAssertEqual(DockIconVisibility.visible.title(language: .simplifiedChinese), "显示 Dock 图标")
        XCTAssertEqual(DockIconVisibility.visible.title(language: .english), "Show Dock icon")
        XCTAssertEqual(DockIconVisibility.menuBarOnly.title(language: .simplifiedChinese), "仅菜单栏")
        XCTAssertEqual(DockIconVisibility.menuBarOnly.title(language: .english), "Menu bar only")
    }

    // MARK: - AppPreferences Dock-derived properties

    func testAppPreferencesActivationPolicyMatchesDockIconSetting() {
        let defaults = isolatedDefaults()

        var preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        preferences.showsDockIcon = true
        XCTAssertEqual(preferences.activationPolicy, .regular)
        XCTAssertTrue(preferences.shouldHandleDockReopen)

        preferences.showsDockIcon = false
        XCTAssertEqual(preferences.activationPolicy, .accessory)
        XCTAssertFalse(preferences.shouldHandleDockReopen)
    }

    func testAppPreferencesDockVisibilityDerivesFromShowsDockIcon() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )

        // Default is showsDockIcon = true
        XCTAssertEqual(preferences.dockIconVisibility, .visible)

        // After persistence round-trip, derived property still works
        let defaults2 = isolatedDefaults()
        defaults2.set(false, forKey: "app.showsDockIcon")
        let preferences2 = AppPreferences(
            defaults: defaults2,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertEqual(preferences2.dockIconVisibility, .menuBarOnly)
        XCTAssertEqual(preferences2.activationPolicy, .accessory)
        XCTAssertFalse(preferences2.shouldHandleDockReopen)
    }

    func testAppPreferencesShouldHandleDockReopenMatchesVisibility() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )

        // When Dock is visible, reopen should be handled
        preferences.showsDockIcon = true
        XCTAssertTrue(preferences.shouldHandleDockReopen)

        // When Dock is hidden, reopen should NOT be handled
        preferences.showsDockIcon = false
        XCTAssertFalse(preferences.shouldHandleDockReopen)
    }

    func testAppearanceModeDefaultsToSystemAndPersistsSelection() {
        let defaults = isolatedDefaults()
        var preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertEqual(preferences.appearanceMode, .system)

        preferences.appearanceMode = .dark
        preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )

        XCTAssertEqual(preferences.appearanceMode, .dark)
    }

    func testNetworkIntelligenceSettingsDefaultsAreConservative() {
        let settings = NetworkIntelligenceSettings.default

        XCTAssertTrue(settings.isAnomalyDetectionEnabled)
        XCTAssertFalse(settings.isSystemNotificationEnabled)
        XCTAssertEqual(settings.highTrafficThreshold, .mbps10)
        XCTAssertTrue(settings.isApplicationSpikeAlertEnabled)
        XCTAssertTrue(settings.isNetworkDropAlertEnabled)
        XCTAssertTrue(settings.isProxyAttributionAlertEnabled)
        XCTAssertTrue(settings.isHistoryTrackingEnabled)
    }

    func testNetworkIntelligenceSettingsDecodeMissingFieldsFromDefaults() throws {
        let data = """
        {
          "isAnomalyDetectionEnabled": false,
          "highTrafficThreshold": 26214400
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(NetworkIntelligenceSettings.self, from: data)

        XCTAssertFalse(settings.isAnomalyDetectionEnabled)
        XCTAssertEqual(settings.highTrafficThreshold, .mbps25)
        XCTAssertEqual(settings.hasSeenNotificationOnboarding, NetworkIntelligenceSettings.default.hasSeenNotificationOnboarding)
        XCTAssertEqual(settings.isSystemNotificationEnabled, NetworkIntelligenceSettings.default.isSystemNotificationEnabled)
        XCTAssertEqual(settings.isApplicationSpikeAlertEnabled, NetworkIntelligenceSettings.default.isApplicationSpikeAlertEnabled)
        XCTAssertEqual(settings.isNetworkDropAlertEnabled, NetworkIntelligenceSettings.default.isNetworkDropAlertEnabled)
        XCTAssertEqual(settings.isProxyAttributionAlertEnabled, NetworkIntelligenceSettings.default.isProxyAttributionAlertEnabled)
        XCTAssertEqual(settings.isHistoryTrackingEnabled, NetworkIntelligenceSettings.default.isHistoryTrackingEnabled)
    }

    func testAppPreferencesPersistNetworkIntelligenceSettings() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(defaults: defaults, loginItemManager: FakeLoginItemManager())

        preferences.networkIntelligenceSettings = NetworkIntelligenceSettings(
            hasSeenNotificationOnboarding: true,
            isAnomalyDetectionEnabled: false,
            isSystemNotificationEnabled: true,
            highTrafficThreshold: .mbps25,
            isApplicationSpikeAlertEnabled: false,
            isNetworkDropAlertEnabled: true,
            isProxyAttributionAlertEnabled: false,
            isHistoryTrackingEnabled: true
        )

        let reloaded = AppPreferences(defaults: defaults, loginItemManager: FakeLoginItemManager())

        XCTAssertEqual(reloaded.networkIntelligenceSettings.highTrafficThreshold, .mbps25)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.hasSeenNotificationOnboarding)
        XCTAssertFalse(reloaded.networkIntelligenceSettings.isAnomalyDetectionEnabled)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.isSystemNotificationEnabled)
        XCTAssertFalse(reloaded.networkIntelligenceSettings.isApplicationSpikeAlertEnabled)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.isNetworkDropAlertEnabled)
        XCTAssertFalse(reloaded.networkIntelligenceSettings.isProxyAttributionAlertEnabled)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.isHistoryTrackingEnabled)
    }

    func testNetworkAnomalyEventLocalizedTitles() {
        XCTAssertEqual(NetworkAnomalyKind.highTraffic.title(language: .simplifiedChinese), "高流量")
        XCTAssertEqual(NetworkAnomalyKind.applicationSpike.title(language: .english), "Application spike")
        XCTAssertEqual(NetworkAnomalyKind.networkDrop.title(language: .simplifiedChinese), "网络断流")
        XCTAssertEqual(NetworkAnomalyKind.networkRecovered.title(language: .english), "Network recovered")
        XCTAssertEqual(NetworkAnomalyKind.proxyAttributionGap.title(language: .simplifiedChinese), "代理归因差异")
    }

    func testNetworkAnomalyDetectorEmitsHighTrafficAfterSustainedThreshold() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start), appTraffic: .empty, settings: settings, now: start).isEmpty)

        let events = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(11)
        )

        XCTAssertEqual(events.map(\.kind), [.highTraffic])
    }

    func testNetworkAnomalyDetectorClearsHighTrafficTimerWhenDisabled() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        var disabledSettings = settings
        disabledSettings.isAnomalyDetectionEnabled = false
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start), appTraffic: .empty, settings: settings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(5)), appTraffic: .empty, settings: disabledSettings, now: start.addingTimeInterval(5))

        let staleWindow = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(11)
        )

        XCTAssertTrue(staleWindow.isEmpty)

        let restartedWindow = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(21)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(21)
        )

        XCTAssertEqual(restartedWindow.map(\.kind), [.highTraffic])
    }

    func testNetworkAnomalyDetectorUsesRequestedLanguageForEventPresentation() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start),
            appTraffic: .empty,
            settings: settings,
            now: start,
            language: .english
        )
        let events = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(11),
            language: .english
        )

        XCTAssertEqual(events.first?.title, "High traffic")
        XCTAssertEqual(events.first?.message, "Current total speed is about 11.0 MB/s.")
    }

    func testNetworkAnomalyDetectorEmitsApplicationSpikeForDominantApp() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)
        let state = ApplicationTrafficState(
            timestamp: start,
            applications: [
                appRate("VideoSync", download: 6_000_000, upload: 500_000),
                appRate("Mail", download: 300_000, upload: 20_000)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        _ = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start), appTraffic: state, settings: settings, now: start)
        let events = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(6)), appTraffic: state, settings: settings, now: start.addingTimeInterval(6))

        XCTAssertEqual(events.first?.kind, .applicationSpike)
        XCTAssertEqual(events.first?.applicationName, "VideoSync")
    }

    func testNetworkAnomalyDetectorClearsApplicationSpikeTimerWhenAlertDisabled() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        var disabledSettings = settings
        disabledSettings.isApplicationSpikeAlertEnabled = false
        let start = Date(timeIntervalSince1970: 100)
        let state = ApplicationTrafficState(
            timestamp: start,
            applications: [
                appRate("VideoSync", download: 6_000_000, upload: 500_000),
                appRate("Mail", download: 300_000, upload: 20_000)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        _ = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start), appTraffic: state, settings: settings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(1)), appTraffic: state, settings: disabledSettings, now: start.addingTimeInterval(1))

        let staleWindow = detector.detect(
            snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(6)),
            appTraffic: state,
            settings: settings,
            now: start.addingTimeInterval(6)
        )

        XCTAssertTrue(staleWindow.isEmpty)

        let restartedWindow = detector.detect(
            snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(12)),
            appTraffic: state,
            settings: settings,
            now: start.addingTimeInterval(12)
        )

        XCTAssertEqual(restartedWindow.map(\.kind), [.applicationSpike])
    }

    func testNetworkAnomalyDetectorRequiresContinuousApplicationSpikeForSameDominantApp() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)
        let spikingState = ApplicationTrafficState(
            timestamp: start,
            applications: [
                appRate("VideoSync", download: 6_000_000, upload: 500_000),
                appRate("Mail", download: 300_000, upload: 20_000)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        _ = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start), appTraffic: spikingState, settings: settings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(1)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(1))

        let interrupted = detector.detect(
            snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(10)),
            appTraffic: spikingState,
            settings: settings,
            now: start.addingTimeInterval(10)
        )

        XCTAssertTrue(interrupted.isEmpty)

        let sustained = detector.detect(
            snapshot: sampleSnapshot(download: 7_000_000, upload: 500_000, timestamp: start.addingTimeInterval(16)),
            appTraffic: spikingState,
            settings: settings,
            now: start.addingTimeInterval(16)
        )

        XCTAssertEqual(sustained.map(\.kind), [.applicationSpike])
    }

    func testNetworkAnomalyDetectorEmitsDropAndRecoveredEvents() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(snapshot: sampleSnapshot(download: 200_000, upload: 20_000, timestamp: start), appTraffic: .empty, settings: settings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(1)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(1))
        let drop = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(10)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(10))

        XCTAssertEqual(drop.map(\.kind), [.networkDrop])

        XCTAssertTrue(detector.detect(snapshot: sampleSnapshot(download: 50_000, upload: 10_000, timestamp: start.addingTimeInterval(11)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(11)).isEmpty)
        let recovered = detector.detect(snapshot: sampleSnapshot(download: 50_000, upload: 10_000, timestamp: start.addingTimeInterval(14)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(14))

        XCTAssertEqual(recovered.map(\.kind), [.networkRecovered])
    }

    func testNetworkAnomalyDetectorClearsDropTimerWhenAlertDisabled() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        var disabledSettings = settings
        disabledSettings.isNetworkDropAlertEnabled = false
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(snapshot: sampleSnapshot(download: 200_000, upload: 20_000, timestamp: start), appTraffic: .empty, settings: settings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(1)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(1))
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(5)), appTraffic: .empty, settings: disabledSettings, now: start.addingTimeInterval(5))

        let staleWindow = detector.detect(
            snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(10)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(10)
        )

        XCTAssertTrue(staleWindow.isEmpty)

        _ = detector.detect(snapshot: sampleSnapshot(download: 200_000, upload: 20_000, timestamp: start.addingTimeInterval(12)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(12))
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(13)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(13))
        let restartedWindow = detector.detect(
            snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(22)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(22)
        )

        XCTAssertEqual(restartedWindow.map(\.kind), [.networkDrop])
    }

    func testNetworkAnomalyDetectorIgnoresDropBaselineCollectedWhileAlertDisabled() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        var disabledSettings = settings
        disabledSettings.isNetworkDropAlertEnabled = false
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(snapshot: sampleSnapshot(download: 200_000, upload: 20_000, timestamp: start), appTraffic: .empty, settings: disabledSettings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(1)), appTraffic: .empty, settings: disabledSettings, now: start.addingTimeInterval(1))
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(10)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(10))

        let staleBaseline = detector.detect(
            snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(18)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(18)
        )

        XCTAssertTrue(staleBaseline.isEmpty)

        _ = detector.detect(snapshot: sampleSnapshot(download: 200_000, upload: 20_000, timestamp: start.addingTimeInterval(20)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(20))
        _ = detector.detect(snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(21)), appTraffic: .empty, settings: settings, now: start.addingTimeInterval(21))
        let freshBaseline = detector.detect(
            snapshot: sampleSnapshot(download: 0, upload: 0, timestamp: start.addingTimeInterval(30)),
            appTraffic: .empty,
            settings: settings,
            now: start.addingTimeInterval(30)
        )

        XCTAssertEqual(freshBaseline.map(\.kind), [.networkDrop])
    }

    func testNetworkAnomalyDetectorEmitsProxyAttributionGap() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let now = Date(timeIntervalSince1970: 100)
        let appTraffic = ApplicationTrafficState(
            timestamp: now,
            applications: [appRate("ClashX", download: 100_000, upload: 20_000)],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let events = detector.detect(snapshot: sampleSnapshot(download: 2_000_000, upload: 500_000, timestamp: now), appTraffic: appTraffic, settings: settings, now: now)

        XCTAssertEqual(events.map(\.kind), [.proxyAttributionGap])
    }

    func testNetworkAnomalyDetectorProxyGapUsesRawCoverageBeforeRounding() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let now = Date(timeIntervalSince1970: 100)
        let appTraffic = ApplicationTrafficState(
            timestamp: now,
            applications: [appRate("ClashX", download: 970_000, upload: 20_000)],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let events = detector.detect(
            snapshot: sampleSnapshot(download: 2_000_000, upload: 500_000, timestamp: now),
            appTraffic: appTraffic,
            settings: settings,
            now: now
        )

        XCTAssertEqual(events.map(\.kind), [.proxyAttributionGap])
    }

    func testNetworkNotificationControllerRefreshesAuthorizationStatus() async {
        let center = FakeNetworkNotificationCenter(authorizationStatus: .authorized)
        let controller = NetworkNotificationController(center: center)

        let status = await controller.refreshAuthorizationStatus()

        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(controller.authorizationStatus, .authorized)
    }

    func testNetworkNotificationControllerSuppressesDuplicateCooldownEvents() async {
        let center = FakeNetworkNotificationCenter(authorizationStatus: .authorized)
        let controller = NetworkNotificationController(center: center, now: { Date(timeIntervalSince1970: 100) })
        let settings = NetworkIntelligenceSettings.default.withSystemNotificationsEnabled()
        let event = NetworkAnomalyEvent(
            kind: .highTraffic,
            severity: .warning,
            title: "High",
            message: "Traffic",
            timestamp: Date(timeIntervalSince1970: 100),
            bytesPerSecond: 1_000,
            cooldownKey: "highTraffic"
        )

        await controller.refreshAuthorizationStatus()
        await controller.handle(event, settings: settings)
        await controller.handle(event, settings: settings)

        XCTAssertEqual(center.deliveredTitles, ["High"])
        XCTAssertEqual(center.deliveredBodies, ["Traffic"])
    }

    func testNetworkNotificationControllerAllowsCooldownAfterWindowExpires() async {
        var currentDate = Date(timeIntervalSince1970: 100)
        let center = FakeNetworkNotificationCenter(authorizationStatus: .authorized)
        let controller = NetworkNotificationController(center: center, now: { currentDate })
        let settings = NetworkIntelligenceSettings.default.withSystemNotificationsEnabled()
        let event = NetworkAnomalyEvent(
            kind: .networkDrop,
            severity: .critical,
            title: "Drop",
            message: "Quiet",
            timestamp: currentDate,
            cooldownKey: "networkDrop"
        )

        await controller.refreshAuthorizationStatus()
        await controller.handle(event, settings: settings)
        currentDate = currentDate.addingTimeInterval(180)
        await controller.handle(event, settings: settings)

        XCTAssertEqual(center.deliveredTitles, ["Drop", "Drop"])
    }

    func testNetworkNotificationControllerDoesNotSendWhenAuthorizationDenied() async {
        let center = FakeNetworkNotificationCenter(authorizationStatus: .denied)
        let controller = NetworkNotificationController(center: center, now: { Date(timeIntervalSince1970: 100) })
        let settings = NetworkIntelligenceSettings.default.withSystemNotificationsEnabled()
        let event = NetworkAnomalyEvent(
            kind: .networkDrop,
            severity: .critical,
            title: "Drop",
            message: "Quiet",
            timestamp: Date(timeIntervalSince1970: 100),
            cooldownKey: "networkDrop"
        )

        await controller.refreshAuthorizationStatus()
        await controller.handle(event, settings: settings)

        XCTAssertTrue(center.deliveredTitles.isEmpty)
    }

    func testHighTrafficThresholdTitlesAreLocalized() {
        XCTAssertEqual(HighTrafficThreshold.mbps5.title(language: .simplifiedChinese), "5 MB/s")
        XCTAssertEqual(HighTrafficThreshold.mbps50.title(language: .english), "50 MB/s")
    }

    func testNetworkNotificationAuthorizationStatusTitles() {
        XCTAssertEqual(NetworkNotificationAuthorizationStatus.authorized.title(language: .simplifiedChinese), "已授权")
        XCTAssertEqual(NetworkNotificationAuthorizationStatus.denied.title(language: .english), "Denied")
        XCTAssertEqual(NetworkNotificationAuthorizationStatus.notDetermined.title(language: .simplifiedChinese), "未设置")
    }

    func testNetworkIntelligenceStatusPresentationMapsSeverity() {
        let event = NetworkAnomalyEvent(
            kind: .networkDrop,
            severity: .critical,
            title: "网络断流",
            message: "网络活动下降。",
            timestamp: Date(timeIntervalSince1970: 10),
            cooldownKey: "networkDrop"
        )

        let presentation = NetworkIntelligenceStatusPresentation(
            event: event,
            language: .simplifiedChinese
        )

        XCTAssertEqual(presentation.title, "网络断流")
        XCTAssertEqual(presentation.message, "网络活动下降。")
        XCTAssertEqual(presentation.tone, .critical)
        XCTAssertEqual(presentation.symbolName, "exclamationmark.triangle.fill")
    }

    func testNetworkDailySummaryPresentationFormatsTodayEstimate() {
        let summary = NetworkDailySummary(
            dateKey: "2026-06-08",
            downloadBytes: 10_000_000,
            uploadBytes: 5_000_000,
            peakDownloadBytesPerSecond: 2_000_000,
            peakUploadBytesPerSecond: 1_000_000,
            sampleCount: 20,
            activeSeconds: 80,
            topApplications: []
        )

        let cards = NetworkDailySummaryPresentation.cards(for: summary, language: .english)

        XCTAssertEqual(cards.map(\.title), ["Today Down", "Today Up", "Peak", "Active"])
        XCTAssertEqual(cards.map(\.id), ["down", "up", "peak", "active"])
        XCTAssertEqual(cards.last?.value, "1m")
    }

    func testApplicationDailyUsageCodablePreservesRole() throws {
        let usage = ApplicationDailyUsage(
            applicationID: "com.example.proxy",
            displayName: "Example Proxy",
            processNames: ["Example Proxy", "proxy-helper"],
            downloadBytes: 4_096,
            uploadBytes: 2_048,
            lastSeenAt: Date(timeIntervalSince1970: 1_717_200_000),
            role: .proxyOrVPN
        )

        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(ApplicationDailyUsage.self, from: data)

        XCTAssertEqual(decoded, usage)
        XCTAssertEqual(decoded.role, .proxyOrVPN)
    }

    func testNetworkHistoryStoreAccumulatesInterfaceDeltasForToday() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
        let first = sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000, timestamp: Date(timeIntervalSince1970: 0))
        let second = sampleSnapshot(download: 300, upload: 200, received: 1_500, sent: 2_700, timestamp: Date(timeIntervalSince1970: 1))

        store.record(snapshot: first)
        store.record(snapshot: second)

        XCTAssertEqual(store.summary.today.downloadBytes, 500)
        XCTAssertEqual(store.summary.today.uploadBytes, 700)
        XCTAssertEqual(store.summary.today.peakDownloadBytesPerSecond, 300)
        XCTAssertEqual(store.summary.today.peakUploadBytesPerSecond, 200)
    }

    func testNetworkHistoryStoreSumsPositiveDeltasPerInterface() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
        let first = multiInterfaceSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            interfaces: [
                interfaceRate(id: "en0", received: 1_000, sent: 2_000),
                interfaceRate(id: "en1", received: 5_000, sent: 8_000),
                interfaceRate(id: "utun0", received: 9_000, sent: 10_000)
            ]
        )
        let second = multiInterfaceSnapshot(
            timestamp: Date(timeIntervalSince1970: 1),
            interfaces: [
                interfaceRate(id: "en0", received: 1_400, sent: 2_600),
                interfaceRate(id: "en1", received: 100, sent: 50),
                interfaceRate(id: "utun0", received: 9_500, sent: 10_500)
            ]
        )

        store.record(snapshot: first)
        store.record(snapshot: second)

        XCTAssertEqual(store.summary.today.downloadBytes, 400)
        XCTAssertEqual(store.summary.today.uploadBytes, 600)
    }

    func testNetworkHistoryStoreRollsOverAndRetainsSevenDays() throws {
        let root = try temporaryDirectory()
        var currentDate = isoDate("2026-06-01T12:00:00Z")
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

        for dayOffset in 0..<9 {
            currentDate = isoDate("2026-06-\(String(format: "%02d", dayOffset + 1))T12:00:00Z")
            store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: UInt64(dayOffset * 1_000 + 1_000), sent: UInt64(dayOffset * 1_000 + 2_000), timestamp: currentDate))
        }

        XCTAssertEqual(store.summary.recentDays.count, 7)
        XCTAssertEqual(store.summary.today.dateKey, "2026-06-09")
        XCTAssertEqual(store.summary.recentDays.first?.dateKey, "2026-06-02")
        XCTAssertEqual(store.summary.recentDays.last?.dateKey, "2026-06-08")
    }

    func testNetworkHistoryStoreAccumulatesTodayTopApplications() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 10) })
        let apps = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appRate("Safari", download: 1_000, upload: 200),
                appRate("Chrome", download: 3_000, upload: 500)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        store.record(appTraffic: apps, interval: 2.0)

        XCTAssertEqual(store.summary.todayTopApplications.map(\.displayName), ["Chrome", "Safari"])
        XCTAssertEqual(store.summary.todayTopApplications.first?.downloadBytes, 6_000)
        XCTAssertEqual(store.summary.todayTopApplications.first?.uploadBytes, 1_000)
    }

    func testNetworkHistoryStoreUsesApplicationCounterDeltasBeforeIntervalFallback() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 10) })
        let first = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appRate("Safari", download: 0, upload: 0, received: 1_000, sent: 500)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )
        let second = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 11),
            applications: [
                appRate("Safari", download: 10_000, upload: 8_000, received: 2_500, sent: 900)
            ],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        store.record(appTraffic: first, interval: 999)
        store.record(appTraffic: second, interval: 99)

        XCTAssertEqual(store.summary.todayTopApplications.first?.downloadBytes, 1_500)
        XCTAssertEqual(store.summary.todayTopApplications.first?.uploadBytes, 400)
    }

    func testNetworkHistoryStoreTreatsZeroApplicationCountersAsValidBaseline() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 10) })
        let first = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appRate("Safari", download: 0, upload: 0, received: 0, sent: 0)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )
        let second = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 11),
            applications: [
                appRate("Safari", download: 10_000, upload: 8_000, received: 1_500, sent: 400)
            ],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        store.record(appTraffic: first, interval: 999)
        store.record(appTraffic: second, interval: 99)

        XCTAssertEqual(store.summary.todayTopApplications.first?.downloadBytes, 1_500)
        XCTAssertEqual(store.summary.todayTopApplications.first?.uploadBytes, 400)
    }

    func testNetworkHistoryStoreDropsMissingApplicationCounterBaselines() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 10) })
        let first = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appRate("Safari", download: 0, upload: 0, received: 5_000, sent: 1_000)
            ],
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )
        let missing = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 11),
            applications: [],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )
        let reappeared = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 12),
            applications: [
                appRate("Safari", download: 10, upload: 5, received: 100, sent: 50)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )
        let next = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 13),
            applications: [
                appRate("Safari", download: 10_000, upload: 8_000, received: 400, sent: 170)
            ],
            sampleCount: 4,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        store.record(appTraffic: first, interval: 1)
        store.record(appTraffic: missing, interval: 1)
        store.record(appTraffic: reappeared, interval: 1)
        store.record(appTraffic: next, interval: 99)

        XCTAssertEqual(store.summary.todayTopApplications.first?.downloadBytes, 310)
        XCTAssertEqual(store.summary.todayTopApplications.first?.uploadBytes, 125)
    }

    func testNetworkHistoryStorePersistsAndReloadsNormalizedSummary() throws {
        let root = try temporaryDirectory()
        let start = isoDate("2026-06-01T12:00:00Z")
        let secondTimestamp = isoDate("2026-06-01T12:00:01Z")
        let reloadTimestamp = isoDate("2026-06-01T13:00:00Z")
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { start })
        let first = sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000, timestamp: start)
        let second = sampleSnapshot(download: 300, upload: 200, received: 1_500, sent: 2_700, timestamp: secondTimestamp)
        let apps = ApplicationTrafficState(
            timestamp: secondTimestamp,
            applications: (1...25).map { index in
                appRate("App\(String(format: "%02d", index))", download: Double(index), upload: 0)
            },
            sampleCount: 1,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        store.record(snapshot: first)
        store.record(snapshot: second)
        store.record(appTraffic: apps, interval: 1)
        let reloaded = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { reloadTimestamp })

        XCTAssertEqual(reloaded.summary.today.downloadBytes, 500)
        XCTAssertEqual(reloaded.summary.today.uploadBytes, 700)
        XCTAssertEqual(reloaded.summary.today.topApplications.count, 20)
        XCTAssertEqual(reloaded.summary.todayTopApplications.count, 5)
        XCTAssertEqual(reloaded.summary.todayTopApplications.map(\.displayName), ["App25", "App24", "App23", "App22", "App21"])
    }

    func testNetworkHistoryStoreRollsPersistedYesterdayIntoRecentDaysOnInit() throws {
        let root = try temporaryDirectory()
        var currentDate = isoDate("2026-06-01T12:00:00Z")
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })
        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000, timestamp: currentDate))
        store.record(snapshot: sampleSnapshot(download: 300, upload: 200, received: 1_800, sent: 2_600, timestamp: isoDate("2026-06-01T12:00:01Z")))

        currentDate = isoDate("2026-06-02T12:00:00Z")
        let reloaded = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

        XCTAssertEqual(reloaded.summary.today.dateKey, "2026-06-02")
        XCTAssertEqual(reloaded.summary.today.downloadBytes, 0)
        XCTAssertEqual(reloaded.summary.today.uploadBytes, 0)
        XCTAssertEqual(reloaded.summary.recentDays.last?.dateKey, "2026-06-01")
        XCTAssertEqual(reloaded.summary.recentDays.last?.downloadBytes, 800)
        XCTAssertEqual(reloaded.summary.recentDays.last?.uploadBytes, 600)
    }

    // MARK: - DockIconVisibility

    func testDockIconVisibilityDefaultValueIsVisible() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertEqual(preferences.dockIconVisibility, .visible)
        XCTAssertTrue(preferences.showsDockIcon)
    }

    func testDockIconVisibilityReadsOldBoolTrueKey() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: "app.showsDockIcon")

        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertEqual(preferences.dockIconVisibility, .visible)
        XCTAssertTrue(preferences.showsDockIcon)
    }

    func testDockIconVisibilityReadsOldBoolFalseKey() {
        let defaults = isolatedDefaults()
        defaults.set(false, forKey: "app.showsDockIcon")

        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertEqual(preferences.dockIconVisibility, .menuBarOnly)
        XCTAssertFalse(preferences.showsDockIcon)
    }

    func testSetDockIconVisibilityPersistsToOldBoolKey() {
        let defaults = isolatedDefaults()

        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        preferences.setDockIconVisibility(.menuBarOnly)

        XCTAssertEqual(defaults.object(forKey: "app.showsDockIcon") as? Bool, false)
        XCTAssertEqual(preferences.dockIconVisibility, .menuBarOnly)

        preferences.setDockIconVisibility(.visible)
        XCTAssertEqual(defaults.object(forKey: "app.showsDockIcon") as? Bool, true)
        XCTAssertEqual(preferences.dockIconVisibility, .visible)
    }

    func testDockActivationPolicyReflectsPendingPublishedVisibilityChange() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        var cancellables: Set<AnyCancellable> = []
        var policiesAppliedFromPublisher: [NSApplication.ActivationPolicy] = []

        preferences.$showsDockIcon
            .dropFirst()
            .sink { _ in
                policiesAppliedFromPublisher.append(preferences.activationPolicy)
            }
            .store(in: &cancellables)

        preferences.setDockIconVisibility(.menuBarOnly)

        XCTAssertEqual(policiesAppliedFromPublisher, [.accessory])
    }

    func testResetAppPreferencesRestoresDockIconVisibilityToDefault() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        preferences.setDockIconVisibility(.menuBarOnly)
        XCTAssertEqual(preferences.dockIconVisibility, .menuBarOnly)

        preferences.resetAppPreferences()
        XCTAssertEqual(preferences.dockIconVisibility, .visible)
        XCTAssertEqual(defaults.object(forKey: "app.showsDockIcon") as? Bool, true)
    }

    func testDockIconVisibilityEnumMapsActivationPolicy() {
        XCTAssertEqual(DockIconVisibility.visible.activationPolicy, .regular)
        XCTAssertEqual(DockIconVisibility.menuBarOnly.activationPolicy, .accessory)
    }

    func testDockIconVisibilityEnumShowsDockIconBoolean() {
        XCTAssertTrue(DockIconVisibility.visible.showsDockIcon)
        XCTAssertFalse(DockIconVisibility.menuBarOnly.showsDockIcon)
    }

    func testDockIconVisibilityEnumRawValueRoundTrip() {
        for visibility in DockIconVisibility.allCases {
            XCTAssertEqual(DockIconVisibility(rawValue: visibility.rawValue), visibility)
        }
    }

    func testDockIconVisibilityEnumCaseOrder() {
        XCTAssertEqual(DockIconVisibility.allCases, [.visible, .menuBarOnly])
    }

    func testAppearanceModeMapsToMacOSAppearanceNames() {
        XCTAssertNil(AppAppearanceMode.system.nsAppearanceName)
        XCTAssertEqual(AppAppearanceMode.light.nsAppearanceName, .aqua)
        XCTAssertEqual(AppAppearanceMode.dark.nsAppearanceName, .darkAqua)
    }

    func testAppearanceModeCaseOrderMatchesSegmentedPickerLayout() {
        XCTAssertEqual(AppAppearanceMode.allCases, [.system, .light, .dark])
    }

    func testAppearanceModeResolvesToCorrectNSAppearance() {
        XCTAssertNil(AppAppearanceMode.system.nsAppearance)

        let lightAppearance = AppAppearanceMode.light.nsAppearance
        XCTAssertNotNil(lightAppearance)
        XCTAssertEqual(lightAppearance?.name, .aqua)

        let darkAppearance = AppAppearanceMode.dark.nsAppearance
        XCTAssertNotNil(darkAppearance)
        XCTAssertEqual(darkAppearance?.name, .darkAqua)
    }

    func testAppearanceModeResolvesToCorrectSwiftUIColorScheme() {
        XCTAssertNil(AppAppearanceMode.system.preferredColorScheme)
        XCTAssertEqual(AppAppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppAppearanceMode.dark.preferredColorScheme, .dark)
    }

    func testAppearanceModeRawValueRoundTripPreservesSemantic() {
        for mode in AppAppearanceMode.allCases {
            XCTAssertEqual(AppAppearanceMode(rawValue: mode.rawValue), mode)
        }
    }

    func testRepeatedAppearanceModeSetPersistsCorrectly() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )

        preferences.appearanceMode = .dark
        XCTAssertEqual(defaults.string(forKey: "app.appearanceMode"), "dark")

        preferences.appearanceMode = .dark
        XCTAssertEqual(defaults.string(forKey: "app.appearanceMode"), "dark")

        preferences.appearanceMode = .light
        XCTAssertEqual(defaults.string(forKey: "app.appearanceMode"), "light")
    }

    // MARK: - Dock icon preference tests

    func testShowsDockIconDefaultsToTrue() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertTrue(preferences.showsDockIcon, "Dock icon should be shown by default")
    }

    func testShowsDockIconPersistsWhenSetToFalse() {
        let defaults = isolatedDefaults()
        var preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        preferences.showsDockIcon = false

        preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertFalse(preferences.showsDockIcon, "Dock icon should remain hidden after re-initialization")
        XCTAssertEqual(defaults.bool(forKey: "app.showsDockIcon"), false)
    }

    func testShowsDockIconPersistsWhenSetBackToTrue() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        preferences.showsDockIcon = false
        XCTAssertFalse(preferences.showsDockIcon)

        preferences.showsDockIcon = true
        XCTAssertTrue(preferences.showsDockIcon)

        let reloaded = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertTrue(reloaded.showsDockIcon, "Dock icon should be shown after toggling back to true")
    }

    func testResetAppPreferencesRestoresShowsDockIconToDefault() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        preferences.showsDockIcon = false
        XCTAssertFalse(preferences.showsDockIcon)

        preferences.resetAppPreferences()
        XCTAssertTrue(preferences.showsDockIcon, "Reset should restore showsDockIcon to true (default)")

        let reloaded = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )
        XCTAssertTrue(reloaded.showsDockIcon, "Reset value should persist across re-initialization")
    }

    func testDockIconVisibilityPickerUsesExplicitModeLabels() {
        XCTAssertEqual(DockIconVisibility.visible.title(language: .simplifiedChinese), "显示 Dock 图标")
        XCTAssertEqual(DockIconVisibility.visible.title(language: .english), "Show Dock icon")
        XCTAssertEqual(DockIconVisibility.menuBarOnly.title(language: .simplifiedChinese), "仅菜单栏")
        XCTAssertEqual(DockIconVisibility.menuBarOnly.title(language: .english), "Menu bar only")
    }

    func testInterfaceIconNamesMatchInterfaceFamilies() {
        XCTAssertEqual(InterfacePresentation.iconName(for: "en0"), "wifi")
        XCTAssertEqual(InterfacePresentation.iconName(for: "bridge100"), "network.badge.shieldbell.fill")
        XCTAssertEqual(InterfacePresentation.iconName(for: "lo0"), "arrow.triangle.2.circlepath")
        XCTAssertEqual(InterfacePresentation.iconName(for: "utun4"), "antenna.radiowaves.left.and.right")
        XCTAssertEqual(InterfacePresentation.iconName(for: "awdl0"), "antenna.radiowaves.left.and.right")
        XCTAssertEqual(InterfacePresentation.iconName(for: "ipsec0"), "network")
    }

    func testGooglyEyesCharacterIsAvailableAsSpecialMenuBarCharacter() {
        let character = RunCatCharacter.byId("googly_eyes")

        XCTAssertEqual(character.id, "googly_eyes")
        XCTAssertEqual(character.category, .special)
        XCTAssertTrue(character.isGooglyEyes)
        XCTAssertTrue(character.supportsColorControls)
        XCTAssertEqual(character.frameWidth, 36)
    }

    func testDuplicateGooglyCatRunnerIsRemovedFromBuiltInCharacterList() {
        XCTAssertFalse(RunCatCharacter.allCharacters.contains { $0.id == "googly_cat" })
        XCTAssertFalse(RunCatCharacter.allCharacters.contains { $0.nameZh == "咕咕眼猫" })
        XCTAssertEqual(RunCatCharacter.byId("googly_cat").id, RunCatCharacter.defaultCat.id)
    }

    func testBuiltInRunnerMetadataMatchesOfficialAnimatedFrames() {
        let expected: [String: (frameCount: Int, frameWidth: Int)] = [
            "cat_b": (5, 32),
            "cat_c": (5, 42),
            "cat_tail": (8, 56),
            "mock_nyan_cat": (5, 44),
            "cheetah": (5, 41),
            "dog": (5, 33),
            "puppy": (5, 31),
            "rabbit": (5, 22),
            "frog": (5, 25),
            "cogwheel": (5, 19),
            "bonfire": (5, 14),
            "drop": (5, 22),
            "rocket": (5, 18),
            "pendulum": (8, 12),
            "reindeer": (5, 58),
            "snowman": (5, 26),
            "wind_chime": (8, 13),
            "sparkler": (5, 22),
            "golden_cat": (10, 45),
            "metal_cluster_cat": (10, 149),
            "flash_cat": (5, 42),
            "maneki_neko": (15, 14),
            "sushi": (16, 58)
        ]

        for (id, metadata) in expected {
            let character = RunCatCharacter.byId(id)
            XCTAssertEqual(character.frameCount, metadata.frameCount, id)
            XCTAssertEqual(character.frameWidth, metadata.frameWidth, id)
        }
    }

    func testOfficialRunnerResourcesContainRoleDefiningAnimationFrames() throws {
        for character in RunCatCharacter.allCharacters where !character.isGooglyEyes {
            let urls = try runnerFrameURLs(for: character)
            XCTAssertEqual(urls.count, character.frameCount, character.id)

            let uniqueFrames = Set(try urls.map { try Data(contentsOf: $0) })
            XCTAssertGreaterThanOrEqual(uniqueFrames.count, min(character.frameCount, 5), character.id)

            let firstFrame = try Data(contentsOf: urls[0])
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: firstFrame), character.id)
            XCTAssertLessThanOrEqual(bitmap.pixelsWide, character.frameWidth * 2, character.id)
        }
    }

    func testGooglyEyesCharacterUsesSelectedSolidColor() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = "googly_eyes"
        settings.catColorMode = CatColorMode.solid.rawValue
        settings.catColor = PersistedColor(red: 1, green: 0.05, blue: 0.02, alpha: 1)
        settings.showsBackground = true
        settings.backgroundOpacity = 1
        settings.backgroundColor = .olive
        settings.usesSystemTextColor = false
        settings.textColor = .black

        let image = StatusBarDisplayRenderer.image(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            scale: 2,
            catFrameIndex: 0
        )

        XCTAssertGreaterThan(
            redPixelCount(in: image, horizontalRegion: 0.0..<1.0),
            10,
            dominantColorSummary(in: image)
        )
    }

    func testArcanePrismColorModeUsesRichHighSaturationPalette() {
        let mode = CatColorMode.arcanePrism

        XCTAssertEqual(mode.displayName(zh: true), "魔法炫彩")
        XCTAssertEqual(mode.displayName(zh: false), "Arcane Prism")
        XCTAssertTrue(mode.isDynamic)
        XCTAssertTrue(mode.hasSparkles)

        let colors = mode.gradientColors(
            at: 12.5,
            frameIndex: 3,
            baseColor: PersistedColor.white,
            size: NSSize(width: 28, height: 18)
        )
        XCTAssertGreaterThanOrEqual(colors.count, 6)
        XCTAssertEqual(colors.first?.position, 0)
        XCTAssertEqual(colors.last?.position, 1)

        let components = colors.compactMap { hsbComponents(for: $0.color) }
        XCTAssertEqual(components.count, colors.count)
        XCTAssertTrue(components.allSatisfy { $0.saturation >= 0.72 })
        XCTAssertTrue(components.allSatisfy { $0.brightness >= 0.78 })
        XCTAssertGreaterThan(hueSpread(in: components), 0.45)

        let shiftedColors = mode.gradientColors(
            at: 13.1,
            frameIndex: 3,
            baseColor: PersistedColor.white,
            size: NSSize(width: 28, height: 18)
        )
        guard
            let firstHue = hsbComponents(for: colors[0].color)?.hue,
            let shiftedFirstHue = hsbComponents(for: shiftedColors[0].color)?.hue
        else {
            return XCTFail("Expected arcane prism colors to expose HSB components")
        }
        let hueDelta = max(firstHue, shiftedFirstHue) - min(firstHue, shiftedFirstHue)
        XCTAssertGreaterThan(hueDelta, 0.02)
    }

    func testHeatVisionColorModeAddsDirectionalEyeBeams() {
        let mode = CatColorMode.heatVision

        XCTAssertEqual(mode.displayName(zh: true), "热视线")
        XCTAssertEqual(mode.displayName(zh: false), "Heat Vision")
        XCTAssertTrue(mode.isDynamic)
        XCTAssertTrue(mode.hasSparkles)

        let colors = mode.gradientColors(
            at: 8.25,
            frameIndex: 1,
            baseColor: PersistedColor.white,
            size: NSSize(width: 36, height: 18)
        )
        XCTAssertGreaterThanOrEqual(colors.count, 4)

        let components = colors.compactMap { hsbComponents(for: $0.color) }
        XCTAssertEqual(components.count, colors.count)
        XCTAssertTrue(components.allSatisfy { $0.saturation >= 0.78 })
        XCTAssertTrue(components.allSatisfy { $0.brightness >= 0.82 })
        XCTAssertTrue(components.allSatisfy { component in
            component.hue <= 0.14 || component.hue >= 0.94
        })

        let rect = NSRect(x: 12, y: 4, width: 36, height: 18)
        let start = CGPoint(x: rect.midX, y: rect.midY)
        let rightEnd = StatusBarDisplayRenderer.heatVisionBeamEnd(
            from: start,
            in: rect,
            facing: .right,
            scale: 1
        )
        let leftEnd = StatusBarDisplayRenderer.heatVisionBeamEnd(
            from: start,
            in: rect,
            facing: .left,
            scale: 1
        )

        XCTAssertGreaterThan(rightEnd.x, rect.maxX)
        XCTAssertLessThan(leftEnd.x, rect.minX)
        XCTAssertEqual(rightEnd.y, leftEnd.y, accuracy: 0.01)
    }

    func testHeatVisionBeamEndFollowsGooglyEyeGazeOffset() {
        let rect = NSRect(x: 12, y: 4, width: 36, height: 18)
        let start = CGPoint(x: rect.midX, y: rect.midY)

        let upperLeftEnd = StatusBarDisplayRenderer.heatVisionBeamEnd(
            from: start,
            gazeOffset: CGSize(width: -3, height: 2),
            in: rect,
            facing: .right,
            scale: 1
        )
        let lowerRightEnd = StatusBarDisplayRenderer.heatVisionBeamEnd(
            from: start,
            gazeOffset: CGSize(width: 3, height: -2),
            in: rect,
            facing: .left,
            scale: 1
        )

        XCTAssertLessThan(upperLeftEnd.x, rect.minX)
        XCTAssertGreaterThan(upperLeftEnd.y, rect.midY)
        XCTAssertGreaterThan(lowerRightEnd.x, rect.maxX)
        XCTAssertLessThan(lowerRightEnd.y, rect.midY)
    }

    func testGooglyEyesPupilOffsetTracksMouseAndStaysInsideEye() {
        let offset = GooglyEyesTracker.pupilOffset(
            from: CGPoint(x: 10, y: 10),
            toward: CGPoint(x: 100, y: 70),
            maximumDistance: 4
        )

        XCTAssertGreaterThan(offset.width, 0)
        XCTAssertGreaterThan(offset.height, 0)
        XCTAssertLessThanOrEqual(hypot(offset.width, offset.height), 4.0001)
    }

    func testGooglyEyesPupilOffsetIsZeroWhenMouseIsAtEyeCenter() {
        let offset = GooglyEyesTracker.pupilOffset(
            from: CGPoint(x: 42, y: 24),
            toward: CGPoint(x: 42, y: 24),
            maximumDistance: 4
        )

        XCTAssertEqual(offset, .zero)
    }

    func testGooglyEyesScreenCenterSupportsSecondaryDisplayCoordinates() {
        let center = GooglyEyesTracker.screenCenter(
            forLocalCenter: CGPoint(x: 12, y: 9),
            statusItemFrame: CGRect(x: -1440, y: 900, width: 80, height: 24)
        )

        XCTAssertEqual(center, CGPoint(x: -1428, y: 909))

        let offset = GooglyEyesTracker.pupilOffset(
            from: center,
            toward: CGPoint(x: 1800, y: 909),
            maximumDistance: 4
        )
        XCTAssertGreaterThan(offset.width, 0)
        XCTAssertEqual(offset.height, 0, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(hypot(offset.width, offset.height), 4.0001)
    }

    func testGooglyEyesClickMonitorTriggersBlinkFromGlobalAndLocalClicks() {
        var globalDownHandlers: [() -> Void] = []
        var localDownHandlers: [() -> Void] = []
        var globalUpHandlers: [() -> Void] = []
        var localUpHandlers: [() -> Void] = []
        let monitor = GooglyEyesClickMonitor(
            addGlobalDownMonitor: { handler in
                globalDownHandlers.append(handler)
                return MonitorToken(name: "globalDown")
            },
            addLocalDownMonitor: { handler in
                localDownHandlers.append(handler)
                return MonitorToken(name: "localDown")
            },
            addGlobalUpMonitor: { handler in
                globalUpHandlers.append(handler)
                return MonitorToken(name: "globalUp")
            },
            addLocalUpMonitor: { handler in
                localUpHandlers.append(handler)
                return MonitorToken(name: "localUp")
            },
            removeMonitor: { _ in }
        )

        var downCount = 0
        var upCount = 0
        monitor.setActive(
            true,
            onMouseDown: { downCount += 1 },
            onMouseUp: { upCount += 1 }
        )

        // 4 handlers installed: globalDown, localDown, globalUp, localUp
        XCTAssertEqual(globalDownHandlers.count, 1)
        XCTAssertEqual(localDownHandlers.count, 1)
        XCTAssertEqual(globalUpHandlers.count, 1)
        XCTAssertEqual(localUpHandlers.count, 1)

        // Simulate mouseDown events
        globalDownHandlers[0]()
        localDownHandlers[0]()
        XCTAssertEqual(downCount, 2)
        XCTAssertEqual(upCount, 0)

        // Simulate mouseUp events
        globalUpHandlers[0]()
        localUpHandlers[0]()
        XCTAssertEqual(downCount, 2)
        XCTAssertEqual(upCount, 2)
    }

    func testGooglyEyesClickMonitorDoesNotDuplicateMonitorsAndRemovesThemWhenInactive() {
        var installCount = 0
        var removedTokens: [String] = []
        let monitor = GooglyEyesClickMonitor(
            addGlobalDownMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "globalDown")
            },
            addLocalDownMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "localDown")
            },
            addGlobalUpMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "globalUp")
            },
            addLocalUpMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "localUp")
            },
            removeMonitor: { token in
                removedTokens.append((token as? MonitorToken)?.name ?? "unknown")
            }
        )

        monitor.setActive(true, onMouseDown: {}, onMouseUp: {})
        monitor.setActive(true, onMouseDown: {}, onMouseUp: {})
        monitor.setActive(false)
        monitor.setActive(false)

        // 4 monitors: globalDown + localDown + globalUp + localUp
        XCTAssertEqual(installCount, 4)
        XCTAssertEqual(removedTokens.sorted(), ["globalDown", "globalUp", "localDown", "localUp"])
    }

    func testCharacterSizePositionAndFacingDefaultPersistAndClamp() {
        let defaults = isolatedDefaults()
        var settings = StatusBarSettings(defaults: defaults)

        XCTAssertEqual(settings.catScale, 1.0)
        XCTAssertEqual(settings.catPosition, .left)
        XCTAssertEqual(settings.catFacing, .right)

        settings.catScale = 1.2
        settings.catPosition = .right
        settings.catFacing = .left
        settings = StatusBarSettings(defaults: defaults)

        XCTAssertEqual(settings.catScale, 1.2)
        XCTAssertEqual(settings.catPosition, .right)
        XCTAssertEqual(settings.catFacing, .left)

        settings.catScale = 3
        XCTAssertEqual(settings.clampedCatScale, 1.3)
        settings.catScale = 0.1
        XCTAssertEqual(settings.clampedCatScale, 0.7)
    }

    func testCharacterScaleContributesToAutomaticWidth() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = "googly_eyes"
        settings.catScale = 1.0

        let defaultWidth = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            catFrameIndex: 0
        ).width

        settings.catScale = 1.3
        let enlargedWidth = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            catFrameIndex: 0
        ).width

        XCTAssertGreaterThan(enlargedWidth - defaultWidth, 10)
    }

    func testGooglyEyesCharacterCanRenderOnEitherSideOfText() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = "googly_eyes"
        settings.showsBackground = true
        settings.backgroundOpacity = 1
        settings.backgroundColor = .olive
        settings.usesSystemTextColor = false
        settings.textColor = .black

        settings.catPosition = .left
        let leftImage = StatusBarDisplayRenderer.image(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            scale: 2,
            catFrameIndex: 0
        )

        settings.catPosition = .right
        let rightImage = StatusBarDisplayRenderer.image(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            scale: 2,
            catFrameIndex: 0
        )

        XCTAssertGreaterThan(whitePixelCount(in: leftImage, horizontalRegion: 0.0..<0.34), 10)
        XCTAssertLessThan(whitePixelCount(in: leftImage, horizontalRegion: 0.66..<1.0), 5)
        XCTAssertGreaterThan(whitePixelCount(in: rightImage, horizontalRegion: 0.66..<1.0), 10)
        XCTAssertLessThan(whitePixelCount(in: rightImage, horizontalRegion: 0.0..<0.34), 5)
    }

    func testCharacterFacingControlsMirrorDirectionAndRenderSignature() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = "googly_cat"
        settings.catFacing = .right
        settings.catHeadSwing = false

        XCTAssertFalse(StatusBarDisplayRenderer.shouldMirrorCharacter(settings: settings, frameIndex: 0))

        let rightSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua",
            catFrameIndex: 0
        )

        settings.catFacing = .left
        XCTAssertTrue(StatusBarDisplayRenderer.shouldMirrorCharacter(settings: settings, frameIndex: 0))

        let leftSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua",
            catFrameIndex: 0
        )

        XCTAssertNotEqual(leftSignature, rightSignature)

        settings.catHeadSwing = true
        XCTAssertTrue(StatusBarDisplayRenderer.shouldMirrorCharacter(settings: settings, frameIndex: 0))
        XCTAssertFalse(StatusBarDisplayRenderer.shouldMirrorCharacter(settings: settings, frameIndex: 1))
    }

    func testCustomCharacterPixelationScaleClampsToSupportedValues() {
        XCTAssertEqual(CustomCharacterPixelationScale.clamped(0), .off)
        XCTAssertEqual(CustomCharacterPixelationScale.clamped(4), .four)
        XCTAssertEqual(CustomCharacterPixelationScale.clamped(99), .eight)
    }

    func testCustomCharacterMotionStyleDisplayNamesAreLocalized() {
        XCTAssertEqual(CustomCharacterMotionStyle.bounceBreathe.title(language: .simplifiedChinese), "呼吸/弹跳")
        XCTAssertEqual(CustomCharacterMotionStyle.swayRun.title(language: .english), "Sway/Run")
        XCTAssertEqual(CustomCharacterMotionStyle.pixelJitterFlicker.title(language: .simplifiedChinese), "像素抖动/闪烁")
        XCTAssertEqual(CustomCharacterMotionStyle.materialize.title(language: .simplifiedChinese), "显现")
        XCTAssertEqual(CustomCharacterMotionStyle.flight.title(language: .english), "Flight")
        XCTAssertEqual(CustomCharacterMotionStyle.sparkleFlash.title(language: .simplifiedChinese), "闪光")
        XCTAssertEqual(CustomCharacterMotionStyle.heartbeat.title(language: .english), "Heartbeat")
        XCTAssertEqual(CustomCharacterMotionStyle.orbitFloat.title(language: .simplifiedChinese), "漂浮旋转")
    }

    func testCharacterAssetFallsBackToBuiltInCatForMissingCustomCharacter() {
        let asset = CharacterAsset.resolve(id: "custom.missing", customCharacters: [])

        XCTAssertEqual(asset.id, RunCatCharacter.defaultCat.id)
        XCTAssertFalse(asset.isCustom)
        XCTAssertEqual(asset.frameCount, RunCatCharacter.defaultCat.frameCount)
    }

    func testStaticImageProcessorCreatesEightDistinctFramesForEachMotionStyle() async throws {
        let image = makeTestImage(size: NSSize(width: 18, height: 18), color: .systemRed)

        for style in CustomCharacterMotionStyle.allCases {
            let frames = try await CustomCharacterImageProcessor.processedStaticFrames(
                from: image,
                motionStyle: style,
                pixelation: .off
            )

            XCTAssertEqual(frames.count, 8, "Expected \(style) to generate a smoother looping frame set")
            XCTAssertTrue(frames.allSatisfy { $0.size.width > 0 && $0.size.height > 0 })
            let uniqueFrames = try Set(frames.map { try CustomCharacterImageProcessor.pngData(for: $0) })
            XCTAssertGreaterThan(uniqueFrames.count, 2, "Expected \(style) to generate visible animation changes")
        }
    }

    func testMaterializeMotionFadesImportedStaticImageIntoView() async throws {
        let image = makeTestImage(size: NSSize(width: 18, height: 18), color: .systemRed)

        let frames = try await CustomCharacterImageProcessor.processedStaticFrames(
            from: image,
            motionStyle: .materialize,
            pixelation: .off
        )

        XCTAssertLessThan(alphaTotal(in: frames[0]), alphaTotal(in: frames[3]) * 0.7)
    }

    func testPixelationProcessorReducesInteriorColorVariation() throws {
        let image = makeCheckerboardImage(size: NSSize(width: 16, height: 16))
        let originalVariation = sampledColorVariation(in: image)

        let pixelated = try CustomCharacterImageProcessor.pixelated(image, scale: .four)
        let pixelatedVariation = sampledColorVariation(in: pixelated)

        XCTAssertLessThan(pixelatedVariation, originalVariation)
    }

    func testFrameSequenceImportSortsByLocalizedFilename() throws {
        let directory = try temporaryDirectory()
        let frame10 = directory.appendingPathComponent("frame_10.png")
        let frame2 = directory.appendingPathComponent("frame_2.png")
        let frame1 = directory.appendingPathComponent("frame_1.png")
        try writeTestImage(color: .systemRed, to: frame10)
        try writeTestImage(color: .systemGreen, to: frame2)
        try writeTestImage(color: .systemBlue, to: frame1)

        let sorted = CustomCharacterImageProcessor.sortedFrameURLs([frame10, frame2, frame1])

        XCTAssertEqual(sorted.map(\.lastPathComponent), ["frame_1.png", "frame_2.png", "frame_10.png"])
    }

    func testFrameSequenceProcessorAspectFitsFramesWithoutStretching() async throws {
        let directory = try temporaryDirectory()
        let square = directory.appendingPathComponent("frame_1.png")
        let tall = directory.appendingPathComponent("frame_2.png")
        try writeTestImage(size: NSSize(width: 20, height: 20), color: .systemBlue, to: square)
        try writeTestImage(size: NSSize(width: 10, height: 20), color: .systemRed, to: tall)

        let frames = try await CustomCharacterImageProcessor.processedFrameSequence(
            from: [square, tall],
            pixelation: .off
        )

        let redBounds = coloredPixelBounds(
            in: frames[1],
            matching: { color in
                color.redComponent > 0.6 && color.redComponent > color.blueComponent + 0.3
            }
        )
        XCTAssertLessThan(redBounds.width, 14)
    }

    func testCustomCharacterStorePersistsReloadsRenamesAndDeletesCharacter() async throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source.png")
        try writeTestImage(color: .systemRed, to: source)
        let store = CustomCharacterStore(rootDirectory: root)

        let imported = try await store.importStaticImage(
            from: source,
            displayName: "Blob",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )

        XCTAssertEqual(store.characters.map(\.displayName), ["Blob"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.frameURL(for: imported, frameIndex: 0).path))

        let reloaded = CustomCharacterStore(rootDirectory: root)
        XCTAssertEqual(reloaded.characters.map(\.id), [imported.id])

        try reloaded.rename(id: imported.id, displayName: "Renamed")
        XCTAssertEqual(reloaded.characters.first?.displayName, "Renamed")

        try reloaded.delete(id: imported.id)
        XCTAssertTrue(reloaded.characters.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(imported.id).path))
    }

    func testCustomCharacterStoreRegeneratesStaticFramesWhenMotionChanges() async throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source.png")
        try writeTestImage(color: .systemPurple, to: source)
        let store = CustomCharacterStore(rootDirectory: root)
        let imported = try await store.importStaticImage(
            from: source,
            displayName: "Pulse",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )
        let originalFrame = try Data(contentsOf: store.frameURL(for: imported, frameIndex: 0))

        try await store.updateStaticCharacter(
            id: imported.id,
            motionStyle: .pixelJitterFlicker,
            pixelationScale: .four
        )

        let updated = try XCTUnwrap(store.characters.first)
        XCTAssertEqual(updated.motionStyle, .pixelJitterFlicker)
        XCTAssertEqual(updated.pixelationScale, .four)
        XCTAssertNotEqual(try Data(contentsOf: store.frameURL(for: updated, frameIndex: 0)), originalFrame)
    }

    func testCustomCharacterStoreIgnoresCorruptManifest() throws {
        let root = try temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: root.appendingPathComponent("manifest.json"))

        let store = CustomCharacterStore(rootDirectory: root)

        XCTAssertTrue(store.characters.isEmpty)
    }

    func testCustomCharacterWidthContributesToAutomaticStatusBarWidth() async throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("wide.png")
        try writeTestImage(size: NSSize(width: 44, height: 18), color: .systemRed, to: source)
        let store = CustomCharacterStore(rootDirectory: root)
        let imported = try await store.importStaticImage(
            from: source,
            displayName: "Wide",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = imported.id

        let width = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            customCharacterStore: store,
            catFrameIndex: 0
        ).width

        settings.catCharacter = "cat"
        let builtInWidth = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            customCharacterStore: store,
            catFrameIndex: 0
        ).width

        XCTAssertGreaterThan(width, builtInWidth)
    }

    func testTallUploadedCharacterKeepsAspectRatioWhenMenuBarHeightIsClamped() async throws {
        let root = try temporaryDirectory()
        let squareSource = root.appendingPathComponent("square.png")
        let tallSource = root.appendingPathComponent("tall.png")
        try writeTestImage(size: NSSize(width: 18, height: 18), color: .systemBlue, to: squareSource)
        try writeTestImage(size: NSSize(width: 18, height: 36), color: .systemRed, to: tallSource)
        let store = CustomCharacterStore(rootDirectory: root)
        let square = try await store.importStaticImage(
            from: squareSource,
            displayName: "Square",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )
        let tall = try await store.importStaticImage(
            from: tallSource,
            displayName: "Tall",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true

        settings.catCharacter = square.id
        let squareWidth = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            customCharacterStore: store,
            catFrameIndex: 0
        ).width

        settings.catCharacter = tall.id
        let tallWidth = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            customCharacterStore: store,
            catFrameIndex: 0
        ).width

        XCTAssertLessThan(tallWidth, squareWidth - 5)
    }

    func testCustomCharacterRendererDrawsImportedFramePixels() async throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("red.png")
        try writeTestImage(color: .systemRed, to: source)
        let store = CustomCharacterStore(rootDirectory: root)
        let imported = try await store.importStaticImage(
            from: source,
            displayName: "Red",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = imported.id
        settings.showsBackground = true
        settings.backgroundOpacity = 1
        settings.backgroundColor = .olive
        settings.usesSystemTextColor = false
        settings.textColor = .black

        let image = StatusBarDisplayRenderer.image(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            scale: 2,
            customCharacterStore: store,
            catFrameIndex: 0
        )

        XCTAssertGreaterThan(redPixelCount(in: image, horizontalRegion: 0.0..<0.45), 10)
    }

    func testRunCatAnimationUsesCustomFrameCount() {
        let character = CustomCharacter(
            id: "custom.frames",
            displayName: "Frames",
            sourceKind: .frameSequence,
            frameCount: 3,
            frameWidth: 18,
            frameHeight: 18,
            motionStyle: nil,
            pixelationScale: .off,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        var frames: [Int] = []
        let animation = RunCatAnimation(
            character: CharacterAsset(custom: character),
            onFrameChange: { frames.append($0) }
        )

        animation.advanceFrameForTesting()
        animation.advanceFrameForTesting()
        animation.advanceFrameForTesting()

        XCTAssertEqual(frames, [1, 2, 0])
    }

    func testPreviewFrameTimelineAnimatesNonCatBuiltInCharacters() {
        var timeline = CharacterPreviewFrameTimeline()
        let cheetah = CharacterAsset(builtIn: RunCatCharacter.byId("cheetah"))
        let pendulum = CharacterAsset(builtIn: RunCatCharacter.byId("pendulum"))

        XCTAssertEqual(timeline.displayedFrame(for: cheetah), 0)
        timeline.advance(for: cheetah)
        XCTAssertEqual(timeline.displayedFrame(for: cheetah), 1)
        timeline.advance(for: cheetah)
        XCTAssertEqual(timeline.displayedFrame(for: cheetah), 2)

        XCTAssertEqual(timeline.displayedFrame(for: pendulum), 0)
        timeline.advance(for: pendulum)
        XCTAssertEqual(timeline.displayedFrame(for: pendulum), 1)
    }

    func testImportPanelClassifiesSingleStaticImageVersusFrameSequence() throws {
        let directory = try temporaryDirectory()
        let staticImage = directory.appendingPathComponent("avatar.png")
        let gif = directory.appendingPathComponent("avatar.gif")
        let frameA = directory.appendingPathComponent("a.png")
        let frameB = directory.appendingPathComponent("b.png")

        XCTAssertEqual(CustomCharacterImportSelection.classify([staticImage])?.sourceKind, .staticImage)
        XCTAssertEqual(CustomCharacterImportSelection.classify([gif])?.sourceKind, .gif)
        XCTAssertEqual(CustomCharacterImportSelection.classify([frameB, frameA])?.sourceKind, .frameSequence)
        XCTAssertEqual(CustomCharacterImportSelection.classify([frameB, frameA])?.urls, [frameA, frameB])
    }

    func testDeletingSelectedCustomCharacterFallsBackToDefaultCat() async throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source.png")
        try writeTestImage(color: .systemRed, to: source)
        let store = CustomCharacterStore(rootDirectory: root)
        let imported = try await store.importStaticImage(
            from: source,
            displayName: "Delete Me",
            motionStyle: .bounceBreathe,
            pixelationScale: .off
        )

        try store.delete(id: imported.id)

        XCTAssertEqual(store.validCharacterID(for: imported.id), RunCatCharacter.defaultCat.id)
    }

    func testNetworkTotalsExcludeVirtualProxyInterfaces() async {
        var sampleDate = Date(timeIntervalSince1970: 1_000)
        let reader = SequenceNetworkStatsReader(samples: [
            [
                interface("en0", received: 1_000, sent: 1_000, isPrimary: true),
                interface("utun4", received: 10_000, sent: 20_000),
                interface("bridge100", received: 50_000, sent: 60_000),
                interface("awdl0", received: 7_000, sent: 8_000)
            ],
            [
                interface("en0", received: 2_200, sent: 1_700, isPrimary: true),
                interface("utun4", received: 15_000, sent: 24_000),
                interface("bridge100", received: 53_000, sent: 63_000),
                interface("awdl0", received: 7_900, sent: 8_900)
            ]
        ])
        let monitor = NetworkMonitor(
            reader: reader,
            appTrafficReader: EmptyApplicationTrafficReader(),
            now: { sampleDate }
        )

        monitor.refresh()
        // refresh() is async (Task.detached inside), yield to let it complete
        try? await Task.sleep(for: .milliseconds(100))
        sampleDate = sampleDate.addingTimeInterval(1)
        monitor.refresh()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(monitor.snapshot.downloadBytesPerSecond, 1_200)
        XCTAssertEqual(monitor.snapshot.uploadBytesPerSecond, 700)
        XCTAssertEqual(monitor.snapshot.totalReceivedBytes, 2_200)
        XCTAssertEqual(monitor.snapshot.totalSentBytes, 1_700)
    }

    func testApplicationTrafficReaderUsesExternalInterfaceScope() {
        XCTAssertEqual(
            NettopApplicationTrafficReader.arguments,
            ["-P", "-L", "1", "-x", "-t", "external", "-J", "bytes_in,bytes_out"]
        )
    }

    func testReleaseManifestDecodesFromJSON() throws {
        let json = """
        {
            "version": "0.21.0",
            "tag": "v0.21.0",
            "asset": "NetBar.app.zip",
            "asset_url": "https://github.com/sunnyhot/NetBar/releases/download/v0.21.0/NetBar.app.zip",
            "sha256": "abcdef1234567890",
            "notes": "Bug fixes and improvements",
            "html_url": "https://github.com/sunnyhot/NetBar/releases/tag/v0.21.0"
        }
        """.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: json)
        XCTAssertEqual(manifest.version, "0.21.0")
        XCTAssertEqual(manifest.tag, "v0.21.0")
        XCTAssertEqual(manifest.asset, "NetBar.app.zip")
        XCTAssertEqual(manifest.sha256, "abcdef1234567890")
        XCTAssertEqual(manifest.notes, "Bug fixes and improvements")
    }

    func testAvailableUpdateProvidesVersionTextAndReleaseBody() {
        let update = AvailableUpdate(
            release: release(
                tagName: "v0.22.0",
                name: "NetBar 0.22.0",
                body: "- 新增自动检测更新\n- 优化菜单栏交互"
            ),
            asset: GitHubReleaseAsset(
                name: "NetBar.app.zip",
                size: 2_400_000,
                browserDownloadURL: URL(string: "https://github.com/sunnyhot/NetBar/releases/download/v0.22.0/NetBar.app.zip")!
            )
        )

        XCTAssertEqual(update.versionText, "0.22.0")
        XCTAssertEqual(update.release.body, "- 新增自动检测更新\n- 优化菜单栏交互")
        XCTAssertEqual(update.release.name, "NetBar 0.22.0")
    }

    func testApplicationListSearchSortAndHideSystemProcesses() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.hidesSystemProcesses = true
        preferences.applicationSort = .name

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                app("networkd", processNames: ["networkd"], download: 9_000, upload: 1_000, total: 10_000),
                app("Xcode", processNames: ["Xcode"], download: 5_000, upload: 2_000, total: 7_000),
                app("Arc", processNames: ["Arc"], download: 2_000, upload: 4_000, total: 6_000)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: "c"
        )

        XCTAssertEqual(visible.map(\.displayName), ["Arc", "Xcode"])
    }

    func testLoginItemFailureRestoresObservedState() async {
        let manager = FakeLoginItemManager()
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: manager
        )

        await preferences.setLaunchesAtLogin(true)
        XCTAssertTrue(preferences.launchesAtLogin)
        XCTAssertNil(preferences.loginItemErrorMessage)

        manager.nextError = FakeLoginItemError()
        await preferences.setLaunchesAtLogin(false)

        XCTAssertTrue(preferences.launchesAtLogin)
        XCTAssertNotNil(preferences.loginItemErrorMessage)
    }

    func testPetStateDefaultsAreCalmAndEnabledRemindersAreConservative() {
        let settings = PetSettings.default
        let state = PetState.default(now: Date(timeIntervalSince1970: 10))

        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.isQuietModeEnabled)
        XCTAssertEqual(settings.personality, .healing)
        XCTAssertEqual(settings.highTrafficThresholdBytesPerSecond, 10_000_000)
        XCTAssertTrue(settings.enabledReminderIDs.contains(PetReminderKind.drinkWater.rawValue))
        XCTAssertTrue(settings.enabledReminderIDs.contains(PetReminderKind.restEyes.rawValue))
        XCTAssertTrue(settings.enabledReminderIDs.contains(PetReminderKind.highTraffic.rawValue))
        XCTAssertTrue(settings.enabledSkillIDs.contains(PetSkillID.networkScout.rawValue))
        XCTAssertTrue(settings.enabledSkillIDs.contains(PetSkillID.focusGuard.rawValue))
        XCTAssertTrue(settings.enabledSkillIDs.contains(PetSkillID.luckyFlash.rawValue))
        XCTAssertEqual(state.mood, .happy)
        XCTAssertEqual(state.energy, 80)
        XCTAssertEqual(state.affection, 0)
        XCTAssertNil(state.activeSkillID)
        XCTAssertNil(state.lastInteractionAt)
        XCTAssertEqual(state.createdAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(state.lastUpdatedAt, Date(timeIntervalSince1970: 10))
    }

    func testPetReminderRecordUsesStringKeysForUserDefaultsEncoding() {
        var state = PetState.default(now: Date(timeIntervalSince1970: 10))
        state.recordReminder(.highTraffic, at: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(
            state.lastReminderAtByKind[PetReminderKind.highTraffic.rawValue],
            Date(timeIntervalSince1970: 20)
        )
        XCTAssertEqual(state.lastReminderDate(for: .highTraffic), Date(timeIntervalSince1970: 20))
    }

    func testPetSkillMetadataIsLocalizedAndEnabledByDefault() {
        let scout = PetSkill.builtIn(.networkScout)
        let focus = PetSkill.builtIn(.focusGuard)
        let flash = PetSkill.builtIn(.luckyFlash)

        XCTAssertEqual(scout.title(language: .simplifiedChinese), "网络侦察")
        XCTAssertEqual(focus.title(language: .english), "Focus Guard")
        XCTAssertEqual(flash.animationHint, .sparkle)
        XCTAssertTrue(PetSkillID.defaultEnabled.contains(PetSkillID.networkScout.rawValue))
        XCTAssertTrue(PetSkillID.defaultEnabled.contains(PetSkillID.focusGuard.rawValue))
        XCTAssertTrue(PetSkillID.defaultEnabled.contains(PetSkillID.luckyFlash.rawValue))
    }

    func testPetControllerPersistsSettingsAndInteractionState() {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 100)
        let controller = PetController(defaults: defaults, now: { now })

        controller.updateSettings { settings in
            settings.isEnabled = true
            settings.personality = .playful
        }
        controller.interact(.pet)

        let reloaded = PetController(defaults: defaults, now: { now })
        XCTAssertTrue(reloaded.settings.isEnabled)
        XCTAssertEqual(reloaded.settings.personality, .playful)
        XCTAssertEqual(reloaded.state.affection, 1)
        XCTAssertEqual(reloaded.state.mood, .happy)
    }

    func testPetControllerMapsNetworkSpeedToMoodAndHighTrafficReminder() {
        let defaults = isolatedDefaults()
        var currentDate = Date(timeIntervalSince1970: 100)
        let controller = PetController(defaults: defaults, now: { currentDate })
        controller.updateSettings { settings in
            settings.isEnabled = true
            settings.highTrafficThresholdBytesPerSecond = 1_000
        }

        controller.observe(snapshot: sampleSnapshot(download: 2_000, upload: 500), appTraffic: .empty)

        XCTAssertEqual(controller.state.mood, .excited)
        XCTAssertEqual(controller.latestCue?.kind, .reminder)
        XCTAssertTrue(controller.latestCue?.message.contains(ByteFormat.speed(2_500)) == true)

        currentDate = currentDate.addingTimeInterval(60)
        controller.observe(snapshot: sampleSnapshot(download: 2_500, upload: 500), appTraffic: .empty)

        XCTAssertEqual(controller.state.lastReminderAtByKind.count, 1)
    }

    func testPetControllerHighTrafficReminderMentionsTopTrafficApplication() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
        controller.updateSettings { settings in
            settings.isEnabled = true
            settings.highTrafficThresholdBytesPerSecond = 1_000
        }
        let appTraffic = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 100),
            applications: [
                app("Quiet", processNames: ["Quiet"], download: 200, upload: 100, total: 300),
                app("Arc", processNames: ["Arc"], download: 2_500, upload: 500, total: 3_000)
            ],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        controller.observe(snapshot: sampleSnapshot(download: 2_000, upload: 500), appTraffic: appTraffic)

        XCTAssertEqual(controller.latestCue?.kind, .reminder)
        XCTAssertTrue(controller.latestCue?.message.contains("Arc") == true)
    }

    func testPetControllerEmitsCueForApplicationSpikeAnomaly() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
        controller.updateSettings { $0.isEnabled = true }
        let event = NetworkAnomalyEvent(
            kind: .applicationSpike,
            severity: .warning,
            title: "应用突增",
            message: "Chrome 当前较活跃。",
            timestamp: Date(timeIntervalSince1970: 100),
            applicationName: "Chrome",
            bytesPerSecond: 5_000_000,
            cooldownKey: "applicationSpike.Chrome"
        )

        controller.observe(anomaly: event)

        XCTAssertEqual(controller.latestCue?.kind, .networkIntelligence)
        XCTAssertTrue(controller.latestCue?.message.contains("Chrome") == true)
        XCTAssertEqual(controller.latestCue?.animationHint, .focused)
    }

    func testPetControllerMoodReflectsDailyNetworkActivity() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
        controller.updateSettings { $0.isEnabled = true }
        let summary = NetworkDailySummary(
            dateKey: "2026-06-08",
            downloadBytes: 20_000_000_000,
            uploadBytes: 1_000_000_000,
            peakDownloadBytesPerSecond: 8_000_000,
            peakUploadBytesPerSecond: 1_000_000,
            sampleCount: 120,
            activeSeconds: 3_000,
            topApplications: []
        )

        controller.observe(todaySummary: summary)

        XCTAssertEqual(controller.state.mood, .excited)
    }

    func testPetControllerMapsLowNetworkSpeedToSleepyMood() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
        controller.updateSettings { $0.isEnabled = true }

        controller.observe(snapshot: sampleSnapshot(download: 40, upload: 20), appTraffic: .empty)

        XCTAssertEqual(controller.state.mood, .sleepy)
        XCTAssertNil(controller.latestCue)
    }

    func testPetControllerHighTrafficReminderCooldownKeepsReminderDateAndCueCreationTime() {
        var currentDate = Date(timeIntervalSince1970: 100)
        let controller = PetController(defaults: isolatedDefaults(), now: { currentDate })
        controller.updateSettings { settings in
            settings.isEnabled = true
            settings.highTrafficThresholdBytesPerSecond = 1_000
        }

        controller.observe(snapshot: sampleSnapshot(download: 2_000, upload: 500), appTraffic: .empty)
        let firstReminderDate = controller.state.lastReminderDate(for: .highTraffic)
        let firstCueCreatedAt = controller.latestCue?.createdAt

        currentDate = currentDate.addingTimeInterval(15 * 60 - 1)
        controller.observe(snapshot: sampleSnapshot(download: 3_000, upload: 500), appTraffic: .empty)

        XCTAssertEqual(controller.state.lastReminderDate(for: .highTraffic), firstReminderDate)
        XCTAssertEqual(controller.latestCue?.createdAt, firstCueCreatedAt)
    }

    func testPetControllerQuietModeSuppressesReminderCue() {
        let defaults = isolatedDefaults()
        let controller = PetController(defaults: defaults, now: { Date(timeIntervalSince1970: 100) })
        controller.updateSettings { settings in
            settings.isEnabled = true
            settings.isQuietModeEnabled = true
            settings.highTrafficThresholdBytesPerSecond = 1_000
        }

        controller.observe(snapshot: sampleSnapshot(download: 3_000, upload: 0), appTraffic: .empty)

        XCTAssertNil(controller.latestCue)
        XCTAssertEqual(controller.state.mood, .excited)
    }

    func testPetControllerTickEmitsDrinkWaterAndTwentiethRestEyesReminder() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 100) })
        controller.updateSettings { $0.isEnabled = true }

        controller.tick()

        XCTAssertEqual(controller.latestCue?.kind, .reminder)
        XCTAssertEqual(controller.latestCue?.animationHint, .happyHop)
        XCTAssertEqual(controller.state.lastReminderDate(for: .drinkWater), Date(timeIntervalSince1970: 100))
        XCTAssertNil(controller.state.lastReminderDate(for: .restEyes))

        for _ in 2...20 {
            controller.tick()
        }

        XCTAssertEqual(controller.latestCue?.kind, .reminder)
        XCTAssertEqual(controller.state.lastReminderDate(for: .restEyes), Date(timeIntervalSince1970: 100))
    }

    func testPetMoodAndSkillsProvidePanelCopy() {
        XCTAssertEqual(PetMood.focused.title(language: .simplifiedChinese), "专注")
        XCTAssertEqual(PetPersonality.playful.title(language: .english), "Playful")
        XCTAssertEqual(PetReminderKind.restEyes.title(language: .simplifiedChinese), "休息眼睛")
        XCTAssertEqual(PetSkill.allBuiltIns.count, 3)
    }

    func testPetNetworkScoutSkillReportsTopTrafficApplication() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 10) })
        controller.updateSettings { $0.isEnabled = true }
        let appTraffic = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                app("Quiet", processNames: ["Quiet"], download: 100, upload: 100, total: 200),
                app("Arc", processNames: ["Arc"], download: 4_000, upload: 1_000, total: 5_000)
            ],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let cue = controller.triggerSkill(
            .networkScout,
            snapshot: sampleSnapshot(download: 4_000, upload: 1_000),
            appTraffic: appTraffic
        )

        XCTAssertEqual(cue?.kind, .skill)
        XCTAssertTrue(cue?.message.contains("Arc") == true)
    }

    func testPetNetworkScoutSkillFallsBackToSnapshotTotalSpeedWhenApplicationsAreEmpty() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 10) })
        controller.updateSettings { $0.isEnabled = true }

        let cue = controller.triggerSkill(
            .networkScout,
            snapshot: sampleSnapshot(download: 4_000, upload: 1_000),
            appTraffic: .empty
        )

        XCTAssertEqual(cue?.kind, .skill)
        XCTAssertTrue(cue?.message.contains(ByteFormat.speed(5_000)) == true)
    }

    func testPetFocusGuardSetsFocusedMoodAndActiveSkill() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 10) })
        controller.updateSettings { $0.isEnabled = true }

        _ = controller.triggerSkill(.focusGuard, snapshot: sampleSnapshot(download: 0, upload: 0), appTraffic: .empty)

        XCTAssertEqual(controller.state.mood, .focused)
        XCTAssertEqual(controller.state.activeSkillID, PetSkillID.focusGuard.rawValue)
    }

    func testPetFocusGuardExpiresAfterTwentyFiveMinutesOnTick() {
        var currentDate = Date(timeIntervalSince1970: 10)
        let controller = PetController(defaults: isolatedDefaults(), now: { currentDate })
        controller.updateSettings { $0.isEnabled = true }

        _ = controller.triggerSkill(.focusGuard, snapshot: sampleSnapshot(download: 0, upload: 0), appTraffic: .empty)

        XCTAssertEqual(controller.state.activeSkillStartedAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(controller.state.activeSkillEndsAt, Date(timeIntervalSince1970: 10 + 25 * 60))

        currentDate = Date(timeIntervalSince1970: 10 + 25 * 60 + 1)
        controller.tick()

        XCTAssertNil(controller.state.activeSkillID)
        XCTAssertNil(controller.state.activeSkillStartedAt)
        XCTAssertNil(controller.state.activeSkillEndsAt)
        XCTAssertNotEqual(controller.state.mood, .focused)
    }

    func testPetLuckyFlashSkillEmitsSparkleAndHappyMood() {
        let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 10) })
        controller.updateSettings { $0.isEnabled = true }
        controller.interact(.encourage)

        let cue = controller.triggerSkill(.luckyFlash, snapshot: sampleSnapshot(download: 0, upload: 0), appTraffic: .empty)

        XCTAssertEqual(cue?.kind, .skill)
        XCTAssertEqual(cue?.animationHint, .sparkle)
        XCTAssertEqual(controller.state.mood, .happy)
    }

    func testPetSkillCooldownSuppressesRepeatedTriggerAndAllowsAfterCooldown() {
        var currentDate = Date(timeIntervalSince1970: 10)
        let controller = PetController(defaults: isolatedDefaults(), now: { currentDate })
        controller.updateSettings { $0.isEnabled = true }

        let firstCue = controller.triggerSkill(
            .luckyFlash,
            snapshot: sampleSnapshot(download: 0, upload: 0),
            appTraffic: .empty
        )

        XCTAssertEqual(firstCue?.animationHint, .sparkle)
        XCTAssertEqual(controller.state.lastSkillTriggeredDate(for: .luckyFlash), Date(timeIntervalSince1970: 10))

        currentDate = Date(timeIntervalSince1970: 14)
        let suppressedCue = controller.triggerSkill(
            .luckyFlash,
            snapshot: sampleSnapshot(download: 0, upload: 0),
            appTraffic: .empty
        )

        XCTAssertNil(suppressedCue)
        XCTAssertEqual(controller.latestCue?.createdAt, firstCue?.createdAt)
        XCTAssertEqual(controller.state.lastSkillTriggeredDate(for: .luckyFlash), Date(timeIntervalSince1970: 10))

        currentDate = Date(timeIntervalSince1970: 15)
        let cooledDownCue = controller.triggerSkill(
            .luckyFlash,
            snapshot: sampleSnapshot(download: 0, upload: 0),
            appTraffic: .empty
        )

        XCTAssertEqual(cooledDownCue?.kind, .skill)
        XCTAssertEqual(controller.state.lastSkillTriggeredDate(for: .luckyFlash), Date(timeIntervalSince1970: 15))
    }

    func testPetSettingsCanToggleReminderAndSkillIDs() {
        var settings = PetSettings.default
        settings.enabledReminderIDs.remove(PetReminderKind.drinkWater.rawValue)
        settings.enabledSkillIDs.remove(PetSkillID.luckyFlash.rawValue)

        XCTAssertFalse(settings.isReminderEnabled(.drinkWater))
        XCTAssertFalse(settings.isSkillEnabled(.luckyFlash))

        settings.enabledReminderIDs.insert(PetReminderKind.drinkWater.rawValue)
        settings.enabledSkillIDs.insert(PetSkillID.luckyFlash.rawValue)

        XCTAssertTrue(settings.isReminderEnabled(.drinkWater))
        XCTAssertTrue(settings.isSkillEnabled(.luckyFlash))
    }

    private func runnerFrameURLs(for character: RunCatCharacter) throws -> [URL] {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = repositoryRoot
            .appendingPathComponent("Resources")
            .appendingPathComponent("RunCat")
            .appendingPathComponent(character.id)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "png" && $0.lastPathComponent.hasPrefix("frame_") }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "NetBarTests.\(UUID().uuidString)"
        isolatedDefaultSuiteNames.insert(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func sampleSnapshot(download: Double, upload: Double) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: Date(timeIntervalSince1970: 20),
            interfaces: [],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: UInt64(download),
            totalSentBytes: UInt64(upload),
            sampleCount: 2
        )
    }

    private func sampleSnapshot(
        download: Double = 0,
        upload: Double = 0,
        received: UInt64 = 0,
        sent: UInt64 = 0,
        timestamp: Date = Date(timeIntervalSince1970: 10)
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            interfaces: [
                InterfaceRate(
                    id: "en0",
                    name: "en0",
                    displayName: "Wi-Fi",
                    downloadBytesPerSecond: download,
                    uploadBytesPerSecond: upload,
                    totalReceivedBytes: received,
                    totalSentBytes: sent,
                    receivedPackets: 0,
                    sentPackets: 0,
                    isPrimary: true
                )
            ],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: received,
            totalSentBytes: sent,
            sampleCount: 1
        )
    }

    private func multiInterfaceSnapshot(timestamp: Date, interfaces: [InterfaceRate]) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            interfaces: interfaces,
            downloadBytesPerSecond: interfaces.reduce(0) { $0 + $1.downloadBytesPerSecond },
            uploadBytesPerSecond: interfaces.reduce(0) { $0 + $1.uploadBytesPerSecond },
            totalReceivedBytes: interfaces.reduce(UInt64(0)) { $0 + $1.totalReceivedBytes },
            totalSentBytes: interfaces.reduce(UInt64(0)) { $0 + $1.totalSentBytes },
            sampleCount: 1
        )
    }

    private func interfaceRate(id: String, received: UInt64, sent: UInt64) -> InterfaceRate {
        InterfaceRate(
            id: id,
            name: id,
            displayName: id,
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            totalReceivedBytes: received,
            totalSentBytes: sent,
            receivedPackets: 0,
            sentPackets: 0,
            isPrimary: id == "en0"
        )
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func isoDate(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func appRate(
        _ name: String,
        download: Double,
        upload: Double,
        received: UInt64 = 0,
        sent: UInt64 = 0
    ) -> ApplicationTrafficRate {
        ApplicationTrafficRate(
            id: name,
            displayName: name,
            processNames: [name],
            pids: [],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: received,
            totalSentBytes: sent,
            residentMemory: nil,
            cpuPercentage: nil
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeTestImage(
        size: NSSize = NSSize(width: 18, height: 18),
        color: NSColor,
        to url: URL
    ) throws {
        let image = makeTestImage(size: size, color: color)
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "NetBarTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode test image"])
        }
        try pngData.write(to: url)
    }

    private func makeTestImage(size: NSSize, color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2), xRadius: 2, yRadius: 2).fill()
        image.unlockFocus()
        return image
    }

    private func makeCheckerboardImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                let hue = CGFloat((x + y) % 16) / 16.0
                NSColor(calibratedHue: hue, saturation: 0.95, brightness: 0.95, alpha: 1).setFill()
                NSRect(x: x, y: y, width: 1, height: 1).fill()
            }
        }
        image.unlockFocus()
        return image
    }

    private func release(tagName: String, name: String?, body: String?) -> GitHubRelease {
        GitHubRelease(
            tagName: tagName,
            name: name,
            body: body,
            htmlURL: URL(string: "https://github.com/sunnyhot/NetBar/releases/tag/\(tagName)")!,
            assets: []
        )
    }

    private func interface(
        _ name: String,
        received: UInt64,
        sent: UInt64,
        isPrimary: Bool = false
    ) -> InterfaceStats {
        InterfaceStats(
            name: name,
            receivedBytes: received,
            sentBytes: sent,
            receivedPackets: received / 100,
            sentPackets: sent / 100,
            isPrimary: isPrimary
        )
    }

    private func app(
        _ displayName: String,
        processNames: [String],
        download: Double,
        upload: Double,
        total: UInt64
    ) -> ApplicationTrafficRate {
        ApplicationTrafficRate(
            id: displayName,
            displayName: displayName,
            processNames: processNames,
            pids: [123],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: total / 2,
            totalSentBytes: total / 2,
            residentMemory: nil,
            cpuPercentage: nil
        )
    }

    /// Variant of `app()` that supports optional memory/CPU fields for testing
    /// memory and CPU sort modes with apps that have no network traffic.
    private func appWithResources(
        _ displayName: String,
        processNames: [String],
        download: Double = 0,
        upload: Double = 0,
        totalReceived: UInt64 = 0,
        totalSent: UInt64 = 0,
        residentMemory: UInt64? = nil,
        cpuPercentage: Double? = nil
    ) -> ApplicationTrafficRate {
        ApplicationTrafficRate(
            id: displayName,
            displayName: displayName,
            processNames: processNames,
            pids: [123],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: totalReceived,
            totalSentBytes: totalSent,
            residentMemory: residentMemory,
            cpuPercentage: cpuPercentage
        )
    }

    private func foregroundPixelBounds(
        in image: NSImage,
        background: PersistedColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (topMargin: Int, bottomMargin: Int) {
        guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
            XCTFail("Expected bitmap image representation", file: file, line: line)
            return (0, 0)
        }

        let backgroundColor = background.nsColor.usingColorSpace(.deviceRGB) ?? background.nsColor
        var minY = bitmap.pixelsHigh
        var maxY = -1

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                    color.alphaComponent > 0.5
                else { continue }

                let distanceFromBackground =
                    abs(color.redComponent - backgroundColor.redComponent) +
                    abs(color.greenComponent - backgroundColor.greenComponent) +
                    abs(color.blueComponent - backgroundColor.blueComponent)
                guard distanceFromBackground > 0.35 else { continue }

                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        guard maxY >= minY else {
            XCTFail("Expected rendered text pixels", file: file, line: line)
            return (0, 0)
        }

        return (
            topMargin: bitmap.pixelsHigh - 1 - maxY,
            bottomMargin: minY
        )
    }

    private func whitePixelCount(in image: NSImage, horizontalRegion: Range<Double>) -> Int {
        guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
            XCTFail("Expected bitmap image representation")
            return 0
        }

        let minX = max(Int(Double(bitmap.pixelsWide) * horizontalRegion.lowerBound), 0)
        let maxX = min(Int(Double(bitmap.pixelsWide) * horizontalRegion.upperBound), bitmap.pixelsWide)
        var count = 0

        for y in 0..<bitmap.pixelsHigh {
            for x in minX..<maxX {
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                    color.alphaComponent > 0.5,
                    color.redComponent > 0.78,
                    color.greenComponent > 0.78,
                    color.blueComponent > 0.78
                else { continue }
                count += 1
            }
        }

        return count
    }

    private func redPixelCount(in image: NSImage, horizontalRegion: Range<Double>) -> Int {
        guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
            XCTFail("Expected bitmap image representation")
            return 0
        }

        let minX = max(Int(Double(bitmap.pixelsWide) * horizontalRegion.lowerBound), 0)
        let maxX = min(Int(Double(bitmap.pixelsWide) * horizontalRegion.upperBound), bitmap.pixelsWide)
        var count = 0

        for y in 0..<bitmap.pixelsHigh {
            for x in minX..<maxX {
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                    color.alphaComponent > 0.5,
                    color.redComponent > 0.72,
                    color.redComponent > color.greenComponent + 0.45,
                    color.redComponent > color.blueComponent + 0.45
                else { continue }
                count += 1
            }
        }

        return count
    }

    private func coloredPixelBounds(
        in image: NSImage,
        matching predicate: (NSColor) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (x: Int, y: Int, width: Int, height: Int) {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            XCTFail("Expected bitmap image representation", file: file, line: line)
            return (0, 0, 0, 0)
        }

        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = -1
        var maxY = -1

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                    color.alphaComponent > 0.4,
                    predicate(color)
                else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            XCTFail("Expected matching colored pixels", file: file, line: line)
            return (0, 0, 0, 0)
        }

        return (minX, minY, maxX - minX + 1, maxY - minY + 1)
    }

    private func dominantColorSummary(in image: NSImage) -> String {
        guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
            return "missing bitmap"
        }

        var best = (red: CGFloat.zero, green: CGFloat.zero, blue: CGFloat.zero, alpha: CGFloat.zero)
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let score = color.redComponent - max(color.greenComponent, color.blueComponent)
                let bestScore = best.red - max(best.green, best.blue)
                if color.alphaComponent > 0.5, score > bestScore {
                    best = (color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent)
                }
            }
        }

        return String(format: "best red-ish rgba %.3f %.3f %.3f %.3f", best.red, best.green, best.blue, best.alpha)
    }

    private func sampledColorVariation(in image: NSImage) -> Int {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            XCTFail("Expected bitmap image representation")
            return 0
        }

        var colors = Set<String>()
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                colors.insert(String(format: "%.2f-%.2f-%.2f-%.2f", color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent))
            }
        }
        return colors.count
    }

    private func alphaTotal(in image: NSImage) -> CGFloat {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            XCTFail("Expected bitmap image representation")
            return 0
        }

        var total = CGFloat.zero
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                total += color.alphaComponent
            }
        }
        return total
    }

    private func hsbComponents(for color: NSColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)? {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
        var hue = CGFloat.zero
        var saturation = CGFloat.zero
        var brightness = CGFloat.zero
        var alpha = CGFloat.zero
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness, alpha)
    }

    private func hueSpread(in components: [(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)]) -> CGFloat {
        guard
            let minimum = components.map(\.hue).min(),
            let maximum = components.map(\.hue).max()
        else {
            return 0
        }
        return maximum - minimum
    }
}

private final class FakeLoginItemManager: LoginItemManaging {
    var isEnabled = false
    var nextError: Error?

    func refreshStatus() -> Bool {
        isEnabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if let nextError {
            self.nextError = nil
            throw nextError
        }
        self.isEnabled = isEnabled
    }
}

private final class SequenceNetworkStatsReader: NetworkStatsReading {
    private var samples: [[InterfaceStats]]
    private var index = 0

    init(samples: [[InterfaceStats]]) {
        self.samples = samples
    }

    func readInterfaces() -> [InterfaceStats] {
        let sample = samples[min(index, samples.count - 1)]
        index += 1
        return sample
    }
}

private struct EmptyApplicationTrafficReader: ApplicationTrafficReading {
    func readApplications() -> ApplicationTrafficReadResult {
        ApplicationTrafficReadResult(stats: [], errorMessage: nil)
    }
}

private struct MonitorToken {
    let name: String
}

private struct FakeLoginItemError: LocalizedError {
    var errorDescription: String? {
        "Login item update failed"
    }
}

// MARK: - AnimationSpeedSource Tests

extension PreferencesAndPresentationTests {

    func testAnimationSpeedSourceDefaultIsNetworkSpeed() {
        XCTAssertEqual(
            AnimationSpeedSource(rawValue: StatusBarSettings(defaults: isolatedDefaults()).catAnimationSpeedSource),
            .networkSpeed
        )
    }

    func testAnimationSpeedSourceAllCases() {
        XCTAssertEqual(
            AnimationSpeedSource.allCases.map(\.rawValue),
            ["networkSpeed", "memoryUsage", "cpuUsage", "thermalState", "autoComposite"]
        )
    }

    func testAnimationSpeedSourceTitles() {
        XCTAssertEqual(AnimationSpeedSource.networkSpeed.title(language: .simplifiedChinese), "网速")
        XCTAssertEqual(AnimationSpeedSource.networkSpeed.title(language: .english), "Network Speed")
        XCTAssertEqual(AnimationSpeedSource.memoryUsage.title(language: .simplifiedChinese), "内存占用")
        XCTAssertEqual(AnimationSpeedSource.memoryUsage.title(language: .english), "Memory Usage")
        XCTAssertEqual(AnimationSpeedSource.cpuUsage.title(language: .simplifiedChinese), "CPU 使用率")
        XCTAssertEqual(AnimationSpeedSource.cpuUsage.title(language: .english), "CPU Usage")
        XCTAssertEqual(AnimationSpeedSource.thermalState.title(language: .simplifiedChinese), "热状态")
        XCTAssertEqual(AnimationSpeedSource.thermalState.title(language: .english), "Thermal State")
        XCTAssertEqual(AnimationSpeedSource.autoComposite.title(language: .simplifiedChinese), "自动综合")
        XCTAssertEqual(AnimationSpeedSource.autoComposite.title(language: .english), "Auto Composite")
    }

    func testStatusBarSettingsAnimationSpeedSourcePersist() {
        let defaults = isolatedDefaults()
        let settings = StatusBarSettings(defaults: defaults)

        // Default is networkSpeed
        XCTAssertEqual(settings.catAnimationSpeedSource, "networkSpeed")
        XCTAssertEqual(settings.resolvedAnimationSpeedSource, .networkSpeed)

        // Change to cpuUsage
        settings.catAnimationSpeedSource = "cpuUsage"
        XCTAssertEqual(defaults.string(forKey: "statusBar.catAnimationSpeedSource"), "cpuUsage")
        XCTAssertEqual(settings.resolvedAnimationSpeedSource, .cpuUsage)

        // Reload from defaults
        let reloaded = StatusBarSettings(defaults: defaults)
        XCTAssertEqual(reloaded.catAnimationSpeedSource, "cpuUsage")
        XCTAssertEqual(reloaded.resolvedAnimationSpeedSource, .cpuUsage)
    }

    func testStatusBarSettingsAnimationSpeedSourceInvalidFallsBack() {
        let defaults = isolatedDefaults()
        defaults.set("invalid_value", forKey: "statusBar.catAnimationSpeedSource")
        let settings = StatusBarSettings(defaults: defaults)
        XCTAssertEqual(settings.resolvedAnimationSpeedSource, .networkSpeed)
    }

    func testStatusBarSettingsAnimationSpeedSourceReset() {
        let defaults = isolatedDefaults()
        let settings = StatusBarSettings(defaults: defaults)
        settings.catAnimationSpeedSource = "memoryUsage"
        settings.reset()
        XCTAssertEqual(settings.catAnimationSpeedSource, "networkSpeed")
    }
}

// MARK: - AnimationSpeedMapper Tests

extension PreferencesAndPresentationTests {

    func testAnimationSpeedMapperMetricValue() {
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.0), .idle)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.1), .idle)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.2), .low)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.4), .low)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.5), .moderate)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.7), .moderate)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 0.8), .high)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(from: 1.0), .high)
    }

    func testAnimationSpeedMapperThermalState() {
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromThermalState: 0), .idle)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromThermalState: 1), .low)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromThermalState: 2), .moderate)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromThermalState: 3), .high)
        XCTAssertEqual(AnimationSpeedMapper.activityLevel(fromThermalState: 99), .high)
    }

    func testAnimationSpeedMapperAutoComposite() {
        // All idle → idle
        let allIdle = AnimationSpeedMapper.autoCompositeActivityLevel(
            cpuUsage: 0, memoryUsage: 0, thermalState: 0, networkActivityLevel: .idle
        )
        XCTAssertEqual(allIdle, .idle)

        // All high → high
        let allHigh = AnimationSpeedMapper.autoCompositeActivityLevel(
            cpuUsage: 1.0, memoryUsage: 1.0, thermalState: 3, networkActivityLevel: .high
        )
        XCTAssertEqual(allHigh, .high)

        // Mixed → moderate range
        let mixed = AnimationSpeedMapper.autoCompositeActivityLevel(
            cpuUsage: 0.5, memoryUsage: 0.3, thermalState: 1, networkActivityLevel: .low
        )
        // (0.5 + 0.3 + 0.333 + 0.25) / 4 ≈ 0.346 → low
        XCTAssertEqual(mixed, .low)
    }
}

// MARK: - RunCatAnimation.updateActivityLevel Tests

extension PreferencesAndPresentationTests {

    func testRunCatAnimationUpdateActivityLevel() {
        let asset = CharacterAsset(builtIn: .defaultCat)
        var lastFrame: Int?
        let animation = RunCatAnimation(character: asset, speedMultiplier: 1.0) { frame in
            lastFrame = frame
        }

        // Setting activity level should work
        animation.updateActivityLevel(.high)
        XCTAssertEqual(animation.activityLevel, .high)

        animation.updateActivityLevel(.idle)
        XCTAssertEqual(animation.activityLevel, .idle)

        animation.updateActivityLevel(.moderate)
        XCTAssertEqual(animation.activityLevel, .moderate)
    }
}

// MARK: - Mock System Metrics Reader

private final class MockSystemMetricsReader: SystemMetricsReading {
    var cpu: Double = 0
    var memory: Double = 0
    var thermal: Int = 0

    func cpuUsage() -> Double { cpu }
    func memoryUsage() -> Double { memory }
    func thermalState() -> Int { thermal }
}

// MARK: - Memory & CPU Sort Tests

extension PreferencesAndPresentationTests {

    func testApplicationSortModeDisplayModesOnlyIncludeTrafficMemoryAndCPU() {
        XCTAssertEqual(ApplicationSortMode.displayModes, [.activity, .memory, .cpu])
        XCTAssertEqual(
            ApplicationSortMode.displayModes.map { $0.title(language: .simplifiedChinese) },
            ["实时流量", "内存占用", "CPU 占用"]
        )
    }

    func testLegacyHiddenApplicationSortFallsBackToRealtimeTraffic() {
        let defaults = isolatedDefaults()
        defaults.set(ApplicationSortMode.download.rawValue, forKey: "app.applicationSort")

        let preferences = AppPreferences(
            defaults: defaults,
            loginItemManager: FakeLoginItemManager()
        )

        XCTAssertEqual(preferences.applicationSort, .activity)
    }

    func testApplicationRowMetricsFollowSelectedDisplayMode() {
        let application = appWithResources(
            "Safari",
            processNames: ["Safari"],
            download: 1_500,
            upload: 500,
            residentMemory: 512 * 1024 * 1024,
            cpuPercentage: 7.5
        )

        XCTAssertEqual(
            ApplicationTrafficPresentation.rowMetrics(for: application, displayMode: .activity),
            [
                ApplicationTrafficMetric(kind: .download, value: "1.46 KB/s"),
                ApplicationTrafficMetric(kind: .upload, value: "500 B/s")
            ]
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.rowMetrics(for: application, displayMode: .memory),
            [ApplicationTrafficMetric(kind: .memory, value: "512 MB")]
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.rowMetrics(for: application, displayMode: .cpu),
            [ApplicationTrafficMetric(kind: .cpu, value: "7.5%")]
        )
    }

    func testApplicationSummaryMetricsFollowSelectedDisplayMode() {
        let applications = [
            appWithResources(
                "Safari",
                processNames: ["Safari"],
                download: 1_500,
                upload: 500,
                residentMemory: 512 * 1024 * 1024,
                cpuPercentage: 7.5
            ),
            appWithResources(
                "Xcode",
                processNames: ["Xcode"],
                download: 500,
                upload: 250,
                residentMemory: 1024 * 1024 * 1024,
                cpuPercentage: 12.0
            )
        ]

        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(for: applications, displayMode: .activity),
            [
                ApplicationTrafficMetric(kind: .download, value: "1.95 KB/s"),
                ApplicationTrafficMetric(kind: .upload, value: "750 B/s")
            ]
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(for: applications, displayMode: .memory),
            [ApplicationTrafficMetric(kind: .memory, value: "1.50 GB")]
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(for: applications, displayMode: .cpu),
            [ApplicationTrafficMetric(kind: .cpu, value: "19.5%")]
        )
    }

    func testApplicationAttributionSummaryShowsCoverageAndLikelyProxy() {
        let applications = [
            app("mihomo-alpha", processNames: ["mihomo-alpha"], download: 60_000, upload: 20_000, total: 80_000),
            app("node", processNames: ["node"], download: 5_000, upload: 2_000, total: 7_000)
        ]
        let summary = ApplicationTrafficPresentation.attributionSummary(
            snapshot: sampleSnapshot(download: 100_000, upload: 50_000),
            applications: applications
        )

        XCTAssertEqual(summary.interfaceBytesPerSecond, 150_000)
        XCTAssertEqual(summary.applicationBytesPerSecond, 87_000)
        XCTAssertEqual(summary.coveragePercentage, 58)
        XCTAssertEqual(summary.proxyCandidateNames, ["mihomo-alpha"])
        XCTAssertEqual(summary.helperCandidateNames, ["node"])
        XCTAssertEqual(summary.status, .partial)
    }

    func testApplicationAttributionSummaryClassifiesRows() {
        XCTAssertEqual(
            ApplicationTrafficPresentation.attributionRole(
                for: app("mihomo-alpha", processNames: ["mihomo-alpha"], download: 1_000, upload: 0, total: 1_000)
            ),
            .proxyOrVPN
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.attributionRole(
                for: app("node", processNames: ["node"], download: 1_000, upload: 0, total: 1_000)
            ),
            .helper
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.attributionRole(
                for: app("networkd", processNames: ["networkd"], download: 1_000, upload: 0, total: 1_000)
            ),
            .systemService
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.attributionRole(
                for: app("Safari", processNames: ["Safari"], download: 1_000, upload: 0, total: 1_000)
            ),
            .application
        )
    }

    func testTrafficHistoryWindowFiltersRecentPoints() {
        let points = (0..<400).map { index in
            RatePoint(
                timestamp: Date(timeIntervalSince1970: Double(index)),
                downloadBytesPerSecond: Double(index),
                uploadBytesPerSecond: Double(index)
            )
        }

        XCTAssertEqual(TrafficHistoryWindow.seconds90.points(from: points).count, 91)
        XCTAssertEqual(TrafficHistoryWindow.minutes5.points(from: points).count, 301)
        XCTAssertEqual(TrafficHistoryWindow.minutes15.points(from: points).count, 400)
    }

    func testRealtimeTrafficModeHidesAppsWithoutCurrentTraffic() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.applicationSort = .activity

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appWithResources("Idle Memory App", processNames: ["Idle Memory App"], residentMemory: 500_000_000),
                appWithResources("Idle CPU App", processNames: ["Idle CPU App"], cpuPercentage: 12),
                appWithResources("Browser", processNames: ["Browser"], download: 2_000, upload: 800, residentMemory: 600_000_000),
                appWithResources("Uploader", processNames: ["Uploader"], download: 0, upload: 1_500)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: ""
        )

        XCTAssertEqual(visible.map(\.displayName), ["Browser", "Uploader"])
    }

    func testApplicationSummaryUsesVisibleApplicationsForSelectedDisplayMode() {
        let applications = [
            appWithResources("Idle Memory App", processNames: ["Idle Memory App"], residentMemory: 500_000_000),
            appWithResources("Browser", processNames: ["Browser"], download: 2_000, upload: 800, residentMemory: 600_000_000),
            appWithResources("Uploader", processNames: ["Uploader"], download: 0, upload: 1_500)
        ]

        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(
                for: ApplicationTrafficPresentation.displayApplications(applications, mode: .activity),
                displayMode: .activity
            ),
            [
                ApplicationTrafficMetric(kind: .download, value: "1.95 KB/s"),
                ApplicationTrafficMetric(kind: .upload, value: "2.25 KB/s")
            ]
        )
        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(
                for: ApplicationTrafficPresentation.displayApplications(applications, mode: .memory),
                displayMode: .memory
            ),
            [ApplicationTrafficMetric(kind: .memory, value: "1.02 GB")]
        )
    }

    /// Apps with no network traffic but valid memory data should appear in memory sort mode,
    /// sorted by residentMemory descending.
    func testMemorySortShowsAppsWithoutNetworkTraffic() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.applicationSort = .memory

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                // Safari: no network traffic, but 500 MB memory
                appWithResources("Safari", processNames: ["Safari"], residentMemory: 500_000_000),
                // Xcode: no network traffic, 1.2 GB memory (should appear first)
                appWithResources("Xcode", processNames: ["Xcode"], residentMemory: 1_200_000_000),
                // Arc: has network traffic but no memory data (should appear last with memory=0)
                app("Arc", processNames: ["Arc"], download: 5_000, upload: 2_000, total: 7_000)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: ""
        )

        // Xcode (1.2 GB) > Safari (500 MB) > Arc (0, no memory data)
        XCTAssertEqual(visible.map(\.displayName), ["Xcode", "Safari", "Arc"])
    }

    /// Apps with no network traffic but valid CPU data should appear in CPU sort mode,
    /// sorted by cpuPercentage descending.
    func testCPUSortShowsAppsWithoutNetworkTraffic() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.applicationSort = .cpu

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                // Docker: no network traffic, 45% CPU
                appWithResources("Docker", processNames: ["Docker"], cpuPercentage: 45.0),
                // Final Cut: no network traffic, 82% CPU (should appear first)
                appWithResources("Final Cut", processNames: ["Final Cut"], cpuPercentage: 82.0),
                // Firefox: has network traffic but no CPU data (should appear last with cpu=-1)
                app("Firefox", processNames: ["Firefox"], download: 3_000, upload: 1_000, total: 4_000)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: ""
        )

        // Final Cut (82%) > Docker (45%) > Firefox (-1, no CPU data)
        XCTAssertEqual(visible.map(\.displayName), ["Final Cut", "Docker", "Firefox"])
    }

    /// In CPU sort, apps with equal CPU percentage should be sorted by display name.
    func testCPUSortBreaksTiesByName() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.applicationSort = .cpu

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appWithResources("Zephyr", processNames: ["Zephyr"], cpuPercentage: 10.0),
                appWithResources("Alpha", processNames: ["Alpha"], cpuPercentage: 10.0),
                appWithResources("Middle", processNames: ["Middle"], cpuPercentage: 10.0)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: ""
        )

        // All have same CPU %, so sorted by display name ascending
        XCTAssertEqual(visible.map(\.displayName), ["Alpha", "Middle", "Zephyr"])
    }

    /// In memory sort, apps with equal memory should be sorted by display name.
    func testMemorySortBreaksTiesByName() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.applicationSort = .memory

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appWithResources("Zebra", processNames: ["Zebra"], residentMemory: 100_000_000),
                appWithResources("Apple", processNames: ["Apple"], residentMemory: 100_000_000)
            ],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: ""
        )

        // Same memory, so sorted by display name ascending
        XCTAssertEqual(visible.map(\.displayName), ["Apple", "Zebra"])
    }
}

@MainActor
private final class FakeNetworkNotificationCenter: NetworkNotificationCentering {
    var status: NetworkNotificationAuthorizationStatus
    var deliveredTitles: [String] = []
    var deliveredBodies: [String] = []

    init(authorizationStatus: NetworkNotificationAuthorizationStatus) {
        self.status = authorizationStatus
    }

    func authorizationStatus() async -> NetworkNotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> NetworkNotificationAuthorizationStatus {
        status
    }

    func deliver(title: String, body: String) async {
        deliveredTitles.append(title)
        deliveredBodies.append(body)
    }
}

private extension NetworkIntelligenceSettings {
    func withSystemNotificationsEnabled() -> NetworkIntelligenceSettings {
        var copy = self
        copy.isSystemNotificationEnabled = true
        return copy
    }
}

// MARK: - SystemMetricsSampler Tests

extension PreferencesAndPresentationTests {

    func testSystemMetricsSamplerInitialValues() {
        let mock = MockSystemMetricsReader()
        let sampler = SystemMetricsSampler(reader: mock, sampleInterval: 2.0)
        XCTAssertEqual(sampler.lastCPUUsage, 0)
        XCTAssertEqual(sampler.lastMemoryUsage, 0)
        XCTAssertEqual(sampler.lastThermalState, 0)
    }
}
