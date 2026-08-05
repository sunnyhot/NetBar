import AppKit
import Combine
import XCTest
@testable import NetBar

@MainActor
final class PreferencesAndPresentationTests: XCTestCase {
    private nonisolated let isolatedDefaultSuiteNames = LockedValue<Set<String>>([])

    nonisolated override func tearDown() {
        for suiteName in isolatedDefaultSuiteNames.withValue({ $0 }) {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        isolatedDefaultSuiteNames.set([])
        super.tearDown()
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2,
        pollInterval: Duration = .milliseconds(10),
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for \(description)", file: file, line: line)
                return
            }
            try await Task.sleep(for: pollInterval)
        }
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

    func testStatusBarBackgroundAutomaticWidthUsesCompactHorizontalPadding() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsBackground = true
        settings.showsCat = false
        settings.trafficDisplayMode = .upDown
        settings.showsArrows = true

        let font = NSFont.monospacedDigitSystemFont(
            ofSize: settings.clampedFontSize,
            weight: settings.fontWeight
        )
        let stableTextWidth = [
            "↑ 999 KB/s",
            "↓ 999 KB/s",
            "↑ 9.99 MB/s",
            "↓ 9.99 MB/s"
        ]
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? 1

        let presentation = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 48_000, upload: 163_000),
            settings: settings
        )

        XCTAssertEqual(presentation.width, ceil(stableTextWidth + 6))
        XCTAssertEqual(
            StatusBarDisplayRenderer.stableMinimumWidth(settings: settings),
            ceil(stableTextWidth + 6)
        )
    }

    func testStatusBarRenderedImageCacheReusesMatchingSignatureAndEvictsOldest() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        let cache = StatusBarRenderedImageCache(limit: 2)
        let snapshot = sampleSnapshot(download: 42_000, upload: 9_500)
        let firstSignature = StatusBarDisplayRenderer.signature(
            snapshot: snapshot,
            settings: settings,
            appearanceName: "NSAppearanceNameAqua"
        )
        let secondSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 43_000, upload: 9_500),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua"
        )
        let thirdSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 44_000, upload: 9_500),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua"
        )

        let firstImage = NSImage(size: NSSize(width: 10, height: 10))
        let secondImage = NSImage(size: NSSize(width: 11, height: 10))
        let thirdImage = NSImage(size: NSSize(width: 12, height: 10))

        cache.store(firstImage, for: firstSignature)
        cache.store(secondImage, for: secondSignature)

        XCTAssertTrue(cache.image(for: firstSignature) === firstImage)

        cache.store(thirdImage, for: thirdSignature)

        XCTAssertNil(cache.image(for: secondSignature))
        XCTAssertTrue(cache.image(for: firstSignature) === firstImage)
        XCTAssertTrue(cache.image(for: thirdSignature) === thirdImage)
    }

    func testStatusBarPreviewRenderCacheReusesMatchingPreviewImage() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = RunCatCharacter.defaultCat.id
        let snapshot = sampleSnapshot(download: 42_000, upload: 9_500)
        let cache = StatusBarPreviewRenderCache(limit: 2)
        var renderCount = 0

        let first = cache.render(
            snapshot: snapshot,
            settings: settings,
            scale: 2,
            catFrameIndex: 0,
            renderTime: 100,
            imageFactory: { _, _, _, _, _ in
                renderCount += 1
                return NSImage(size: NSSize(width: 18, height: 18))
            }
        )
        let second = cache.render(
            snapshot: snapshot,
            settings: settings,
            scale: 2,
            catFrameIndex: 0,
            renderTime: 100,
            imageFactory: { _, _, _, _, _ in
                renderCount += 1
                return NSImage(size: NSSize(width: 24, height: 18))
            }
        )
        let third = cache.render(
            snapshot: snapshot,
            settings: settings,
            scale: 2,
            catFrameIndex: 1,
            renderTime: 100,
            imageFactory: { _, _, _, _, _ in
                renderCount += 1
                return NSImage(size: NSSize(width: 30, height: 18))
            }
        )

        XCTAssertEqual(renderCount, 2)
        XCTAssertTrue(first.image === second.image)
        XCTAssertFalse(second.image === third.image)
        XCTAssertEqual(first.presentation, second.presentation)
    }

    func testCatAnimationConfigurationIgnoresTextOnlySettings() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = RunCatCharacter.defaultCat.id
        let baseline = StatusBarCatAnimationConfiguration(settings: settings, customCharacterRevision: 1)

        settings.isBold.toggle()
        settings.showsArrows.toggle()
        settings.usesSystemTextColor.toggle()
        settings.fontSize += 1

        XCTAssertEqual(
            baseline,
            StatusBarCatAnimationConfiguration(settings: settings, customCharacterRevision: 1)
        )

        settings.catSpeedMultiplier += 0.25

        XCTAssertNotEqual(
            baseline,
            StatusBarCatAnimationConfiguration(settings: settings, customCharacterRevision: 1)
        )
    }

    func testStatusBarPulseRenderPolicyDisablesBucketForIdleAndReducedMotion() {
        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: sampleSnapshot(download: 0, upload: 0),
                reduceMotion: false,
                renderTime: 12.4
            ),
            0
        )

        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: sampleSnapshot(download: 2_000_000, upload: 100_000),
                reduceMotion: true,
                renderTime: 12.4
            ),
            0
        )
    }

    func testStatusBarPulseRenderPolicyQuantizesActiveTrafficAtTwoHz() {
        let snapshot = sampleSnapshot(download: 2_000_000, upload: 100_000)

        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: false,
                renderTime: 10.24
            ),
            20
        )
        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: false,
                renderTime: 10.26
            ),
            20
        )
        XCTAssertEqual(
            StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: false,
                renderTime: 10.51
            ),
            21
        )
    }

    func testStatusBarSignatureIncludesPulseBucketOnlyForActiveTraffic() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())

        let idleSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 0, upload: 0),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua",
            renderTime: 10.51,
            reduceMotion: false
        )
        XCTAssertEqual(idleSignature.statusPulseTimeBucket, 0)

        let activeSignature = StatusBarDisplayRenderer.signature(
            snapshot: sampleSnapshot(download: 2_000_000, upload: 100_000),
            settings: settings,
            appearanceName: "NSAppearanceNameAqua",
            renderTime: 10.51,
            reduceMotion: false
        )
        XCTAssertEqual(activeSignature.statusPulseTimeBucket, 21)
    }

    func testStatusBarTextLayoutCacheReusesMatchingInputs() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        let cache = StatusBarTextLayoutCache(limit: 2)
        let key = StatusBarTextLayoutCacheKey(
            lines: ["down", "up"],
            fontSize: settings.fontSize,
            isBold: settings.isBold,
            lineSpacing: settings.lineSpacing,
            alignment: settings.alignment,
            showsBackground: settings.showsBackground
        )
        let layout = StatusBarCachedTextLayout(
            width: 48,
            horizontalPadding: 2,
            lines: ["down", "up"]
        )

        cache.store(layout, for: key)

        XCTAssertEqual(cache.layout(for: key), layout)
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


    func testDiagnosticsCenterBuildsPrivacySafeSummaryText() {
        let snapshot = DiagnosticsSnapshot(
            appVersion: "v0.39.0",
            bundleIdentifier: "local.codex.NetBar",
            updateStatus: "检查更新失败：network offline",
            lastCheckedAt: Date(timeIntervalSince1970: 100),
            sampling: NetworkSamplingDiagnostics(
                isRunning: true,
                isApplicationTrafficVisible: false,
                isApplicationTrafficSamplingEnabled: false,
                isPowerSaveModeEnabled: true
            ),
            notificationAuthorization: "authorized",
            historyStatus: "available",
            historyPath: "/Users/example/Library/Application Support/NetBar/NetworkHistory.json"
        )

        let text = DiagnosticsCenter.copyText(for: snapshot, language: .english)

        XCTAssertTrue(text.contains("NetBar Diagnostics"))
        XCTAssertTrue(text.contains("v0.39.0"))
        XCTAssertTrue(text.contains("powerSave=true"))
        XCTAssertFalse(text.contains("https://"))
        XCTAssertFalse(text.contains("example.com"))
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

    func testAnimatedCharacterCatalogDoesNotRunItsOwnTimer() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "MenuBarSubcomponents.swift"]
        )
        let catalogStart = try XCTUnwrap(source.range(of: "struct AnimatedCharacterCatalog"))
        let catalogEnd = source.range(of: "// MARK: -", range: catalogStart.upperBound..<source.endIndex)?.lowerBound ?? source.endIndex
        let catalogSource = String(source[catalogStart.lowerBound..<catalogEnd])

        XCTAssertFalse(catalogSource.contains("Timer.publish"))
        XCTAssertTrue(catalogSource.contains("characterPickerFrameTick ?? 0"))
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
            forWindowSize: NSSize(
                width: LivingSignalLayout.preferredPopoverWidth,
                height: 700
            ),
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
            forWindowSize: NSSize(
                width: LivingSignalLayout.preferredPopoverWidth,
                height: LivingSignalLayout.preferredPopoverHeight
            ),
            minimumSize: NSSize(
                width: LivingSignalLayout.minimumPopoverWidth,
                height: LivingSignalLayout.minimumPopoverHeight
            ),
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            padding: 10
        )

        XCTAssertEqual(frame.width, LivingSignalLayout.preferredPopoverWidth)
        XCTAssertEqual(frame.maxY, anchorFrame.minY, accuracy: 0.5)
    }

    func testDetailsWindowLayoutTouchesVisibleFrameTopWhenAnchoredAtMenuBarEdge() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1200, height: 878)
        let anchorFrame = NSRect(x: 590, y: 878, width: 20, height: 20)

        let frame = DetailsWindowLayout.frame(
            forWindowSize: NSSize(
                width: LivingSignalLayout.preferredPopoverWidth,
                height: LivingSignalLayout.preferredPopoverHeight
            ),
            minimumSize: NSSize(
                width: LivingSignalLayout.minimumPopoverWidth,
                height: LivingSignalLayout.minimumPopoverHeight
            ),
            visibleFrame: visibleFrame,
            anchorFrame: anchorFrame,
            padding: 10
        )

        XCTAssertEqual(frame.width, LivingSignalLayout.preferredPopoverWidth)
        XCTAssertEqual(frame.maxY, visibleFrame.maxY, accuracy: 0.5)
    }

    func testDetailsWindowLayoutShrinksLivingSignalWidthForSmallVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 470, height: 700)
        let frame = DetailsWindowLayout.frame(
            forWindowSize: NSSize(
                width: LivingSignalLayout.preferredPopoverWidth,
                height: LivingSignalLayout.preferredPopoverHeight
            ),
            minimumSize: NSSize(
                width: LivingSignalLayout.minimumPopoverWidth,
                height: LivingSignalLayout.minimumPopoverHeight
            ),
            visibleFrame: visibleFrame,
            anchorFrame: nil,
            padding: 10
        )

        XCTAssertLessThanOrEqual(frame.width, 450)
        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX + 10)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX - 10)
    }

    func testDetailsWindowControllerUsesLivingSignalWindowSizes() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "DetailsWindowController.swift"]
        )

        XCTAssertTrue(source.contains("LivingSignalLayout.preferredPopoverWidth"))
        XCTAssertTrue(source.contains("LivingSignalLayout.preferredPopoverHeight"))
        XCTAssertTrue(source.contains("LivingSignalLayout.minimumPopoverWidth"))
        XCTAssertTrue(source.contains("LivingSignalLayout.minimumPopoverHeight"))
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

    func testDeferredMainActorActionSchedulerRunsAfterDelay() async throws {
        var calls: [String] = []
        let scheduler = DeferredMainActorActionScheduler(delay: .milliseconds(20))
        defer { scheduler.cancel() }

        scheduler.schedule {
            calls.append("refresh")
        }

        XCTAssertEqual(
            calls,
            [],
            "Opening the panel should not synchronously refresh the whole detail model before the first frame"
        )

        try await waitUntil("deferred refresh callback") {
            calls == ["refresh"]
        }

        XCTAssertEqual(calls, ["refresh"])
    }

    func testDeferredMainActorActionSchedulerCancelsAndCoalescesWork() async throws {
        var calls: [String] = []
        let scheduler = DeferredMainActorActionScheduler(delay: .milliseconds(20))
        defer { scheduler.cancel() }

        scheduler.schedule {
            calls.append("first")
        }
        scheduler.schedule {
            calls.append("second")
        }

        try await waitUntil("coalesced deferred refresh callback") {
            calls == ["second"]
        }

        XCTAssertEqual(calls, ["second"])

        scheduler.schedule {
            calls.append("cancelled")
        }
        scheduler.cancel()

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(calls, ["second"])
    }

    func testDetailsWindowActivityRefreshPolicyThrottlesHighFrequencyPointerEvents() {
        var policy = DetailsWindowActivityRefreshPolicy(minimumRefreshInterval: 1.0)

        XCTAssertFalse(DetailsWindowActivityRefreshPolicy.eventMask.contains(.mouseMoved))
        XCTAssertTrue(DetailsWindowActivityRefreshPolicy.eventMask.contains(.scrollWheel))
        XCTAssertTrue(policy.shouldRefresh(at: Date(timeIntervalSince1970: 10)))
        XCTAssertFalse(policy.shouldRefresh(at: Date(timeIntervalSince1970: 10.2)))
        XCTAssertTrue(policy.shouldRefresh(at: Date(timeIntervalSince1970: 11.1)))
    }

    func testApplicationTrafficVisibilitySchedulerDefersResumeAndKeepsShortReopensWarm() async throws {
        var isDetailVisible = true
        var visibilityChanges: [Bool] = []
        let scheduler = ApplicationTrafficVisibilityScheduler(
            resumeDelay: .milliseconds(20),
            pauseDelay: .milliseconds(20),
            isDetailWindowVisible: { isDetailVisible },
            setApplicationTrafficVisible: { visibilityChanges.append($0) }
        )
        defer { scheduler.invalidate() }

        scheduler.scheduleResume()

        XCTAssertEqual(
            visibilityChanges,
            [],
            "Opening the panel should not synchronously start nettop before the UI is on screen"
        )

        try await waitUntil("application traffic resume") {
            visibilityChanges == [true]
        }
        XCTAssertEqual(visibilityChanges, [true])

        isDetailVisible = false
        scheduler.schedulePause()
        isDetailVisible = true
        scheduler.scheduleResume()

        try await waitUntil("warm application traffic resume") {
            visibilityChanges == [true, true]
        }

        XCTAssertEqual(
            visibilityChanges,
            [true, true],
            "Reopening before the pause window expires should keep app traffic sampling warm"
        )
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

        let preferences = AppPreferences(
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
        XCTAssertEqual(settings.isHistoryTrackingEnabled, NetworkIntelligenceSettings.default.isHistoryTrackingEnabled)
    }

    func testNetworkIntelligenceSettingsIgnoresRemovedInsightFields() throws {
        let legacyJSON = """
        {
          "hasSeenNotificationOnboarding": true,
          "isAnomalyDetectionEnabled": false,
          "isSystemNotificationEnabled": true,
          "highTrafficThreshold": 26214400,
          "isApplicationSpikeAlertEnabled": false,
          "isNetworkDropAlertEnabled": true,
          "isHistoryTrackingEnabled": true,
          "isInsightStreamEnabled": true,
          "insightRetentionLimit": 20,
          "isInsightSuggestionEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(NetworkIntelligenceSettings.self, from: legacyJSON)

        XCTAssertTrue(decoded.hasSeenNotificationOnboarding)
        XCTAssertFalse(decoded.isAnomalyDetectionEnabled)
        XCTAssertEqual(decoded.highTrafficThreshold, .mbps25)

        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(encoded.contains("isInsightStreamEnabled"))
        XCTAssertFalse(encoded.contains("insightRetentionLimit"))
        XCTAssertFalse(encoded.contains("isInsightSuggestionEnabled"))
        XCTAssertFalse(encoded.contains("isApplicationSpikeAlertEnabled"))
        XCTAssertFalse(encoded.contains("isNetworkDropAlertEnabled"))
    }

    func testAppPreferencesPersistNetworkIntelligenceSettings() {
        let defaults = isolatedDefaults()
        let preferences = AppPreferences(defaults: defaults, loginItemManager: FakeLoginItemManager())

        preferences.networkIntelligenceSettings = NetworkIntelligenceSettings(
            hasSeenNotificationOnboarding: true,
            isAnomalyDetectionEnabled: false,
            isSystemNotificationEnabled: true,
            highTrafficThreshold: .mbps25,
            isHistoryTrackingEnabled: true
        )

        let reloaded = AppPreferences(defaults: defaults, loginItemManager: FakeLoginItemManager())

        XCTAssertEqual(reloaded.networkIntelligenceSettings.highTrafficThreshold, .mbps25)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.hasSeenNotificationOnboarding)
        XCTAssertFalse(reloaded.networkIntelligenceSettings.isAnomalyDetectionEnabled)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.isSystemNotificationEnabled)
        XCTAssertTrue(reloaded.networkIntelligenceSettings.isHistoryTrackingEnabled)
    }

    func testNetworkAnomalyEventLocalizedTitles() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start),
            settings: settings,
            now: start,
            language: .simplifiedChinese
        )
        let events = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            settings: settings,
            now: start.addingTimeInterval(11),
            language: .simplifiedChinese
        )

        XCTAssertEqual(events.first?.title, "高流量")
    }

    func testNetworkAnomalyDetectorEmitsHighTrafficAfterSustainedThreshold() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start), settings: settings, now: start).isEmpty)

        let events = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            settings: settings,
            now: start.addingTimeInterval(11)
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "高流量")
    }

    func testNetworkAnomalyDetectorClearsHighTrafficTimerWhenDisabled() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        var disabledSettings = settings
        disabledSettings.isAnomalyDetectionEnabled = false
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start), settings: settings, now: start)
        _ = detector.detect(snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(5)), settings: disabledSettings, now: start.addingTimeInterval(5))

        let staleWindow = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            settings: settings,
            now: start.addingTimeInterval(11)
        )

        XCTAssertTrue(staleWindow.isEmpty)

        let restartedWindow = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(21)),
            settings: settings,
            now: start.addingTimeInterval(21)
        )

        XCTAssertEqual(restartedWindow.count, 1)
    }

    func testNetworkAnomalyDetectorUsesRequestedLanguageForEventPresentation() {
        var detector = NetworkAnomalyDetector()
        let settings = NetworkIntelligenceSettings.default
        let start = Date(timeIntervalSince1970: 100)

        _ = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start),
            settings: settings,
            now: start,
            language: .english
        )
        let events = detector.detect(
            snapshot: sampleSnapshot(download: 11_000_000, upload: 500_000, timestamp: start.addingTimeInterval(11)),
            settings: settings,
            now: start.addingTimeInterval(11),
            language: .english
        )

        XCTAssertEqual(events.first?.title, "High traffic")
        XCTAssertEqual(events.first?.message, "Current total speed is about 11.0 MB/s.")
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
            title: "High",
            message: "Traffic",
            timestamp: Date(timeIntervalSince1970: 100)
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
            title: "High",
            message: "Traffic",
            timestamp: currentDate
        )

        await controller.refreshAuthorizationStatus()
        await controller.handle(event, settings: settings)
        currentDate = currentDate.addingTimeInterval(600)
        await controller.handle(event, settings: settings)

        XCTAssertEqual(center.deliveredTitles, ["High", "High"])
    }

    func testNetworkNotificationControllerDoesNotSendWhenAuthorizationDenied() async {
        let center = FakeNetworkNotificationCenter(authorizationStatus: .denied)
        let controller = NetworkNotificationController(center: center, now: { Date(timeIntervalSince1970: 100) })
        let settings = NetworkIntelligenceSettings.default.withSystemNotificationsEnabled()
        let event = NetworkAnomalyEvent(
            title: "High",
            message: "Traffic",
            timestamp: Date(timeIntervalSince1970: 100)
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

    func testNetworkDailySummaryPresentationFormatsTodayEstimate() {
        let today = NetworkDailySummary(
            dateKey: "2026-06-08",
            downloadBytes: 10_000_000,
            uploadBytes: 5_000_000,
            peakDownloadBytesPerSecond: 2_000_000,
            peakUploadBytesPerSecond: 1_000_000,
            sampleCount: 20,
            activeSeconds: 80,
            animationPlaybackCount: 42
        )
        let summary = NetworkIntelligenceSummary(
            latestEvent: nil,
            today: today,
            animationPlaybackCountsByCharacter: [
                "cat": 11,
                "cat_b": 31
            ]
        )

        let cards = NetworkDailySummaryPresentation.cards(for: summary, language: .english)

        XCTAssertEqual(cards.map(\.title), ["Today Down", "Today Up", "Peak", "Active", "Anim Plays", "Favorite Hero"])
        XCTAssertEqual(cards.map(\.id), ["down", "up", "peak", "active", "animation", "favoriteCharacter"])
        XCTAssertEqual(cards.first { $0.id == "active" }?.value, "1m")
        XCTAssertEqual(cards.first { $0.id == "animation" }?.value, "42 plays")
        XCTAssertEqual(cards.first { $0.id == "favoriteCharacter" }?.value, "Cat β · 31 plays")
        XCTAssertNil(cards.first { $0.id == "favoriteCharacter" }?.milestone)
    }

    func testCharacterPlaybackMilestoneThresholds() {
        XCTAssertNil(CharacterPlaybackMilestone(count: 49_999))
        XCTAssertEqual(CharacterPlaybackMilestone(count: 50_000), .spark)
        XCTAssertEqual(CharacterPlaybackMilestone(count: 99_999), .spark)
        XCTAssertEqual(CharacterPlaybackMilestone(count: 100_000), .volt)
        XCTAssertEqual(CharacterPlaybackMilestone(count: 499_999), .volt)
        XCTAssertEqual(CharacterPlaybackMilestone(count: 500_000), .crown)
        XCTAssertEqual(CharacterPlaybackMilestone(count: 999_999), .crown)
        XCTAssertEqual(CharacterPlaybackMilestone(count: 1_000_000), .legend)
    }

    func testNetworkDailySummaryPresentationAppliesFavoriteMilestone() {
        let today = NetworkDailySummary.empty(dateKey: "2026-06-11")
        let summary = NetworkIntelligenceSummary(
            latestEvent: nil,
            today: today,
            animationPlaybackCountsByCharacter: [
                "cat": 100_000,
                "dog": 500_000
            ]
        )

        let cards = NetworkDailySummaryPresentation.cards(for: summary, language: .english)

        XCTAssertEqual(cards.first { $0.id == "favoriteCharacter" }?.milestone, .crown)
        XCTAssertNil(cards.first { $0.id == "animation" }?.milestone)
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

    func testNetworkHistoryStoreDefersDiskWriteUntilFlush() throws {
        let root = try temporaryDirectory()
        let historyURL = root.appendingPathComponent("NetworkHistory.json")
        let store = NetworkHistoryStore(
            rootDirectory: root,
            calendar: fixedCalendar(),
            now: { Date(timeIntervalSince1970: 0) },
            saveDebounceInterval: 20
        )

        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000))

        XCTAssertFalse(FileManager.default.fileExists(atPath: historyURL.path))

        store.flushNow()

        XCTAssertTrue(FileManager.default.fileExists(atPath: historyURL.path))
    }

    func testNetworkHistoryStoreClearFlushesImmediately() throws {
        let root = try temporaryDirectory()
        let historyURL = root.appendingPathComponent("NetworkHistory.json")
        let store = NetworkHistoryStore(
            rootDirectory: root,
            calendar: fixedCalendar(),
            now: { Date(timeIntervalSince1970: 0) },
            saveDebounceInterval: 20
        )

        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000))
        store.clear()

        XCTAssertTrue(FileManager.default.fileExists(atPath: historyURL.path))
        let reloaded = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(reloaded.summary.today.downloadBytes, 0)
        XCTAssertEqual(reloaded.summary.today.uploadBytes, 0)
    }

    func testNetworkHistoryStoreAccumulatesAnimationPlaybacksForToday() throws {
        let root = try temporaryDirectory()
        var currentDate = isoDate("2026-06-08T12:00:00Z")
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

        store.recordAnimationPlayback(count: 2, characterID: "cat", at: currentDate)
        store.recordAnimationPlayback(count: 3, characterID: "dog", at: currentDate)

        XCTAssertEqual(store.summary.today.animationPlaybackCount, 5)
        XCTAssertEqual(store.summary.today.animationPlaybackCountsByCharacter["cat"], 2)
        XCTAssertEqual(store.summary.today.animationPlaybackCountsByCharacter["dog"], 3)
        XCTAssertEqual(store.summary.animationPlaybackCountsByCharacter["cat"], 2)
        XCTAssertEqual(store.summary.animationPlaybackCountsByCharacter["dog"], 3)
        XCTAssertEqual(store.summary.favoriteAnimationCharacterID, "dog")

        currentDate = isoDate("2026-06-09T00:00:01Z")
        store.recordAnimationPlayback(count: 1, characterID: "cat", at: currentDate)

        // After day rollover, today resets but global animation counts persist across days.
        XCTAssertEqual(store.summary.today.dateKey, "2026-06-09")
        XCTAssertEqual(store.summary.today.animationPlaybackCount, 1)
        XCTAssertEqual(store.summary.today.animationPlaybackCountsByCharacter["cat"], 1)
        XCTAssertEqual(store.summary.animationPlaybackCountsByCharacter["cat"], 3)
        XCTAssertEqual(store.summary.animationPlaybackCountsByCharacter["dog"], 3)
        XCTAssertEqual(store.summary.favoriteAnimationCharacterID, "cat")
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

    func testNetworkHistoryStoreResetsTodayAcrossDays() throws {
        let root = try temporaryDirectory()
        let startDate = isoDate("2026-06-01T12:00:00Z")
        var currentDate = startDate
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

        // Day 1: record two snapshots so a byte delta is accumulated.
        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000, timestamp: currentDate))
        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_800, sent: 2_600, timestamp: isoDate("2026-06-01T12:00:01Z")))
        XCTAssertEqual(store.summary.today.dateKey, "2026-06-01")
        XCTAssertEqual(store.summary.today.downloadBytes, 800)

        // Day 2: today resets; multi-day history is no longer retained
        currentDate = fixedCalendar().date(byAdding: .day, value: 1, to: startDate)!
        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 3_000, sent: 4_000, timestamp: currentDate))

        XCTAssertEqual(store.summary.today.dateKey, "2026-06-02")
        // Only the delta from the day-2 first sample (no previous snapshot yet) — counts as 0 bytes.
        XCTAssertEqual(store.summary.today.downloadBytes, 0)
    }

    func testNetworkHistoryStoreSkipsWritesWhenTrackingDisabled() throws {
        let root = try temporaryDirectory()
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })
        store.configure(isTrackingEnabled: false)

        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000))

        XCTAssertEqual(store.summary.today.downloadBytes, 0)
        XCTAssertEqual(store.summary.today.uploadBytes, 0)
    }

    func testNetworkHistoryStoreDoesNotRepublishUnchangedConfiguration() throws {
        let store = NetworkHistoryStore(
            rootDirectory: try temporaryDirectory(),
            calendar: fixedCalendar(),
            now: { Date(timeIntervalSince1970: 0) }
        )
        var publicationCount = 0
        let cancellable = store.$summary.dropFirst().sink { _ in
            publicationCount += 1
        }

        store.configure(isTrackingEnabled: true)

        XCTAssertEqual(publicationCount, 0)
        withExtendedLifetime(cancellable) {}
    }

    func testNetworkHistoryStoreBacksUpUnreadableStorage() throws {
        let root = try temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let historyURL = root.appendingPathComponent("NetworkHistory.json")
        try Data("not-json".utf8).write(to: historyURL)

        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { Date(timeIntervalSince1970: 0) })

        guard case .unreadableBackupCreated(let backupURL) = store.storageStatus else {
            return XCTFail("Expected unreadable backup status")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(store.summary.today.dateKey, "1970-01-01")
    }


    func testTrafficHistoryWindowPresentationFiltersPointsAndSummarizesTotals() {
        let latest = Date(timeIntervalSince1970: 1_000)
        let points = [
            RatePoint(timestamp: latest.addingTimeInterval(-400), downloadBytesPerSecond: 10, uploadBytesPerSecond: 1),
            RatePoint(timestamp: latest.addingTimeInterval(-60), downloadBytesPerSecond: 20, uploadBytesPerSecond: 2),
            RatePoint(timestamp: latest, downloadBytesPerSecond: 30, uploadBytesPerSecond: 3)
        ]

        let model = TrafficHistoryWindowPresentation.make(points: points, window: .seconds90)

        XCTAssertEqual(model.points.map(\.downloadBytesPerSecond), [20, 30])
        XCTAssertEqual(model.peakDownloadBytesPerSecond, 30)
        XCTAssertEqual(model.peakUploadBytesPerSecond, 3)
        XCTAssertEqual(model.normalizedDownloadValues, [2.0 / 3.0, 1.0])
        XCTAssertEqual(model.normalizedUploadValues, [2.0 / 3.0, 1.0])
    }


    func testNetworkHistoryStoreResetsStaleTodayOnReloadAcrossDays() throws {
        let root = try temporaryDirectory()
        var currentDate = isoDate("2026-06-01T12:00:00Z")
        let store = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })
        store.record(snapshot: sampleSnapshot(download: 100, upload: 50, received: 1_000, sent: 2_000, timestamp: currentDate))
        store.record(snapshot: sampleSnapshot(download: 300, upload: 200, received: 1_800, sent: 2_600, timestamp: isoDate("2026-06-01T12:00:01Z")))
        store.flushNow()

        // Reload on the next day: stale yesterday's `today` is dropped (no multi-day retention).
        currentDate = isoDate("2026-06-02T12:00:00Z")
        let reloaded = NetworkHistoryStore(rootDirectory: root, calendar: fixedCalendar(), now: { currentDate })

        XCTAssertEqual(reloaded.summary.today.dateKey, "2026-06-02")
        XCTAssertEqual(reloaded.summary.today.downloadBytes, 0)
        XCTAssertEqual(reloaded.summary.today.uploadBytes, 0)
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

    func testInterfaceRateHasTrafficOnlyWhenCurrentSpeedIsNonZero() {
        XCTAssertFalse(
            interfaceRate(id: "en0", download: 0, upload: 0).hasTraffic
        )
        XCTAssertTrue(
            interfaceRate(id: "en0", download: 1, upload: 0).hasTraffic
        )
        XCTAssertTrue(
            interfaceRate(id: "en0", download: 0, upload: 1).hasTraffic
        )
    }

    func testPreferredPrimaryInterfaceUsesSystemPrimaryBeforeActiveFallback() {
        let active = interfaceRate(id: "en1", download: 100, upload: 0)
        let primary = InterfaceRate(
            id: "en0",
            name: "en0",
            displayName: "Wi-Fi / en0",
            downloadBytesPerSecond: 0,
            uploadBytesPerSecond: 0,
            totalReceivedBytes: 0,
            totalSentBytes: 0,
            receivedPackets: 0,
            sentPackets: 0,
            isPrimary: true
        )

        XCTAssertEqual(
            InterfacePresentation.preferredPrimaryInterface(in: [active, primary])?.id,
            "en0"
        )
    }

    func testPreferredPrimaryInterfaceFallsBackToActiveThenFirstKnownInterface() {
        let idle = interfaceRate(id: "en2", download: 0, upload: 0)
        let active = interfaceRate(id: "utun4", download: 25, upload: 0)

        XCTAssertEqual(
            InterfacePresentation.preferredPrimaryInterface(in: [idle, active])?.id,
            "utun4"
        )
        XCTAssertEqual(
            InterfacePresentation.preferredPrimaryInterface(in: [idle])?.id,
            "en2"
        )
        XCTAssertNil(InterfacePresentation.preferredPrimaryInterface(in: []))
    }

    func testOriginalColorBuiltInCharactersOptOutOfColorControls() {
        let unsupported = RunCatCharacter.allCharacters
            .filter { !$0.supportsColorControls }
            .map(\.id)

        XCTAssertEqual(
            unsupported,
            ["shiba_inu", "bunny", "penguin", "coffee_cup", "little_cloud", "tiny_plant", "sushi"]
        )
    }

    func testFullColorCharacterPickerPreviewsUseContrastShadow() {
        XCTAssertEqual(
            CharacterPickerPreviewIcon.contrastShadowOpacity(for: RunCatCharacter.byId("cat")),
            0
        )
        XCTAssertGreaterThan(
            CharacterPickerPreviewIcon.contrastShadowOpacity(for: RunCatCharacter.byId("chroma_slime")),
            0
        )
    }

    func testGoldenCatUsesSelectedSolidColorInsteadOfOriginalColor() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = "golden_cat"
        settings.catColorMode = CatColorMode.solid.rawValue
        settings.catColor = PersistedColor(red: 0.02, green: 0.18, blue: 1.0, alpha: 1)
        settings.showsBackground = true
        settings.backgroundOpacity = 1
        settings.backgroundColor = .olive
        settings.usesSystemTextColor = false
        settings.textColor = .black

        let image = StatusBarDisplayRenderer.image(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings,
            scale: 2,
            catFrameIndex: 0,
            renderTime: 19.25
        )

        XCTAssertGreaterThan(
            bluePixelCount(in: image, horizontalRegion: 0.0..<0.34),
            10,
            dominantColorSummary(in: image)
        )
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
            "prism_fox": (5, 40),
            "starlight_dragon": (5, 46),
            "chroma_slime": (6, 30),
            "sushi": (16, 58),
            "shiba_inu": (6, 28),
            "bunny": (6, 24),
            "penguin": (6, 26),
            "coffee_cup": (6, 24),
            "little_cloud": (6, 28),
            "tiny_plant": (6, 24)
        ]

        for (id, metadata) in expected {
            let character = RunCatCharacter.byId(id)
            XCTAssertEqual(character.frameCount, metadata.frameCount, id)
            XCTAssertEqual(character.frameWidth, metadata.frameWidth, id)
        }
    }

    func testCutePetAndSmallObjectCharactersAreAvailableInExpectedCategories() {
        XCTAssertEqual(RunCatCharacter.byId("shiba_inu").category, .animal)
        XCTAssertEqual(RunCatCharacter.byId("bunny").category, .animal)
        XCTAssertEqual(RunCatCharacter.byId("penguin").category, .animal)
        XCTAssertEqual(RunCatCharacter.byId("coffee_cup").category, .inanimate)
        XCTAssertEqual(RunCatCharacter.byId("little_cloud").category, .inanimate)
        XCTAssertEqual(RunCatCharacter.byId("tiny_plant").category, .inanimate)
        XCTAssertEqual(RunCatCharacter.byId("shiba_inu").displayName(language: .english), "Shiba Inu")
        XCTAssertEqual(RunCatCharacter.byId("little_cloud").displayName(language: .simplifiedChinese), "小云朵")
    }

    func testOfficialRunnerResourcesContainRoleDefiningAnimationFrames() throws {
        for character in RunCatCharacter.allCharacters {
            let urls = try runnerFrameURLs(for: character)
            XCTAssertEqual(urls.count, character.frameCount, character.id)

            let uniqueFrames = Set(try urls.map { try Data(contentsOf: $0) })
            XCTAssertGreaterThanOrEqual(uniqueFrames.count, min(character.frameCount, 5), character.id)

            let firstFrame = try Data(contentsOf: urls[0])
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: firstFrame), character.id)
            XCTAssertLessThanOrEqual(bitmap.pixelsWide, character.frameWidth * 2, character.id)
        }
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
        settings.catCharacter = "cat"
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

        // Scaling the cat up widens the status item.
        XCTAssertGreaterThan(enlargedWidth - defaultWidth, 5)
    }


    func testCharacterFacingControlsMirrorDirectionAndRenderSignature() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsCat = true
        settings.catCharacter = "cat"
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

    func testRunCatAnimationReportsCompletedPlaybackWhenLoopingToFirstFrame() {
        let character = CustomCharacter(
            id: "custom.loop",
            displayName: "Loop",
            sourceKind: .frameSequence,
            frameCount: 3,
            frameWidth: 18,
            frameHeight: 18,
            motionStyle: nil,
            pixelationScale: .off,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        var completedPlaybackCount = 0
        let animation = RunCatAnimation(
            character: CharacterAsset(custom: character),
            onFrameChange: { _ in }
        )
        animation.onPlaybackComplete = { characterID in
            XCTAssertEqual(characterID, "custom.loop")
            completedPlaybackCount += 1
        }

        animation.advanceFrameForTesting()
        animation.advanceFrameForTesting()
        XCTAssertEqual(completedPlaybackCount, 0)

        animation.advanceFrameForTesting()
        XCTAssertEqual(completedPlaybackCount, 1)
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
    }

    func testApplicationTrafficReaderUsesExternalInterfaceScope() {
        XCTAssertEqual(
            NettopLineParser.arguments,
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

    func testManifestReleaseCarriesSHA256ToAsset() async throws {
        let expectedSHA256 = String(repeating: "a", count: 64)
        let fetcher = UpdateReleaseFetcher(
            repository: "sunnyhot/NetBar",
            currentVersion: "0.37.1",
            loadData: { request in
                let json = """
                {
                    "version": "0.38.1",
                    "tag": "v0.38.1",
                    "asset": "NetBar.app.zip",
                    "asset_url": "https://github.com/sunnyhot/NetBar/releases/download/v0.38.1/NetBar.app.zip",
                    "sha256": "\(expectedSHA256)",
                    "notes": "Security hardening",
                    "html_url": "https://github.com/sunnyhot/NetBar/releases/tag/v0.38.1"
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (json, response)
            }
        )

        let release = try await fetcher.fetchLatestRelease()

        XCTAssertEqual(release.assets.first?.sha256, expectedSHA256)
    }

    func testUpdateArchiveIntegrityAcceptsMatchingSHA256AndRejectsMismatch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = directory.appendingPathComponent("NetBar.app.zip")
        try Data("netbar-update".utf8).write(to: archiveURL)

        try UpdateArchiveIntegrity.validate(
            fileURL: archiveURL,
            expectedSHA256: "5a870270648d26cf0ddb72ce56fbb6941ec0a3bf115814fd6027fd420ada9b28"
        )

        XCTAssertThrowsError(
            try UpdateArchiveIntegrity.validate(fileURL: archiveURL, expectedSHA256: String(repeating: "0", count: 64))
        ) { error in
            guard case UpdateError.checksumMismatch = error else {
                return XCTFail("Expected checksum mismatch, got \(error)")
            }
        }
    }

    func testUpdateReleaseFetcherFallsBackToGitHubAPIAfterManifestGatewayTimeout() async throws {
        let requestedURLs = LockedValue<[URL]>([])
        let fetcher = UpdateReleaseFetcher(
            repository: "sunnyhot/NetBar",
            currentVersion: "0.37.1",
            loadData: { request in
                let requestURL = try XCTUnwrap(request.url)
                requestedURLs.mutate { urls in
                    urls.append(requestURL)
                }
                if request.url?.host == "github.com" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 504,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (Data("Gateway Time-out".utf8), response)
                }

                let json = """
                {
                    "tag_name": "v0.38.1",
                    "name": "NetBar v0.38.1",
                    "body": "Retry update checks",
                    "html_url": "https://github.com/sunnyhot/NetBar/releases/tag/v0.38.1",
                    "assets": [
                        {
                            "name": "NetBar.app.zip",
                            "size": 3200000,
                            "browser_download_url": "https://github.com/sunnyhot/NetBar/releases/download/v0.38.1/NetBar.app.zip"
                        }
                    ]
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (json, response)
            }
        )

        let release = try await fetcher.fetchLatestRelease()

        XCTAssertEqual(release.tagName, "v0.38.1")
        XCTAssertEqual(release.assets.first?.name, "NetBar.app.zip")
        XCTAssertEqual(requestedURLs.withValue { $0.map(\.host) }, ["github.com", "api.github.com"])
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

        // "networkd" is hidden as a system process; the remaining "c" matches sort by
        // live activity (download+upload) descending: Xcode (7000) before Arc (6000).
        XCTAssertEqual(visible.map(\.displayName), ["Xcode", "Arc"])
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

    private func sourceFileContent(pathComponents: [String]) throws -> String {
        let sourceFile = URL(fileURLWithPath: #filePath)
        var url = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for pathComponent in pathComponents {
            url.appendPathComponent(pathComponent)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "NetBarTests.\(UUID().uuidString)"
        _ = isolatedDefaultSuiteNames.mutate { $0.insert(suiteName) }
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
            sampleCount: 1
        )
    }

    private func multiInterfaceSnapshot(timestamp: Date, interfaces: [InterfaceRate]) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            interfaces: interfaces,
            downloadBytesPerSecond: interfaces.reduce(0) { $0 + $1.downloadBytesPerSecond },
            uploadBytesPerSecond: interfaces.reduce(0) { $0 + $1.uploadBytesPerSecond },
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

    private func interfaceRate(id: String, download: Double, upload: Double) -> InterfaceRate {
        InterfaceRate(
            id: id,
            name: id,
            displayName: id,
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: 0,
            totalSentBytes: 0,
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
            totalSentBytes: sent
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
            totalSentBytes: total / 2
        )
    }

    /// Variant of `app()` with explicit traffic totals, for apps that may have
    /// no realtime activity in a given sample.
    private func appWithResources(
        _ displayName: String,
        processNames: [String],
        download: Double = 0,
        upload: Double = 0,
        totalReceived: UInt64 = 0,
        totalSent: UInt64 = 0
    ) -> ApplicationTrafficRate {
        ApplicationTrafficRate(
            id: displayName,
            displayName: displayName,
            processNames: processNames,
            pids: [123],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: totalReceived,
            totalSentBytes: totalSent
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

    private func bluePixelCount(in image: NSImage, horizontalRegion: Range<Double>) -> Int {
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
                    color.blueComponent > 0.72,
                    color.blueComponent > color.redComponent + 0.35,
                    color.blueComponent > color.greenComponent + 0.35
                else { continue }
                count += 1
            }
        }

        return count
    }

    private func darkPixelCount(in image: NSImage, horizontalRegion: Range<Double>) -> Int {
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
                    color.redComponent < 0.32,
                    color.greenComponent < 0.32,
                    color.blueComponent < 0.32
                else { continue }
                count += 1
            }
        }

        return count
    }

    private func saturatedPixelCount(in image: NSImage, horizontalRegion: Range<Double>) -> Int {
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
                    color.alphaComponent > 0.5
                else { continue }

                var hue = CGFloat.zero
                var saturation = CGFloat.zero
                var brightness = CGFloat.zero
                var alpha = CGFloat.zero
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                guard saturation > 0.45, brightness > 0.45 else { continue }
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

private final class SequenceNetworkStatsReader: NetworkStatsReading, @unchecked Sendable {
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
        let animation = RunCatAnimation(character: asset, speedMultiplier: 1.0) { _ in
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

// MARK: - Application Traffic Presentation Tests

extension PreferencesAndPresentationTests {

    func testApplicationRowMetricsShowRealtimeTraffic() {
        let application = appWithResources(
            "Safari",
            processNames: ["Safari"],
            download: 1_500,
            upload: 500
        )

        XCTAssertEqual(
            ApplicationTrafficPresentation.rowMetrics(for: application),
            [
                ApplicationTrafficMetric(kind: .download, value: "1.46 KB/s"),
                ApplicationTrafficMetric(kind: .upload, value: "500 B/s")
            ]
        )
    }

    func testApplicationSummaryMetricsShowRealtimeTraffic() {
        let applications = [
            appWithResources(
                "Safari",
                processNames: ["Safari"],
                download: 1_500,
                upload: 500
            ),
            appWithResources(
                "Xcode",
                processNames: ["Xcode"],
                download: 500,
                upload: 250
            )
        ]

        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(for: applications),
            [
                ApplicationTrafficMetric(kind: .download, value: "1.95 KB/s"),
                ApplicationTrafficMetric(kind: .upload, value: "750 B/s")
            ]
        )
    }

    func testApplicationTrafficPresentationModelBuildsVisibleAppsAndSummary() {
        let snapshot = sampleSnapshot(download: 4_000, upload: 2_000)
        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appRate("Safari", download: 1_500, upload: 500, received: 10_000, sent: 2_000),
                appRate("Helper", download: 0, upload: 0, received: 0, sent: 0)
            ],
            sampleCount: 2,
            isRefreshing: false,
            errorMessage: nil,
            systemResources: .empty
        )

        let model = ApplicationTrafficPresentation.makeModel(
            snapshot: snapshot,
            state: state,
            hidesSystemProcesses: false,
            searchText: "",
            limit: 18
        )

        XCTAssertEqual(model.visibleApplications.map(\.displayName), ["Safari"])
        XCTAssertEqual(model.summaryMetrics, [
            ApplicationTrafficMetric(kind: .download, value: "1.46 KB/s"),
            ApplicationTrafficMetric(kind: .upload, value: "500 B/s")
        ])
        XCTAssertEqual(model.attributionSummary.applicationBytesPerSecond, 2_000)
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

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                appWithResources("Idle App", processNames: ["Idle App"]),
                appWithResources("Browser", processNames: ["Browser"], download: 2_000, upload: 800),
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

    func testApplicationSummaryUsesVisibleApplications() {
        let applications = [
            appWithResources("Idle App", processNames: ["Idle App"]),
            appWithResources("Browser", processNames: ["Browser"], download: 2_000, upload: 800),
            appWithResources("Uploader", processNames: ["Uploader"], download: 0, upload: 1_500)
        ]

        XCTAssertEqual(
            ApplicationTrafficPresentation.summaryMetrics(
                for: ApplicationTrafficPresentation.displayApplications(applications)
            ),
            [
                ApplicationTrafficMetric(kind: .download, value: "1.95 KB/s"),
                ApplicationTrafficMetric(kind: .upload, value: "2.25 KB/s")
            ]
        )
    }
}

// MARK: - Living Signal Design System Tests

extension PreferencesAndPresentationTests {
    func testLivingSignalLayoutUsesApprovedPopoverWidth() {
        XCTAssertEqual(LivingSignalLayout.minimumPopoverWidth, 480)
        XCTAssertEqual(LivingSignalLayout.preferredPopoverWidth, 500)
        XCTAssertEqual(LivingSignalLayout.maximumPopoverWidth, 520)
        XCTAssertGreaterThan(LivingSignalLayout.chartHeight, 132)
    }

    func testLivingSignalPaletteUsesRestrainedNativeInstrumentRoles() {
        XCTAssertEqual(LivingSignalPalette.signal.red, 0.12, accuracy: 0.001)
        XCTAssertEqual(LivingSignalPalette.signal.green, 0.62, accuracy: 0.001)
        XCTAssertEqual(LivingSignalPalette.signal.blue, 0.57, accuracy: 0.001)

        XCTAssertEqual(LivingSignalPalette.upload.red, 0.88, accuracy: 0.001)
        XCTAssertEqual(LivingSignalPalette.upload.green, 0.41, accuracy: 0.001)
        XCTAssertEqual(LivingSignalPalette.upload.blue, 0.34, accuracy: 0.001)

        XCTAssertEqual(LivingSignalTone.active.role, .signal)
        XCTAssertEqual(LivingSignalTone.normal.role, .signal)
        XCTAssertEqual(LivingSignalTone.uploadHeavy.role, .upload)
        XCTAssertEqual(LivingSignalTone.attention.role, .attention)
        XCTAssertEqual(LivingSignalTone.critical.role, .critical)
        XCTAssertEqual(LivingSignalTone.idle.role, .neutral)
        XCTAssertEqual(LivingSignalTone.neutral.role, .neutral)

        XCTAssertLessThanOrEqual(LivingSignalSurface.windowSignalTintOpacity, 0.025)
        XCTAssertLessThanOrEqual(LivingSignalSurface.windowUploadTintOpacity, 0.018)
        XCTAssertLessThanOrEqual(LivingSignalSurface.selectedFillOpacity, 0.12)
    }

    func testLivingSignalMotionPolicyDisablesLoopingEffectsWhenReduceMotionIsOn() {
        let reduced = LivingSignalMotionPolicy.make(
            reduceMotion: true,
            windowVisible: true,
            isActive: true
        )

        XCTAssertFalse(reduced.allowsLoopingEffects)
        XCTAssertFalse(reduced.allowsScan)
        XCTAssertEqual(reduced.pulseScale, 1)

        let active = LivingSignalMotionPolicy.make(
            reduceMotion: false,
            windowVisible: true,
            isActive: true
        )

        XCTAssertTrue(active.allowsLoopingEffects)
        XCTAssertTrue(active.allowsScan)
        XCTAssertGreaterThan(active.pulseScale, 1)
    }

    func testLivingSignalStatusPresentationClassifiesIdleActiveUploadAndAnomaly() {
        let idle = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 0, upload: 0),
            latestEvent: nil,
            language: .english
        )
        XCTAssertEqual(idle.tone, .idle)
        XCTAssertEqual(idle.title, "Idle")

        let active = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 420_000, upload: 60_000),
            latestEvent: nil,
            language: .english
        )
        XCTAssertEqual(active.tone, .active)
        XCTAssertEqual(active.title, "Active")

        let uploadHeavy = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 80_000, upload: 900_000),
            latestEvent: nil,
            language: .english
        )
        XCTAssertEqual(uploadHeavy.tone, .uploadHeavy)
        XCTAssertEqual(uploadHeavy.title, "Upload Heavy")

        let event = NetworkAnomalyEvent(
            title: "Traffic surge",
            message: "Traffic stayed high.",
            timestamp: Date(timeIntervalSince1970: 20)
        )
        let anomaly = LivingSignalStatusPresentation.make(
            snapshot: sampleSnapshot(download: 0, upload: 0),
            latestEvent: event,
            language: .english
        )
        XCTAssertEqual(anomaly.tone, .attention)
        XCTAssertEqual(anomaly.title, "Traffic surge")
    }
}

// MARK: - Traffic Pulse Chart Tests

extension PreferencesAndPresentationTests {
    func testTrafficPulseChartScaleNormalizesValuesAgainstLargestPoint() {
        XCTAssertEqual(
            TrafficPulseChartScale.normalizedValues([0, 50, 100]),
            [0, 0.5, 1.0]
        )
    }

    func testTrafficPulseChartScaleHandlesEmptyAndAllZeroValues() {
        XCTAssertEqual(TrafficPulseChartScale.normalizedValues([]), [])
        XCTAssertEqual(TrafficPulseChartScale.normalizedValues([0, 0]), [0, 0])
    }
}

// MARK: - Popover Decomposition Tests

extension PreferencesAndPresentationTests {
    func testLivingSignalPopoverOwnsSummaryFiles() throws {
        let summarySource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkSummaryPanel.swift"]
        )
        let rootSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkPopoverView.swift"]
        )

        XCTAssertTrue(summarySource.contains("struct TodayNetworkSummaryPanel"))
        XCTAssertFalse(summarySource.contains("struct HistoryLedgerPanel"))
        XCTAssertFalse(summarySource.contains("struct ApplicationTopPanel"))
        XCTAssertFalse(summarySource.contains("struct SummaryGrid"))
        XCTAssertFalse(rootSource.contains("struct TodayNetworkSummary: View"))
        XCTAssertFalse(rootSource.contains("private var insightStreamSection"))
    }

    func testLivingSignalPopoverOwnsApplicationInterfaceAndFooterFiles() throws {
        let appSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "ApplicationTrafficPanel.swift"]
        )
        let interfaceSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "InterfaceAndSystemPanel.swift"]
        )
        let footerSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "PopoverFooterView.swift"]
        )
        let rootSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkPopoverView.swift"]
        )

        XCTAssertTrue(appSource.contains("struct ApplicationTrafficPanel"))
        XCTAssertTrue(appSource.contains("struct ApplicationTrafficRow"))
        XCTAssertTrue(interfaceSource.contains("struct InterfaceAndSystemPanel"))
        XCTAssertTrue(interfaceSource.contains("struct InterfaceRow"))
        XCTAssertTrue(footerSource.contains("struct PopoverFooterView"))
        XCTAssertFalse(rootSource.contains("struct ApplicationTrafficList"))
        XCTAssertFalse(rootSource.contains("struct InterfaceList"))
        XCTAssertFalse(rootSource.contains("struct FooterView"))
    }

    func testPopoverHeaderChartAndFooterUseNativeInstrumentPrimitives() throws {
        let headerSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "PopoverHeaderView.swift"]
        )
        let chartSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "TrafficPulseChartView.swift"]
        )
        let footerSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "PopoverFooterView.swift"]
        )

        XCTAssertTrue(headerSource.contains("struct LivingSignalStatusDot"))
        XCTAssertTrue(headerSource.contains("livingSignalRow"))
        XCTAssertFalse(headerSource.contains("presentation.tone.gradient"))

        XCTAssertTrue(chartSource.contains("chartWellBackground"))
        XCTAssertTrue(chartSource.contains("LivingSignalTone.active.color"))
        XCTAssertTrue(chartSource.contains("LivingSignalTone.uploadHeavy.color"))

        XCTAssertTrue(footerSource.contains("livingSignalToolbarSurface"))
        XCTAssertFalse(footerSource.contains(".livingSignalPanel(tone: monitor.isRunning ? .normal : .attention"))
    }

    func testPopoverPanelsAvoidBroadSystemTrafficColorLiterals() throws {
        let panelFiles = [
            ["Sources", "NetBar", "Popover", "NetworkSummaryPanel.swift"],
            ["Sources", "NetBar", "Popover", "ApplicationTrafficPanel.swift"],
            ["Sources", "NetBar", "Popover", "InterfaceAndSystemPanel.swift"]
        ]

        for pathComponents in panelFiles {
            let source = try sourceFileContent(pathComponents: pathComponents)
            XCTAssertFalse(source.contains("return .blue"), pathComponents.joined(separator: "/"))
            XCTAssertFalse(source.contains("return .orange"), pathComponents.joined(separator: "/"))
            XCTAssertFalse(source.contains("return .green"), pathComponents.joined(separator: "/"))
            XCTAssertFalse(source.contains("Color.blue"), pathComponents.joined(separator: "/"))
            XCTAssertFalse(source.contains("Color.orange"), pathComponents.joined(separator: "/"))
            XCTAssertFalse(source.contains("Color.mint"), pathComponents.joined(separator: "/"))
        }
    }

    func testPreferencesComponentsUseNativeInstrumentHeaderAndSections() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesComponents.swift"]
        )

        XCTAssertTrue(source.contains("struct PreferencesHeader"))
        XCTAssertTrue(source.contains("livingSignalRow"))
        XCTAssertTrue(source.contains("NetBar 偏好设置"))
        XCTAssertFalse(source.contains("struct PreferencesHeroHeader"))
        XCTAssertFalse(source.contains("NetBar 信号控制台"))
        XCTAssertFalse(source.contains("LivingSignalTone.active.gradient"))
    }

    func testPreferencesWindowUsesNativeInstrumentBackgroundAndTabs() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesWindowController.swift"]
        )

        XCTAssertTrue(source.contains("PreferencesHeader(appPreferences: appPreferences, updater: updater)"))
        XCTAssertTrue(source.contains("livingSignalPanelBackground()"))
        XCTAssertTrue(source.contains("livingSignalSelectedSurface"))
        XCTAssertFalse(source.contains("PreferencesHeroHeader"))
    }

    func testPreferencesWindowUsesLightweightManualTabs() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesWindowController.swift"]
        )

        XCTAssertTrue(source.contains("enum PreferencesTab"))
        XCTAssertTrue(source.contains("struct PreferencesTabBar"))
        XCTAssertFalse(source.contains("TabView(selection:"))
        XCTAssertFalse(source.contains(".animation(.easeInOut(duration: 0.2), value: selectedTab)"))
    }

    func testPreferencesUsesAccurateAlertsAndHistoryNaming() throws {
        let windowSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesWindowController.swift"]
        )
        let alertsSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "AlertsAndHistoryPreferencesView.swift"]
        )

        XCTAssertTrue(windowSource.contains("提醒与历史"))
        XCTAssertTrue(windowSource.contains("Alerts & History"))
        XCTAssertTrue(alertsSource.contains("struct AlertsAndHistoryPreferencesView"))
        XCTAssertTrue(alertsSource.contains("高流量提醒"))
        XCTAssertFalse(windowSource.contains("appPreferences.text(\"智能\", \"Intelligence\")"))
        XCTAssertFalse(alertsSource.contains("appPreferences.text(\"智能检测\", \"Intelligence\")"))
    }

    func testInterfacePanelDefaultsToPrimaryAndDisclosesAdvancedDiagnostics() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "InterfaceAndSystemPanel.swift"]
        )

        XCTAssertTrue(source.contains("@State private var showsAdvancedDiagnostics = false"))
        XCTAssertTrue(source.contains("struct PrimaryInterfaceSection"))
        XCTAssertTrue(source.contains("DisclosureGroup(isExpanded: $isExpanded)"))
        XCTAssertTrue(source.contains("高级接口诊断"))
        XCTAssertTrue(source.contains("showsPacketCounts: false"))
        XCTAssertTrue(source.contains("showsPacketCounts: true"))
    }

    func testMainMenuIncludesStandardUtilityMenusAndServices() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "AppDelegate.swift"]
        )

        XCTAssertTrue(source.contains("NSApplication.shared.servicesMenu"))
        XCTAssertTrue(source.contains("text(\"编辑\", \"Edit\")"))
        XCTAssertTrue(source.contains("text(\"显示\", \"View\")"))
        XCTAssertTrue(source.contains("text(\"窗口\", \"Window\")"))
        XCTAssertTrue(source.contains("text(\"帮助\", \"Help\")"))
        XCTAssertTrue(source.contains("NSApplication.shared.helpMenu"))
    }

    func testPreferencesWindowRestoresAndAutosavesItsFrame() throws {
        let source = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Preferences", "PreferencesWindowController.swift"]
        )

        XCTAssertTrue(source.contains("setFrameUsingName(autosaveName)"))
        XCTAssertTrue(source.contains("setFrameAutosaveName(autosaveName)"))
    }

    func testIconOnlyTrafficControlsProvideVoiceOverLabels() throws {
        let statusSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "StatusBarController.swift"]
        )
        let footerSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "PopoverFooterView.swift"]
        )

        XCTAssertTrue(statusSource.contains("button.setAccessibilityLabel"))
        XCTAssertTrue(statusSource.contains("button.setAccessibilityHelp"))
        XCTAssertEqual(footerSource.components(separatedBy: ".accessibilityLabel(").count - 1, 3)
    }

    func testLivingSignalScrollingPanelsAvoidExpensivePerRowEffects() throws {
        let designSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "LivingSignalDesignSystem.swift"]
        )
        let appSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "ApplicationTrafficPanel.swift"]
        )
        let interfaceSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "InterfaceAndSystemPanel.swift"]
        )
        let summarySource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "NetworkSummaryPanel.swift"]
        )

        XCTAssertFalse(designSource.contains(".fill(.regularMaterial)"))
        XCTAssertFalse(interfaceSource.contains(".fill(.ultraThinMaterial)"))
        XCTAssertFalse(appSource.contains(".animation(NetBarMotion.quick, value: isHovering)"))
        XCTAssertFalse(interfaceSource.contains(".animation(NetBarMotion.quick, value: isHovering)"))
        XCTAssertFalse(summarySource.contains("repeatForever"))
    }

    func testMenuPopoverDisablesContinuousScrollBlockingAnimations() throws {
        let headerSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "PopoverHeaderView.swift"]
        )
        let chartSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "TrafficPulseChartView.swift"]
        )

        XCTAssertFalse(headerSource.contains("repeatForever"))
        XCTAssertFalse(headerSource.contains("withAnimation"))
        XCTAssertFalse(headerSource.contains("isPulsing"))
        XCTAssertFalse(chartSource.contains("repeatForever"))
        XCTAssertFalse(chartSource.contains("withAnimation"))
        XCTAssertFalse(chartSource.contains("scanOffset"))
        XCTAssertFalse(chartSource.contains("allowsScan"))
    }

    func testApplicationTrafficRowsUseStaticBadgesWhileScrolling() throws {
        let appSource = try sourceFileContent(
            pathComponents: ["Sources", "NetBar", "Popover", "ApplicationTrafficPanel.swift"]
        )

        XCTAssertTrue(appSource.contains("AppBadge(title: application.displayName)"))
        XCTAssertFalse(appSource.contains("pids: application.pids"))
        XCTAssertFalse(appSource.contains("iconLoadTask"))
        XCTAssertFalse(appSource.contains("scheduleIconLoad"))
        XCTAssertFalse(appSource.contains("resolveIconAsync"))
        XCTAssertFalse(appSource.contains(".onAppear(perform:"))
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
