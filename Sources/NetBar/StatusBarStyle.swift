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
        switch self {
        case .uploadFirst:
            return "上传在上"
        case .downloadFirst:
            return "下载在上"
        }
    }
}

enum StatusBarAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading:
            return "左对齐"
        case .center:
            return "居中"
        case .trailing:
            return "右对齐"
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
    @Published var textColor: PersistedColor { didSet { save() } }
    @Published var backgroundColor: PersistedColor { didSet { save() } }

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
        textColor = Self.color(prefix: Keys.textColor, defaults: defaults, fallback: Defaults.textColor)
        backgroundColor = Self.color(prefix: Keys.backgroundColor, defaults: defaults, fallback: Defaults.backgroundColor)
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
        textColor = Defaults.textColor
        backgroundColor = Defaults.backgroundColor
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
        save(textColor, prefix: Keys.textColor)
        save(backgroundColor, prefix: Keys.backgroundColor)
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
        static let textColor = PersistedColor.white
        static let backgroundColor = PersistedColor.olive
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
        static let textColor = "statusBar.textColor"
        static let backgroundColor = "statusBar.backgroundColor"
    }
}

@MainActor
enum StatusBarImageRenderer {
    static func image(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> NSImage {
        let layout = layout(snapshot: snapshot, settings: settings)
        let width = layout.width
        let height = max(NSStatusBar.system.thickness, 24)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if settings.showsBackground {
            settings.backgroundColor.nsColor
                .withAlphaComponent(CGFloat(settings.backgroundOpacity.clamped(to: 0...1)))
                .setFill()
            NSRect(origin: .zero, size: size).fill()
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = settings.alignment.nsTextAlignment
        paragraphStyle.lineBreakMode = .byClipping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: layout.font,
            .foregroundColor: settings.textColor.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let lineHeight = layout.font.ascender - layout.font.descender
        let totalHeight = lineHeight * 2 + settings.clampedLineSpacing
        let firstY = (height - totalHeight) / 2 + lineHeight + settings.clampedLineSpacing - 1
        let secondY = firstY - lineHeight - settings.clampedLineSpacing

        NSString(string: layout.lines[0]).draw(
            in: NSRect(
                x: layout.horizontalPadding,
                y: firstY,
                width: width - layout.horizontalPadding * 2,
                height: lineHeight
            ),
            withAttributes: attributes
        )
        NSString(string: layout.lines[1]).draw(
            in: NSRect(
                x: layout.horizontalPadding,
                y: secondY,
                width: width - layout.horizontalPadding * 2,
                height: lineHeight
            ),
            withAttributes: attributes
        )

        image.isTemplate = false
        return image
    }

    static func width(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> CGFloat {
        layout(snapshot: snapshot, settings: settings).width
    }

    private static func line(prefix: String, value: String, settings: StatusBarSettings) -> String {
        settings.showsArrows ? "\(prefix) \(value)" : value
    }

    private static func layout(snapshot: NetworkSnapshot, settings: StatusBarSettings) -> Layout {
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
        let automaticWidth = ceil(max(measuredWidth, stableWidth) + horizontalPadding * 2)
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
}

extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
