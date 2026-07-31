import AppKit

@MainActor
enum StatusBarPresentationKind: Equatable {
    case nativeTitle
    case retinaImage
}

struct StatusBarPresentation: Equatable {
    let kind: StatusBarPresentationKind
    let width: CGFloat
    let lines: [String]
}

struct StatusBarRenderSignature: Equatable {
    let presentation: StatusBarPresentation
    let fontSize: Double
    let itemWidth: Double
    let usesAutomaticWidth: Bool
    let lineSpacing: Double
    let trafficDisplayMode: StatusBarTrafficDisplayMode
    let order: StatusBarOrder
    let alignment: StatusBarAlignment
    let showsArrows: Bool
    let isBold: Bool
    let showsBackground: Bool
    let backgroundOpacity: Double
    let usesSystemTextColor: Bool
    let textColor: PersistedColor
    let backgroundColor: PersistedColor
    let statusPulseTimeBucket: Int
    let appearanceName: String
    let catFrameIndex: Int?
    let catCharacter: String
    let catScale: Double
    let catPosition: StatusBarCharacterPosition
    let catFacing: StatusBarCharacterFacing
    let catColor: PersistedColor
    let catColorMode: String
    let catColorTimeBucket: Int  // For dynamic modes: time quantized to ~250ms buckets
    let catHeadSwing: Bool
    let customCharacterRevision: Int
}

enum StatusBarPulseRenderPolicy {
    static let activeTrafficThresholdBytesPerSecond: Double = 100_000

    static func isActive(snapshot: NetworkSnapshot) -> Bool {
        snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond >= activeTrafficThresholdBytesPerSecond
    }

    static func timeBucket(
        snapshot: NetworkSnapshot,
        reduceMotion: Bool,
        renderTime: TimeInterval
    ) -> Int {
        guard !reduceMotion, isActive(snapshot: snapshot) else { return 0 }
        return Int(renderTime * 2)
    }

    static func pulseAlpha(
        snapshot: NetworkSnapshot,
        reduceMotion: Bool,
        renderTime: TimeInterval
    ) -> CGFloat {
        guard timeBucket(snapshot: snapshot, reduceMotion: reduceMotion, renderTime: renderTime) > 0 else {
            return 0
        }
        let wave = 0.5 + 0.5 * sin(renderTime * .pi * 2)
        return CGFloat(0.08 + wave * 0.1)
    }
}

@MainActor
enum StatusBarDisplayRenderer {

    // MARK: - Image Caches

    private static let characterImageCache = NSCache<CharacterImageCacheKey, NSImage>()

    private static let tintImageCache = NSCache<TintImageCacheKey, NSImage>()

    private static let textLayoutCache = StatusBarTextLayoutCache(limit: 24)

    private static let gradientTintImageCache: NSCache<GradientTintImageCacheKey, NSImage> = {
        let cache = NSCache<GradientTintImageCacheKey, NSImage>()
        cache.countLimit = 30
        return cache
    }()

    private static let gradientDetailPreservingImageCache: NSCache<GradientTintImageCacheKey, NSImage> = {
        let cache = NSCache<GradientTintImageCacheKey, NSImage>()
        cache.countLimit = 30
        return cache
    }()

    private final class CharacterImageCacheKey: NSObject {
        let characterID: String
        let frameIndex: Int
        init(characterID: String, frameIndex: Int) {
            self.characterID = characterID
            self.frameIndex = frameIndex
        }
        override var hash: Int { characterID.hashValue ^ frameIndex.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? CharacterImageCacheKey else { return false }
            return characterID == other.characterID && frameIndex == other.frameIndex
        }
    }

    private final class TintImageCacheKey: NSObject {
        let imagePointer: Int
        let colorRGBA: (CGFloat, CGFloat, CGFloat, CGFloat)
        init(image: NSImage, color: NSColor) {
            self.imagePointer = Int(bitPattern: Unmanaged.passUnretained(image).toOpaque())
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.colorRGBA = (r, g, b, a)
        }
        override var hash: Int {
            imagePointer.hashValue ^ colorRGBA.0.hashValue ^ colorRGBA.1.hashValue ^ colorRGBA.2.hashValue
        }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? TintImageCacheKey else { return false }
            return imagePointer == other.imagePointer
                && colorRGBA.0 == other.colorRGBA.0
                && colorRGBA.1 == other.colorRGBA.1
                && colorRGBA.2 == other.colorRGBA.2
                && colorRGBA.3 == other.colorRGBA.3
        }
    }

    private final class GradientTintImageCacheKey: NSObject {
        let imagePointer: Int
        let quantizedStops: [(r: Int, g: Int, b: Int, a: Int, pos: Int)]

        init(image: NSImage, colors: [(color: NSColor, position: CGFloat)]) {
            self.imagePointer = Int(bitPattern: Unmanaged.passUnretained(image).toOpaque())
            self.quantizedStops = colors.map { stop in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                stop.color.getRed(&r, green: &g, blue: &b, alpha: &a)
                return (Int(r * 100), Int(g * 100), Int(b * 100), Int(a * 100), Int(stop.position * 100))
            }
        }

        override var hash: Int {
            var h = imagePointer.hashValue
            for stop in quantizedStops {
                h = h ^ stop.r.hashValue ^ stop.g.hashValue ^ stop.b.hashValue ^ stop.a.hashValue ^ stop.pos.hashValue
            }
            return h
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? GradientTintImageCacheKey else { return false }
            guard imagePointer == other.imagePointer else { return false }
            guard quantizedStops.count == other.quantizedStops.count else { return false }
            for (a, b) in zip(quantizedStops, other.quantizedStops) {
                guard a.r == b.r, a.g == b.g, a.b == b.b, a.a == b.a, a.pos == b.pos else { return false }
            }
            return true
        }
    }

    // MARK: - Color Pipeline

    /// Quantized time bucket for dynamic color modes. Updates at 4 Hz (250ms intervals)
    /// instead of being coupled to the position/animation frame rate.
    static func colorTimeBucket(forMode mode: String) -> Int {
        let colorMode = CatColorMode(rawValue: mode) ?? .solid
        return colorMode.isDynamic ? Int(Date().timeIntervalSince1970 * 4) : 0
    }

    // MARK: - Presentation

    static func presentation(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore? = nil,
        catFrameIndex: Int? = nil
    ) -> StatusBarPresentation {
        let layout = layout(
            snapshot: snapshot,
            settings: settings,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex
        )
        return StatusBarPresentation(
            kind: .retinaImage,
            width: layout.width,
            lines: layout.lines
        )
    }

    static func signature(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        appearanceName: String,
        customCharacterStore: CustomCharacterStore? = nil,
        catFrameIndex: Int? = nil,
        renderTime: TimeInterval = Date().timeIntervalSince1970,
        reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    ) -> StatusBarRenderSignature {
        let effectiveCharacter = characterAsset(
            settings: settings,
            customCharacterStore: customCharacterStore
        )
        return StatusBarRenderSignature(
            presentation: presentation(
                snapshot: snapshot,
                settings: settings,
                customCharacterStore: customCharacterStore,
                catFrameIndex: catFrameIndex
            ),
            fontSize: settings.fontSize,
            itemWidth: settings.itemWidth,
            usesAutomaticWidth: settings.usesAutomaticWidth,
            lineSpacing: settings.lineSpacing,
            trafficDisplayMode: settings.trafficDisplayMode,
            order: settings.order,
            alignment: settings.alignment,
            showsArrows: settings.showsArrows,
            isBold: settings.isBold,
            showsBackground: settings.showsBackground,
            backgroundOpacity: settings.backgroundOpacity,
            usesSystemTextColor: settings.usesSystemTextColor,
            textColor: settings.textColor,
            backgroundColor: settings.backgroundColor,
            statusPulseTimeBucket: StatusBarPulseRenderPolicy.timeBucket(
                snapshot: snapshot,
                reduceMotion: reduceMotion,
                renderTime: renderTime
            ),
            appearanceName: appearanceName,
            catFrameIndex: catFrameIndex,
            catCharacter: effectiveCharacter.id,
            catScale: settings.catScale,
            catPosition: settings.catPosition,
            catFacing: settings.catFacing,
            catColor: settings.catColor,
            catColorMode: settings.catColorMode,
            catColorTimeBucket: Self.colorTimeBucket(forMode: settings.catColorMode),
            catHeadSwing: settings.catHeadSwing,
            customCharacterRevision: customCharacterStore?.revision ?? 0
        )
    }

    static func attributedTitle(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> NSAttributedString {
        let layout = layout(snapshot: snapshot, settings: settings, customCharacterStore: nil)
        return attributedText(layout.lines.joined(separator: "\n"), layout: layout, settings: settings)
    }

    static func image(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> NSImage {
        image(snapshot: snapshot, settings: settings, scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    static func image(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore? = nil,
        catFrameIndex: Int? = nil,
        renderTime: TimeInterval = Date().timeIntervalSince1970
    ) -> NSImage {
        image(
            snapshot: snapshot,
            settings: settings,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex,
            renderTime: renderTime
        )
    }

    static func image(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        scale: CGFloat,
        customCharacterStore: CustomCharacterStore? = nil,
        catFrameIndex: Int? = nil,
        renderTime: TimeInterval = Date().timeIntervalSince1970
    ) -> NSImage {
        let layout = layout(
            snapshot: snapshot,
            settings: settings,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex
        )
        let width = layout.width
        let height = max(NSStatusBar.system.thickness, 24)
        let size = NSSize(width: width, height: height)
        let safeScale = max(scale, 1)
        let pixelsWide = max(Int(ceil(width * safeScale)), 1)
        let pixelsHigh = max(Int(ceil(height * safeScale)), 1)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }

        representation.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if settings.showsBackground {
            settings.backgroundColor.nsColor
                .withAlphaComponent(CGFloat(settings.backgroundOpacity.clamped(to: 0...1)))
                .setFill()
            NSRect(origin: .zero, size: size).fill()
            let pulseAlpha = StatusBarPulseRenderPolicy.pulseAlpha(
                snapshot: snapshot,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                renderTime: renderTime
            )
            if pulseAlpha > 0 {
                let pulseColor = snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond
                    ? NSColor.systemOrange
                    : NSColor.systemTeal
                pulseColor.withAlphaComponent(pulseAlpha).setFill()
                NSRect(origin: .zero, size: size).fill()
            }
        }

        // Determine if cat has custom coloring (non-default-white solid or fancy mode)
        let colorMode = CatColorMode(rawValue: settings.catColorMode) ?? .solid
        let catHasCustomColor: Bool
        if settings.showsCat, catFrameIndex != nil {
            let character = characterAsset(
                settings: settings,
                customCharacterStore: customCharacterStore
            )
            if character.isCustom {
                catHasCustomColor = true
            } else if character.isTemplate {
                // Template character with non-solid mode, or solid mode with non-white color
                catHasCustomColor = colorMode != .solid || settings.catColor != PersistedColor.white
            } else {
                // Color characters (gaming-cat, party-parrot, etc.) always have custom colors
                catHasCustomColor = true
            }
        } else {
            catHasCustomColor = false
        }

        // When cat has custom colors, we cannot use template image mode
        // because macOS would re-tint the entire image, inverting custom colors.
        // Instead, render with explicit colors for both cat and text.
        let useTemplate = settings.usesSystemTextColor && !settings.showsBackground && !catHasCustomColor
        let textColor = useTemplate ? NSColor.black : settings.effectiveTextColor

        var textRect = NSRect(
            x: layout.horizontalPadding,
            y: 0,
            width: max(width - layout.horizontalPadding * 2, 1),
            height: height
        )
        if let catIndex = catFrameIndex, settings.showsCat {
            // Load the cat character image from the pre-cached animation frames
            let character = characterAsset(
                settings: settings,
                customCharacterStore: customCharacterStore
            )
            let frameIdx = catIndex % character.frameCount

            // Scale: sprite is at 1x (e.g. 28x36). Draw at 1x logical size.
            // Frame width varies by character, use character.frameWidth
            let catSize = characterSize(for: character, settings: settings)
            let catPadding = characterSpacing(settings: settings)
            let catY = (height - catSize.height) / 2
            let catX: CGFloat
            switch settings.catPosition {
            case .left:
                catX = layout.horizontalPadding
                textRect.origin.x = layout.horizontalPadding + catSize.width + catPadding
                textRect.size.width = max(width - textRect.origin.x - layout.horizontalPadding, 1)
            case .right:
                catX = width - layout.horizontalPadding - catSize.width
                textRect.origin.x = layout.horizontalPadding
                textRect.size.width = max(catX - catPadding - layout.horizontalPadding, 1)
            }
            let drawRect = NSRect(x: catX, y: catY, width: catSize.width, height: catSize.height)

            let catImage = characterImage(
                for: character,
                frameIndex: frameIdx,
                customCharacterStore: customCharacterStore
            )

            if let catImg = catImage {
                let now = renderTime

                let shouldFlip = shouldMirrorCharacter(settings: settings, frameIndex: frameIdx)

                if shouldFlip {
                    // Mirror the drawing context for character facing and optional head swing.
                    if let currentContext = NSGraphicsContext.current {
                        let transform = currentContext.cgContext
                        transform.saveGState()
                        transform.translateBy(x: drawRect.midX * 2, y: 0)
                        transform.scaleBy(x: -1, y: 1)
                    }
                }

                if character.supportsColorControls {
                    // Color-capable characters use the same tint pipeline, whether their
                    // source frames are template silhouettes or full-color sprites.
                    if colorMode == .solid {
                        // Solid color: use single-color tint
                        let tintColor = colorMode.color(at: now, frameIndex: frameIdx, baseColor: settings.catColor)
                        if let tinted = tintImage(catImg, color: tintColor) {
                            tinted.draw(in: drawRect, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1.0)
                        } else {
                            catImg.isTemplate = true
                            catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                        }
                    } else {
                        // Fancy mode: use gradient/multi-color tinting
                        let colors = colorMode.gradientColors(at: now, frameIndex: frameIdx, baseColor: settings.catColor, size: catImg.size)
                        let tinted = character.isTemplate
                            ? tintImageGradient(catImg, colors: colors)
                            : tintImageGradientPreservingDetails(catImg, colors: colors)
                        if let tinted {
                            tinted.draw(in: drawRect, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1.0)
                        } else {
                            // Fallback to single-color tint
                            let tintColor = colorMode.color(at: now, frameIndex: frameIdx, baseColor: settings.catColor)
                            if let tinted = tintImage(catImg, color: tintColor) {
                                tinted.draw(in: drawRect, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1.0)
                            } else {
                                catImg.isTemplate = true
                                catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                            }
                        }
                    }
                } else {
                    // Original-only characters keep authored colors.
                    catImg.isTemplate = false
                    catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                }

                if shouldFlip {
                    if let currentContext = NSGraphicsContext.current {
                        currentContext.cgContext.restoreGState()
                    }
                }

                // Draw sparkle decorations for modes that have them
                if !character.isCustom && colorMode.hasSparkles {
                    if let currentContext = NSGraphicsContext.current {
                        let sparkleColor = colorMode.color(at: now, frameIndex: frameIdx, baseColor: settings.catColor)
                        drawSparkles(in: currentContext, rect: drawRect, time: now, color: sparkleColor)
                    }
                }
            }
        }

        let text = attributedText(layout.lines.joined(separator: "\n"), layout: layout, settings: settings, color: textColor)
        let textHeight = lineHeight(for: layout.font, settings: settings) * CGFloat(layout.lines.count)
        textRect.origin.y = (height - textHeight) / 2
        textRect.size.height = textHeight
        text.draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        image.isTemplate = useTemplate
        return image
    }

    private static func characterAsset(
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore?
    ) -> CharacterAsset {
        CharacterAsset.resolve(
            id: settings.catCharacter,
            customCharacters: customCharacterStore?.characters ?? []
        )
    }

    private static func characterImage(
        for character: CharacterAsset,
        frameIndex: Int,
        customCharacterStore: CustomCharacterStore?
    ) -> NSImage? {
        let cacheKey = CharacterImageCacheKey(characterID: character.id, frameIndex: frameIndex)
        if let cached = characterImageCache.object(forKey: cacheKey) {
            return cached
        }

        let image: NSImage? = {
            switch character.source {
            case .builtIn(let runCatCharacter):
                let resourcePath = "RunCat/\(runCatCharacter.id)"
                if let url = Bundle.main.url(forResource: "frame_\(frameIndex)", withExtension: "png", subdirectory: resourcePath) {
                    return NSImage(contentsOf: url)
                }
                if let resPath = Bundle.main.resourcePath {
                    let bundledURL = URL(fileURLWithPath: "\(resPath)/RunCat/\(runCatCharacter.id)/frame_\(frameIndex).png")
                    if let image = NSImage(contentsOf: bundledURL) {
                        return image
                    }
                }
                let sourceTreeURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("Resources")
                    .appendingPathComponent("RunCat")
                    .appendingPathComponent(runCatCharacter.id)
                    .appendingPathComponent("frame_\(frameIndex).png")
                if FileManager.default.fileExists(atPath: sourceTreeURL.path) {
                    return NSImage(contentsOf: sourceTreeURL)
                }
                return nil
            case .custom(let customCharacter):
                guard let customCharacterStore else { return nil }
                let url = customCharacterStore.frameURL(for: customCharacter, frameIndex: frameIndex)
                if let image = NSImage(contentsOf: url) {
                    return image
                }
                let fallbackURL = customCharacterStore.frameURL(for: customCharacter, frameIndex: 0)
                return NSImage(contentsOf: fallbackURL)
            }
        }()

        if let image {
            characterImageCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    private static func characterExtraWidth(
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore?,
        catFrameIndex: Int?
    ) -> CGFloat {
        guard catFrameIndex != nil, settings.showsCat else { return 0 }
        let character = characterAsset(
            settings: settings,
            customCharacterStore: customCharacterStore
        )
        return characterSize(for: character, settings: settings).width + characterSpacing(settings: settings)
    }

    private static func characterSize(for character: CharacterAsset, settings: StatusBarSettings) -> CGSize {
        let scale = settings.clampedCatScale
        let rawWidth = CGFloat(character.frameWidth) * scale
        let rawHeight = CGFloat(character.frameHeight) * scale
        guard character.isCustom else {
            return CGSize(width: rawWidth, height: 18 * scale)
        }

        let maxHeight = 18 * scale
        let fitScale = rawHeight > maxHeight ? maxHeight / max(rawHeight, 1) : 1
        return CGSize(
            width: max(rawWidth * fitScale, 1),
            height: max(rawHeight * fitScale, 1)
        )
    }

    private static func characterSpacing(settings: StatusBarSettings) -> CGFloat {
        max(2, 3 * settings.clampedCatScale)
    }

    private static func horizontalPadding(settings: StatusBarSettings) -> CGFloat {
        settings.showsBackground ? 3 : 2
    }

    static func shouldMirrorCharacter(settings: StatusBarSettings, frameIndex: Int) -> Bool {
        let baseMirror = settings.catFacing == .left
        let swingMirror = settings.catHeadSwing && frameIndex % 2 == 1
        return baseMirror != swingMirror
    }

    static func width(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore? = nil
    ) -> CGFloat {
        layout(
            snapshot: snapshot,
            settings: settings,
            customCharacterStore: customCharacterStore
        ).width
    }

    static func stableMinimumWidth(settings: StatusBarSettings) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: settings.clampedFontSize,
            weight: settings.fontWeight
        )
        let horizontalPadding = horizontalPadding(settings: settings)
        let stableWidth = stableWidthTemplates(settings: settings)
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? 1
        return ceil(stableWidth + horizontalPadding * 2)
    }

    private static func line(prefix: String, value: String, settings: StatusBarSettings) -> String {
        settings.showsArrows ? "\(prefix) \(value)" : value
    }

    private static func layout(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore?,
        catFrameIndex: Int? = nil
    ) -> Layout {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: settings.clampedFontSize,
            weight: settings.fontWeight
        )
        let upload = line(prefix: "↑", value: ByteFormat.speed(snapshot.uploadBytesPerSecond), settings: settings)
        let download = line(prefix: "↓", value: ByteFormat.speed(snapshot.downloadBytesPerSecond), settings: settings)
        let total = line(
            prefix: "↕",
            value: ByteFormat.speed(snapshot.uploadBytesPerSecond + snapshot.downloadBytesPerSecond),
            settings: settings
        )
        let displayMode = settings.trafficDisplayMode
        let lines: [String] = {
            switch displayMode {
            case .upDown:
                return settings.order == .uploadFirst ? [upload, download] : [download, upload]
            case .downloadOnly:
                return [download]
            case .uploadOnly:
                return [upload]
            case .total:
                return [total]
            }
        }()
        let horizontalPadding = horizontalPadding(settings: settings)
        let cacheKey = StatusBarTextLayoutCacheKey(
            lines: lines,
            fontSize: settings.fontSize,
            isBold: settings.isBold,
            lineSpacing: settings.lineSpacing,
            alignment: settings.alignment,
            showsBackground: settings.showsBackground
        )
        if settings.usesAutomaticWidth, let cached = textLayoutCache.layout(for: cacheKey) {
            let catExtraWidth = characterExtraWidth(
                settings: settings,
                customCharacterStore: customCharacterStore,
                catFrameIndex: catFrameIndex
            )
            return Layout(
                width: ceil(cached.width + catExtraWidth),
                horizontalPadding: cached.horizontalPadding,
                lines: cached.lines,
                font: font
            )
        }

        let measuredWidth = lines
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? 1
        let stableWidth = stableWidthTemplates(settings: settings)
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? measuredWidth

        let catExtraWidth = characterExtraWidth(
            settings: settings,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex
        )
        let automaticTextWidth = max(measuredWidth, stableWidth)
        let automaticWidth = ceil(automaticTextWidth + horizontalPadding * 2 + catExtraWidth)
        let width = settings.usesAutomaticWidth ? automaticWidth : settings.clampedWidth

        if settings.usesAutomaticWidth {
            textLayoutCache.store(
                StatusBarCachedTextLayout(
                    width: ceil(automaticTextWidth + horizontalPadding * 2),
                    horizontalPadding: horizontalPadding,
                    lines: lines
                ),
                for: cacheKey
            )
        }

        return Layout(
            width: width,
            horizontalPadding: horizontalPadding,
            lines: lines,
            font: font
        )
    }

    private struct Layout {
        let width: CGFloat
        let horizontalPadding: CGFloat
        let lines: [String]
        let font: NSFont
    }

    private static func stableWidthTemplates(settings: StatusBarSettings) -> [String] {
        let values = [
            "999 KB/s",
            "9.99 MB/s"
        ]

        guard settings.showsArrows else { return values }

        return values.flatMap { value in
            switch settings.trafficDisplayMode {
            case .upDown:
                return ["↑ \(value)", "↓ \(value)"]
            case .downloadOnly:
                return ["↓ \(value)"]
            case .uploadOnly:
                return ["↑ \(value)"]
            case .total:
                return ["↕ \(value)"]
            }
        }
    }

    private static func attributedText(
        _ text: String,
        layout: Layout,
        settings: StatusBarSettings,
        color: NSColor? = nil
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = settings.alignment.nsTextAlignment
        paragraphStyle.lineBreakMode = .byClipping
        let naturalLineHeight = layout.font.ascender - layout.font.descender
        let constrainedLineHeight = lineHeight(for: layout.font, settings: settings)
        paragraphStyle.minimumLineHeight = constrainedLineHeight
        paragraphStyle.maximumLineHeight = constrainedLineHeight
        let baselineOffset = (constrainedLineHeight - naturalLineHeight) / 2

        return NSAttributedString(
            string: text,
            attributes: [
                .font: layout.font,
                .foregroundColor: color ?? settings.effectiveTextColor,
                .paragraphStyle: paragraphStyle,
                .baselineOffset: NSNumber(value: Double(baselineOffset))
            ]
        )
    }

    private static func lineHeight(for font: NSFont, settings: StatusBarSettings) -> CGFloat {
        let naturalLineHeight = font.ascender - font.descender
        return max(naturalLineHeight + settings.clampedLineSpacing, 8)
    }

    private static func tintImage(_ image: NSImage, color: NSColor) -> NSImage? {
        let cacheKey = TintImageCacheKey(image: image, color: color)
        if let cached = tintImageCache.object(forKey: cacheKey) {
            return cached
        }

        let result = _renderTintImage(image, color: color)
        if let result {
            tintImageCache.setObject(result, forKey: cacheKey)
        }
        return result
    }

    private static func _renderTintImage(_ image: NSImage, color: NSColor) -> NSImage? {
        let size = image.size
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .destinationIn, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        let tinted = NSImage(size: size)
        tinted.addRepresentation(bitmapRep)
        return tinted
    }

    /// Tint a template image with a vertical gradient of colors.
    /// Each color is applied at its position (0=top, 1=bottom), creating
    /// a multi-colored effect where different parts of the character show different colors.
    private static func tintImageGradient(_ image: NSImage, colors: [(color: NSColor, position: CGFloat)]) -> NSImage? {
        guard colors.count >= 2 else { return nil }

        let cacheKey = GradientTintImageCacheKey(image: image, colors: colors)
        if let cached = gradientTintImageCache.object(forKey: cacheKey) {
            return cached
        }

        let result = _renderGradientTintImage(image, colors: colors)
        if let result {
            gradientTintImageCache.setObject(result, forKey: cacheKey)
        }
        return result
    }

    private static func _renderGradientTintImage(_ image: NSImage, colors: [(color: NSColor, position: CGFloat)]) -> NSImage? {
        let size = image.size
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        // Draw vertical gradient
        let gradient = NSGradient(colors: colors.map { $0.color }, atLocations: colors.map { $0.position }, colorSpace: .deviceRGB)
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 270) // top-to-bottom

        // Mask with the original image's alpha channel
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .destinationIn, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        let tinted = NSImage(size: size)
        tinted.addRepresentation(bitmapRep)
        return tinted
    }

    /// Apply a gradient color effect to full-color sprites while preserving their
    /// original luminosity, shadows, and dark outline pixels.
    private static func tintImageGradientPreservingDetails(_ image: NSImage, colors: [(color: NSColor, position: CGFloat)]) -> NSImage? {
        guard colors.count >= 2 else { return nil }

        let cacheKey = GradientTintImageCacheKey(image: image, colors: colors)
        if let cached = gradientDetailPreservingImageCache.object(forKey: cacheKey) {
            return cached
        }

        let result = _renderGradientDetailPreservingImage(image, colors: colors)
        if let result {
            gradientDetailPreservingImageCache.setObject(result, forKey: cacheKey)
        }
        return result
    }

    private static func _renderGradientDetailPreservingImage(_ image: NSImage, colors: [(color: NSColor, position: CGFloat)]) -> NSImage? {
        let size = image.size
        guard
            let gradientTint = _renderGradientTintImage(image, colors: colors),
            let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width * 2),
                pixelsHigh: Int(size.height * 2),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else { return nil }

        let rect = NSRect(origin: .zero, size: size)
        bitmapRep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        gradientTint.draw(in: rect, from: NSRect(origin: .zero, size: gradientTint.size), operation: .color, fraction: 1.0)
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .multiply, fraction: 0.35)
        image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .destinationIn, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        let tinted = NSImage(size: size)
        tinted.addRepresentation(bitmapRep)
        return tinted
    }

    /// Draw sparkle/star decorations on the tinted character.
    /// Sparkles appear at pseudo-random positions based on time, creating a twinkling effect.
    private static func drawSparkles(in context: NSGraphicsContext, rect: NSRect, time: TimeInterval, color: NSColor) {
        // Generate 3-5 sparkle positions based on time
        let sparkleCount = 4
        for i in 0..<sparkleCount {
            let timeBucket = Int(time * 3) // Change sparkle positions ~3 times/sec
            let offset = UInt32(truncatingIfNeeded: i &* 2246822519 &+ 7919)
            let mixed = UInt32(truncatingIfNeeded: timeBucket) &* 2654435761 &+ offset
            let seed = mixed &+ (mixed &>> 16)

            // Random position within the character bounds
            let xNorm = CGFloat(Double(seed % 100) / 100.0)
            let yNorm = CGFloat(Double((seed >> 7) % 100) / 100.0)
            let sparkleX = rect.minX + rect.width * (0.1 + 0.8 * xNorm)
            let sparkleY = rect.minY + rect.height * (0.1 + 0.8 * yNorm)

            // Twinkle: vary alpha over time per sparkle
            let phase = Double(seed &>> 3) * 0.1
            let alpha = 0.4 + 0.6 * abs(sin(time * 4.0 + phase))
            let sparkleColor = color.withAlphaComponent(CGFloat(alpha))

            // Draw a 4-pointed star
            let starSize: CGFloat = 2.5
            drawStar(in: context, center: NSPoint(x: sparkleX, y: sparkleY), size: starSize, color: sparkleColor)
        }
    }

    /// Draw a simple 4-pointed star shape
    private static func drawStar(in context: NSGraphicsContext, center: NSPoint, size: CGFloat, color: NSColor) {
        color.setFill()
        let path = NSBezierPath()
        // 4-pointed star
        let outerR = size
        let innerR = size * 0.35
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4.0 - .pi / 2.0
            let r = i % 2 == 0 ? outerR : innerR
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            if i == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        path.close()
        path.fill()
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
