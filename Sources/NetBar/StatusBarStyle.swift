import AppKit
import SwiftUI

struct PersistedColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = PersistedColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let olive = PersistedColor(red: 0.36, green: 0.35, blue: 0.12, alpha: 1)

    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    var swiftUIColor: Color {
        Color(nsColor)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        red = Double(color.redComponent)
        green = Double(color.greenComponent)
        blue = Double(color.blueComponent)
        alpha = Double(color.alphaComponent)
    }

    init(color: Color) {
        self.init(nsColor: NSColor(color))
    }
}

enum StatusBarOrder: String, CaseIterable, Identifiable {
    case uploadFirst
    case downloadFirst

    var id: String { rawValue }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .uploadFirst:
            return language.text("上传在上", "Upload first")
        case .downloadFirst:
            return language.text("下载在上", "Download first")
        }
    }
}

enum StatusBarAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .leading:
            return language.text("左对齐", "Leading")
        case .center:
            return language.text("居中", "Center")
        case .trailing:
            return language.text("右对齐", "Trailing")
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }
}

@MainActor
final class StatusBarSettings: ObservableObject {
    @Published var fontSize: Double { didSet { save() } }
    @Published var itemWidth: Double { didSet { save() } }
    @Published var usesAutomaticWidth: Bool { didSet { save() } }
    @Published var lineSpacing: Double { didSet { save() } }
    @Published var order: StatusBarOrder { didSet { save() } }
    @Published var alignment: StatusBarAlignment { didSet { save() } }
    @Published var showsArrows: Bool { didSet { save() } }
    @Published var isBold: Bool { didSet { save() } }
    @Published var showsBackground: Bool { didSet { save() } }
    @Published var backgroundOpacity: Double { didSet { save() } }
    @Published var usesSystemTextColor: Bool { didSet { save() } }
    @Published var textColor: PersistedColor { didSet { save() } }
    @Published var backgroundColor: PersistedColor { didSet { save() } }
    @Published var showsCat: Bool { didSet { save() } }
    @Published var catCharacter: String { didSet { save() } }
    @Published var catSpeedMultiplier: Double { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? Defaults.fontSize
        itemWidth = defaults.object(forKey: Keys.itemWidth) as? Double ?? Defaults.itemWidth
        usesAutomaticWidth = defaults.object(forKey: Keys.usesAutomaticWidth) as? Bool ?? Defaults.usesAutomaticWidth
        lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? Defaults.lineSpacing
        order = StatusBarOrder(rawValue: defaults.string(forKey: Keys.order) ?? "") ?? Defaults.order
        alignment = StatusBarAlignment(rawValue: defaults.string(forKey: Keys.alignment) ?? "") ?? Defaults.alignment
        showsArrows = defaults.object(forKey: Keys.showsArrows) as? Bool ?? Defaults.showsArrows
        isBold = defaults.object(forKey: Keys.isBold) as? Bool ?? Defaults.isBold
        showsBackground = defaults.object(forKey: Keys.showsBackground) as? Bool ?? Defaults.showsBackground
        backgroundOpacity = defaults.object(forKey: Keys.backgroundOpacity) as? Double ?? Defaults.backgroundOpacity
        usesSystemTextColor = defaults.object(forKey: Keys.usesSystemTextColor) as? Bool ?? Defaults.usesSystemTextColor
        textColor = Self.color(prefix: Keys.textColor, defaults: defaults, fallback: Defaults.textColor)
        backgroundColor = Self.color(prefix: Keys.backgroundColor, defaults: defaults, fallback: Defaults.backgroundColor)
        showsCat = defaults.object(forKey: Keys.showsCat) as? Bool ?? Defaults.showsCat
        catCharacter = defaults.string(forKey: Keys.catCharacter) ?? Defaults.catCharacter
        catSpeedMultiplier = defaults.object(forKey: Keys.catSpeedMultiplier) as? Double ?? Defaults.catSpeedMultiplier
    }

    var clampedFontSize: CGFloat {
        CGFloat(fontSize.clamped(to: 8...18))
    }

    var clampedWidth: CGFloat {
        CGFloat(itemWidth.clamped(to: 36...220))
    }

    var clampedLineSpacing: CGFloat {
        CGFloat(lineSpacing.clamped(to: -5...8))
    }

    var fontWeight: NSFont.Weight {
        isBold ? .semibold : .medium
    }

    var effectiveTextColor: NSColor {
        usesSystemTextColor ? .labelColor : textColor.nsColor
    }

    func reset() {
        fontSize = Defaults.fontSize
        itemWidth = Defaults.itemWidth
        usesAutomaticWidth = Defaults.usesAutomaticWidth
        lineSpacing = Defaults.lineSpacing
        order = Defaults.order
        alignment = Defaults.alignment
        showsArrows = Defaults.showsArrows
        isBold = Defaults.isBold
        showsBackground = Defaults.showsBackground
        backgroundOpacity = Defaults.backgroundOpacity
        usesSystemTextColor = Defaults.usesSystemTextColor
        textColor = Defaults.textColor
        backgroundColor = Defaults.backgroundColor
        showsCat = Defaults.showsCat
        catCharacter = Defaults.catCharacter
        catSpeedMultiplier = Defaults.catSpeedMultiplier
    }

    private func save() {
        defaults.set(fontSize, forKey: Keys.fontSize)
        defaults.set(itemWidth, forKey: Keys.itemWidth)
        defaults.set(usesAutomaticWidth, forKey: Keys.usesAutomaticWidth)
        defaults.set(lineSpacing, forKey: Keys.lineSpacing)
        defaults.set(order.rawValue, forKey: Keys.order)
        defaults.set(alignment.rawValue, forKey: Keys.alignment)
        defaults.set(showsArrows, forKey: Keys.showsArrows)
        defaults.set(isBold, forKey: Keys.isBold)
        defaults.set(showsBackground, forKey: Keys.showsBackground)
        defaults.set(backgroundOpacity, forKey: Keys.backgroundOpacity)
        defaults.set(usesSystemTextColor, forKey: Keys.usesSystemTextColor)
        save(textColor, prefix: Keys.textColor)
        save(backgroundColor, prefix: Keys.backgroundColor)
        defaults.set(showsCat, forKey: Keys.showsCat)
        defaults.set(catCharacter, forKey: Keys.catCharacter)
        defaults.set(catSpeedMultiplier, forKey: Keys.catSpeedMultiplier)
    }

    private func save(_ color: PersistedColor, prefix: String) {
        defaults.set(color.red, forKey: "\(prefix).red")
        defaults.set(color.green, forKey: "\(prefix).green")
        defaults.set(color.blue, forKey: "\(prefix).blue")
        defaults.set(color.alpha, forKey: "\(prefix).alpha")
    }

    private static func color(prefix: String, defaults: UserDefaults, fallback: PersistedColor) -> PersistedColor {
        guard
            let red = defaults.object(forKey: "\(prefix).red") as? Double,
            let green = defaults.object(forKey: "\(prefix).green") as? Double,
            let blue = defaults.object(forKey: "\(prefix).blue") as? Double
        else {
            return fallback
        }

        let alpha = defaults.object(forKey: "\(prefix).alpha") as? Double ?? fallback.alpha
        return PersistedColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private enum Defaults {
        static let fontSize = 11.5
        static let itemWidth = 96.0
        static let usesAutomaticWidth = true
        static let lineSpacing = -2.0
        static let order = StatusBarOrder.uploadFirst
        static let alignment = StatusBarAlignment.leading
        static let showsArrows = true
        static let isBold = true
        static let showsBackground = false
        static let backgroundOpacity = 0.0
        static let usesSystemTextColor = true
        static let textColor = PersistedColor.white
        static let backgroundColor = PersistedColor.olive
        static let showsCat = true
        static let catCharacter = "cat"
        static let catSpeedMultiplier = 1.0
    }

    private enum Keys {
        static let fontSize = "statusBar.fontSize"
        static let itemWidth = "statusBar.itemWidth"
        static let usesAutomaticWidth = "statusBar.usesAutomaticWidth"
        static let lineSpacing = "statusBar.lineSpacing"
        static let order = "statusBar.order"
        static let alignment = "statusBar.alignment"
        static let showsArrows = "statusBar.showsArrows"
        static let isBold = "statusBar.isBold"
        static let showsBackground = "statusBar.showsBackground"
        static let backgroundOpacity = "statusBar.backgroundOpacity"
        static let usesSystemTextColor = "statusBar.usesSystemTextColor"
        static let textColor = "statusBar.textColor"
        static let backgroundColor = "statusBar.backgroundColor"
        static let showsCat = "statusBar.showsCat"
        static let catCharacter = "statusBar.catCharacter"
        static let catSpeedMultiplier = "statusBar.catSpeedMultiplier"
    }
}

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
    let order: StatusBarOrder
    let alignment: StatusBarAlignment
    let showsArrows: Bool
    let isBold: Bool
    let showsBackground: Bool
    let backgroundOpacity: Double
    let usesSystemTextColor: Bool
    let textColor: PersistedColor
    let backgroundColor: PersistedColor
    let appearanceName: String
    let catFrameIndex: Int?
    let catCharacter: String
}

@MainActor
enum StatusBarDisplayRenderer {
    static func presentation(snapshot: NetworkSnapshot, settings: StatusBarSettings, catFrameIndex: Int? = nil) -> StatusBarPresentation {
        let layout = layout(snapshot: snapshot, settings: settings, catFrameIndex: catFrameIndex)
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
        catFrameIndex: Int? = nil
    ) -> StatusBarRenderSignature {
        StatusBarRenderSignature(
            presentation: presentation(snapshot: snapshot, settings: settings, catFrameIndex: catFrameIndex),
            fontSize: settings.fontSize,
            itemWidth: settings.itemWidth,
            usesAutomaticWidth: settings.usesAutomaticWidth,
            lineSpacing: settings.lineSpacing,
            order: settings.order,
            alignment: settings.alignment,
            showsArrows: settings.showsArrows,
            isBold: settings.isBold,
            showsBackground: settings.showsBackground,
            backgroundOpacity: settings.backgroundOpacity,
            usesSystemTextColor: settings.usesSystemTextColor,
            textColor: settings.textColor,
            backgroundColor: settings.backgroundColor,
            appearanceName: appearanceName,
            catFrameIndex: catFrameIndex,
            catCharacter: settings.catCharacter
        )
    }

    static func attributedTitle(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> NSAttributedString {
        let layout = layout(snapshot: snapshot, settings: settings)
        return attributedText(layout.lines.joined(separator: "\n"), layout: layout, settings: settings)
    }

    static func image(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> NSImage {
        image(snapshot: snapshot, settings: settings, scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    static func image(snapshot: NetworkSnapshot, settings: StatusBarSettings, catFrameIndex: Int? = nil) -> NSImage {
        image(snapshot: snapshot, settings: settings, scale: NSScreen.main?.backingScaleFactor ?? 2, catFrameIndex: catFrameIndex)
    }

    static func image(snapshot: NetworkSnapshot, settings: StatusBarSettings, scale: CGFloat, catFrameIndex: Int? = nil) -> NSImage {
        let layout = layout(snapshot: snapshot, settings: settings, catFrameIndex: catFrameIndex)
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
        }

        let useTemplate = settings.usesSystemTextColor && !settings.showsBackground
        let textColor = useTemplate ? NSColor.black : settings.effectiveTextColor

        // Draw cat frame if enabled
        var textXOffset: CGFloat = layout.horizontalPadding
        if let catIndex = catFrameIndex, settings.showsCat {
            // Load the cat character image from the pre-cached animation frames
            let character = RunCatCharacter(rawValue: settings.catCharacter) ?? .cat
            let resourcePath = "RunCat/\(character.resourceDir)"
            let frameIdx = catIndex % character.frameCount
            let catImage: NSImage?
            if let url = Bundle.main.url(forResource: "frame_\(frameIdx)", withExtension: "png", subdirectory: resourcePath) {
                catImage = NSImage(contentsOf: url)
            } else if let resPath = Bundle.main.resourcePath {
                catImage = NSImage(contentsOf: URL(fileURLWithPath: "\(resPath)/RunCat/\(character.resourceDir)/frame_\(frameIdx).png"))
            } else {
                catImage = nil
            }

            if let catImg = catImage {
                // Scale: sprite is at 2x (e.g. 56x36 for 28x18pt). Draw at 1x logical size.
                let spritePointsW = catImg.size.width / 2  // 28pt for cat/gaming-cat, 24pt for parrot
                let catWidth: CGFloat = min(spritePointsW, 28)
                let catHeight: CGFloat = 18
                let catY = (height - catHeight) / 2
                let catPadding: CGFloat = 3
                let drawRect = NSRect(x: layout.horizontalPadding, y: catY, width: catWidth, height: catHeight)

                if character.isTemplate {
                    // Template mode: draw as-is (macOS handles inversion)
                    catImg.isTemplate = true
                    catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                } else {
                    // Color mode (gaming-cat, party-parrot): draw with original colors
                    catImg.isTemplate = false
                    if useTemplate {
                        // In template rendering mode, we need to tint the image to match text color
                        // Draw image into a tinted version
                        if let tinted = tintImage(catImg, color: .black) {
                            tinted.isTemplate = true
                            tinted.draw(in: drawRect, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1.0)
                        }
                    } else {
                        catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                    }
                }

                textXOffset = layout.horizontalPadding + catWidth + catPadding
            } else {
                // Fallback: no image loaded, skip cat rendering
                let catWidth: CGFloat = 22
                let catPadding: CGFloat = 3
                textXOffset = layout.horizontalPadding + catWidth + catPadding
            }
        }

        let text = attributedText(layout.lines.joined(separator: "\n"), layout: layout, settings: settings, color: textColor)
        let textHeight = lineHeight(for: layout.font, settings: settings) * CGFloat(layout.lines.count)
        text.draw(
            with: NSRect(
                x: textXOffset,
                y: (height - textHeight) / 2,
                width: width - textXOffset - layout.horizontalPadding,
                height: textHeight
            ),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        image.isTemplate = useTemplate
        return image
    }

    static func width(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> CGFloat {
        layout(snapshot: snapshot, settings: settings).width
    }

    static func stableMinimumWidth(settings: StatusBarSettings) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: settings.clampedFontSize,
            weight: settings.fontWeight
        )
        let horizontalPadding: CGFloat = settings.showsBackground ? 8 : 2
        let stableWidth = stableWidthTemplates(settings: settings)
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? 1
        return ceil(stableWidth + horizontalPadding * 2)
    }

    private static func line(prefix: String, value: String, settings: StatusBarSettings) -> String {
        settings.showsArrows ? "\(prefix) \(value)" : value
    }

    private static func layout(snapshot: NetworkSnapshot, settings: StatusBarSettings, catFrameIndex: Int? = nil) -> Layout {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: settings.clampedFontSize,
            weight: settings.fontWeight
        )
        let upload = line(prefix: "↑", value: ByteFormat.speed(snapshot.uploadBytesPerSecond), settings: settings)
        let download = line(prefix: "↓", value: ByteFormat.speed(snapshot.downloadBytesPerSecond), settings: settings)
        let lines = settings.order == .uploadFirst ? [upload, download] : [download, upload]
        let horizontalPadding: CGFloat = settings.showsBackground ? 8 : 2
        let measuredWidth = lines
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? 1
        let stableWidth = stableWidthTemplates(settings: settings)
            .map { NSString(string: $0).size(withAttributes: [.font: font]).width }
            .max() ?? measuredWidth

        // Add cat width if shown
        let catCharacter = RunCatCharacter(rawValue: settings.catCharacter) ?? .cat
        let catSpriteW: CGFloat = catCharacter == .partyParrot ? 24 : 28  // parrot is 48px@2x=24pt, cat is 56px@2x=28pt
        let catExtraWidth: CGFloat = (catFrameIndex != nil && settings.showsCat) ? catSpriteW + 3 : 0

        let automaticWidth = ceil(max(measuredWidth, stableWidth) + horizontalPadding * 2 + catExtraWidth)
        let width = settings.usesAutomaticWidth ? automaticWidth : settings.clampedWidth

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
            ["↑ \(value)", "↓ \(value)"]
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
}

extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
