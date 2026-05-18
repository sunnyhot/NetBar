import AppKit
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
        XCTAssertEqual(DetailsWindowDismissalPolicy.autoDismissInterval, 10)
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
        var globalClick: (() -> Void)?
        var localClick: (() -> Void)?
        let monitor = GooglyEyesClickMonitor(
            addGlobalMonitor: { handler in
                globalClick = handler
                return MonitorToken(name: "global")
            },
            addLocalMonitor: { handler in
                localClick = handler
                return MonitorToken(name: "local")
            },
            removeMonitor: { _ in }
        )

        var blinkCount = 0
        monitor.setActive(true) {
            blinkCount += 1
        }

        globalClick?()
        localClick?()

        XCTAssertEqual(blinkCount, 2)
    }

    func testGooglyEyesClickMonitorDoesNotDuplicateMonitorsAndRemovesThemWhenInactive() {
        var installCount = 0
        var removedTokens: [String] = []
        let monitor = GooglyEyesClickMonitor(
            addGlobalMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "global")
            },
            addLocalMonitor: { _ in
                installCount += 1
                return MonitorToken(name: "local")
            },
            removeMonitor: { token in
                removedTokens.append((token as? MonitorToken)?.name ?? "unknown")
            }
        )

        monitor.setActive(true) {}
        monitor.setActive(true) {}
        monitor.setActive(false) {}
        monitor.setActive(false) {}

        XCTAssertEqual(installCount, 2)
        XCTAssertEqual(removedTokens.sorted(), ["global", "local"])
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

    func testNetworkTotalsExcludeVirtualProxyInterfaces() {
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
        sampleDate = sampleDate.addingTimeInterval(1)
        monitor.refresh()

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

    func testUpdateLookupUsesGitHubReleaseRedirectInsteadOfRateLimitedAPI() throws {
        let request = try GitHubLatestReleaseLookup.request(
            repository: "sunnyhot/NetBar",
            currentVersion: "0.27.0"
        )

        XCTAssertEqual(request.url?.absoluteString, "https://github.com/sunnyhot/NetBar/releases/latest")
        XCTAssertEqual(request.httpMethod, "HEAD")
        XCTAssertNotEqual(request.url?.host, "api.github.com")
    }

    func testUpdateLookupBuildsReleaseFromLatestRedirectURL() throws {
        let release = try GitHubLatestReleaseLookup.release(
            from: URL(string: "https://github.com/sunnyhot/NetBar/releases/tag/v0.21.0")!,
            repository: "sunnyhot/NetBar",
            assetName: "NetBar.app.zip"
        )

        XCTAssertEqual(release.tagName, "v0.21.0")
        XCTAssertEqual(release.htmlURL.absoluteString, "https://github.com/sunnyhot/NetBar/releases/tag/v0.21.0")
        XCTAssertEqual(release.assets.first?.name, "NetBar.app.zip")
        XCTAssertEqual(
            release.assets.first?.browserDownloadURL.absoluteString,
            "https://github.com/sunnyhot/NetBar/releases/download/v0.21.0/NetBar.app.zip"
        )
    }

    func testAutomaticUpdatePromptUsesActionableButtonsInsteadOfAcknowledgementOnly() {
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

        let prompt = UpdatePromptContent.make(
            for: update,
            currentVersion: "0.21.0",
            automaticCheck: true
        )

        XCTAssertEqual(prompt.messageText, "发现新版本 0.22.0")
        XCTAssertTrue(prompt.informativeText.contains("当前版本：0.21.0"))
        XCTAssertTrue(prompt.informativeText.contains("最新版本：0.22.0"))
        XCTAssertTrue(prompt.informativeText.contains("NetBar 0.22.0"))
        XCTAssertEqual(prompt.buttonTitles, ["下载并安装", "查看 Release 页面", "稍后提醒"])
        XCTAssertFalse(prompt.buttonTitles.contains("知道了"))
        XCTAssertEqual(prompt.releaseNotesText, "- 新增自动检测更新\n- 优化菜单栏交互")
    }

    func testUpdatePromptMapsAlertResponsesToActions() {
        XCTAssertEqual(UpdatePromptAction.response(forButtonIndex: 0), .downloadAndInstall)
        XCTAssertEqual(UpdatePromptAction.response(forButtonIndex: 1), .openReleasePage)
        XCTAssertEqual(UpdatePromptAction.response(forButtonIndex: 2), .remindLater)
        XCTAssertNil(UpdatePromptAction.response(forButtonIndex: 3))
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
            errorMessage: nil
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
            errorMessage: nil
        )

        controller.observe(snapshot: sampleSnapshot(download: 2_000, upload: 500), appTraffic: appTraffic)

        XCTAssertEqual(controller.latestCue?.kind, .reminder)
        XCTAssertTrue(controller.latestCue?.message.contains("Arc") == true)
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
            errorMessage: nil
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
