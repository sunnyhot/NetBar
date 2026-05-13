import AppKit
import SwiftUI

struct PersistedColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = PersistedColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = PersistedColor(red: 0, green: 0, blue: 0, alpha: 1)
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

// MARK: - Cat Color Mode

enum CatColorMode: String, CaseIterable, Identifiable {
    case solid           // Single solid color (uses catColor)
    case rainbow         // Rainbow hue cycle
    case neon            // Neon glow (cycles through bright neon colors)
    case flame           // Fire gradient (red → orange → yellow)
    case ocean           // Ocean gradient (dark blue → cyan → white)
    case aurora          // Northern lights (green → cyan → purple)
    case sakura          // Cherry blossom (pink → white → light pink)
    case cyber           // Cyberpunk (magenta ↔ electric blue)
    case sunset          // Sunset (deep red → orange → purple)
    case forest          // Forest (dark green → lime → golden)
    case candy           // Candy pastels (soft colors cycling)
    case lava            // Lava (dark red → bright orange → yellow → dark)
    case galaxy          // Galaxy (deep purple → blue → pink → white)
    case matrix          // Matrix (green shades)
    case roseGold        // Rose gold (warm pink → gold → copper)
    case randomPop       // Random color per frame change (拼色)
    case randomCycle     // Smooth random color cycling (随机炫彩)

    var id: String { rawValue }

    func displayName(zh: Bool = true) -> String {
        switch self {
        case .solid:       return zh ? "纯色" : "Solid"
        case .rainbow:     return zh ? "彩虹" : "Rainbow"
        case .neon:        return zh ? "霓虹" : "Neon"
        case .flame:       return zh ? "火焰" : "Flame"
        case .ocean:       return zh ? "海洋" : "Ocean"
        case .aurora:      return zh ? "极光" : "Aurora"
        case .sakura:      return zh ? "樱花" : "Sakura"
        case .cyber:       return zh ? "赛博" : "Cyber"
        case .sunset:      return zh ? "日落" : "Sunset"
        case .forest:      return zh ? "森林" : "Forest"
        case .candy:       return zh ? "糖果" : "Candy"
        case .lava:        return zh ? "熔岩" : "Lava"
        case .galaxy:      return zh ? "星河" : "Galaxy"
        case .matrix:      return zh ? "黑客" : "Matrix"
        case .roseGold:    return zh ? "玫瑰金" : "Rose Gold"
        case .randomPop:   return zh ? "随机拼色" : "Random Pop"
        case .randomCycle: return zh ? "随机炫彩" : "Random Cycle"
        }
    }

    var isDynamic: Bool { self != .solid }

    /// Compute the current color for this mode at a given time and frame.
    /// - Parameters:
    ///   - time: Current time (used for cycling)
    ///   - frameIndex: Current animation frame index
    ///   - baseColor: Base solid color (used for .solid mode)
    /// - Returns: The NSColor to use for tinting
    func color(at time: TimeInterval, frameIndex: Int, baseColor: PersistedColor) -> NSColor {
        switch self {
        case .solid:
            return baseColor.nsColor

        case .rainbow:
            // Full hue cycle every ~3 seconds
            let hue = CGFloat((time.truncatingRemainder(dividingBy: 3.0)) / 3.0)
            return NSColor(calibratedHue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

        case .neon:
            // Cycle through bright neon: magenta → cyan → green → yellow → magenta
            let neonHues: [CGFloat] = [0.83, 0.5, 0.33, 0.17, 0.08]
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let progress = cycleTime / 4.0
            let segment = progress * CGFloat(neonHues.count - 1)
            let idx = Int(segment)
            let frac = segment - CGFloat(idx)
            let fromHue = neonHues[min(idx, neonHues.count - 1)]
            let toHue = neonHues[min(idx + 1, neonHues.count - 1)]
            let hue = fromHue + (toHue - fromHue) * frac
            return NSColor(calibratedHue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

        case .flame:
            // Red → orange → yellow cycle
            let cycleTime = time.truncatingRemainder(dividingBy: 2.0)
            let progress = CGFloat(cycleTime / 2.0)
            let hue = 0.0 + 0.12 * (0.5 + 0.5 * sin(progress * .pi * 2))
            return NSColor(calibratedHue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

        case .ocean:
            // Dark blue → cyan → white foam
            let cycleTime = time.truncatingRemainder(dividingBy: 3.0)
            let progress = CGFloat(cycleTime / 3.0)
            let hue = 0.55 + 0.1 * sin(progress * .pi * 2)
            let brightness = 0.7 + 0.3 * sin(progress * .pi * 4)
            return NSColor(calibratedHue: hue, saturation: 0.8, brightness: brightness, alpha: 1.0)

        case .aurora:
            // Green → cyan → purple
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let progress = CGFloat(cycleTime / 4.0)
            let hue = 0.33 + 0.37 * (0.5 + 0.5 * sin(progress * .pi * 2))
            return NSColor(calibratedHue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)

        case .sakura:
            // Pink → white → light pink
            let cycleTime = time.truncatingRemainder(dividingBy: 3.0)
            let progress = CGFloat(cycleTime / 3.0)
            let hue = 0.93 + 0.03 * sin(progress * .pi * 2)
            let saturation = 0.3 + 0.4 * (0.5 + 0.5 * cos(progress * .pi * 2))
            return NSColor(calibratedHue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)

        case .cyber:
            // Cyberpunk: magenta ↔ electric blue with flicker
            let cycleTime = time.truncatingRemainder(dividingBy: 2.5)
            let progress = CGFloat(cycleTime / 2.5)
            let hue = 0.83 + 0.17 * (0.5 + 0.5 * sin(progress * .pi * 2))
            // Occasional brightness flicker
            let flicker = 0.85 + 0.15 * sin(progress * .pi * 12)
            return NSColor(calibratedHue: hue, saturation: 1.0, brightness: flicker, alpha: 1.0)

        case .sunset:
            // Deep red → orange → purple dusk
            let cycleTime = time.truncatingRemainder(dividingBy: 5.0)
            let progress = CGFloat(cycleTime / 5.0)
            let hue = 0.02 + 0.08 * sin(progress * .pi * 2)
            let brightness = 0.8 + 0.2 * cos(progress * .pi * 4)
            // Brief purple phase near the end of cycle
            let purpleMix = max(0, sin(progress * .pi * 2 - .pi / 2))
            let finalHue = hue + 0.7 * purpleMix
            return NSColor(calibratedHue: finalHue, saturation: 0.9, brightness: brightness, alpha: 1.0)

        case .forest:
            // Dark green → lime → golden
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let progress = CGFloat(cycleTime / 4.0)
            let hue = 0.25 + 0.2 * (0.5 + 0.5 * sin(progress * .pi * 2))
            let saturation = 0.6 + 0.3 * cos(progress * .pi * 2)
            return NSColor(calibratedHue: hue, saturation: saturation, brightness: 0.7, alpha: 1.0)

        case .candy:
            // Pastel colors cycling: soft pink → mint → lavender → peach → baby blue
            let candyHues: [CGFloat] = [0.95, 0.45, 0.75, 0.08, 0.58]
            let candySats: [CGFloat] = [0.4, 0.35, 0.3, 0.45, 0.35]
            let cycleTime = time.truncatingRemainder(dividingBy: 5.0)
            let progress = cycleTime / 5.0
            let segment = progress * CGFloat(candyHues.count)
            let idx = Int(segment) % candyHues.count
            let nextIdx = (idx + 1) % candyHues.count
            let frac = segment - CGFloat(Int(segment))
            let hue = candyHues[idx] + (candyHues[nextIdx] - candyHues[idx]) * frac
            let sat = candySats[idx] + (candySats[nextIdx] - candySats[idx]) * frac
            return NSColor(calibratedHue: hue, saturation: sat, brightness: 1.0, alpha: 1.0)

        case .lava:
            // Dark red → bright orange → yellow → back to dark
            let cycleTime = time.truncatingRemainder(dividingBy: 3.0)
            let progress = CGFloat(cycleTime / 3.0)
            // Hue: 0.0 (red) → 0.08 (orange) → 0.15 (yellow-orange)
            let hue = 0.0 + 0.15 * (0.5 + 0.5 * sin(progress * .pi * 2))
            // Brightness pulses: dark → bright → dark
            let brightness = 0.5 + 0.5 * sin(progress * .pi * 2)
            return NSColor(calibratedHue: hue, saturation: 1.0, brightness: max(0.3, brightness), alpha: 1.0)

        case .galaxy:
            // Deep purple → blue → pink → white sparkle
            let cycleTime = time.truncatingRemainder(dividingBy: 6.0)
            let progress = CGFloat(cycleTime / 6.0)
            // Multi-phase: purple → blue → pink → white flash
            let phase = progress * 3.0
            let phaseIdx = Int(phase) % 3
            let phaseFrac = phase - CGFloat(Int(phase))
            let hues: [CGFloat] = [0.75, 0.6, 0.9]
            let sats: [CGFloat] = [0.7, 0.8, 0.5]
            let brights: [CGFloat] = [0.6, 0.7, 1.0]
            let nextIdx = (phaseIdx + 1) % 3
            let hue = hues[phaseIdx] + (hues[nextIdx] - hues[phaseIdx]) * phaseFrac
            let sat = sats[phaseIdx] + (sats[nextIdx] - sats[phaseIdx]) * phaseFrac
            let bright = brights[phaseIdx] + (brights[nextIdx] - brights[phaseIdx]) * phaseFrac
            return NSColor(calibratedHue: hue, saturation: sat, brightness: bright, alpha: 1.0)

        case .matrix:
            // Green shades cycling (Matrix digital rain)
            let cycleTime = time.truncatingRemainder(dividingBy: 2.0)
            let progress = CGFloat(cycleTime / 2.0)
            let brightness = 0.4 + 0.6 * sin(progress * .pi * 2)
            // Stay in green hue range with tiny variation
            let hue = 0.33 + 0.02 * sin(progress * .pi * 6)
            return NSColor(calibratedHue: hue, saturation: 0.9, brightness: brightness, alpha: 1.0)

        case .roseGold:
            // Warm pink → gold → copper
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let progress = CGFloat(cycleTime / 4.0)
            // Hue oscillates between pink (0.95) and gold/amber (0.1)
            let hue = 0.05 + 0.9 * (0.5 + 0.5 * cos(progress * .pi * 2))
            let saturation = 0.4 + 0.3 * sin(progress * .pi * 2)
            return NSColor(calibratedHue: hue, saturation: saturation, brightness: 0.85, alpha: 1.0)

        case .randomPop:
            // Change color on each frame change — truly random-feeling jumps
            // Use a hash of frameIndex + time bucket for variety
            let timeBucket = Int(time * 2)  // Change color ~2x per second
            // Keep hash within UInt32 range to avoid overflow crash
            let mixed = UInt32(truncatingIfNeeded: timeBucket &* 2654435761 &+ Int(frameIndex))
            let seed = mixed &+ mixed &>> 16  // extra mixing (Murmur-style)
            let hue = CGFloat(Double(seed % 360) / 360.0)
            let sat = 0.7 + 0.3 * CGFloat(Double((seed >> 8) % 100) / 100.0)
            let bright = 0.8 + 0.2 * CGFloat(Double((seed >> 16) % 100) / 100.0)
            return NSColor(calibratedHue: hue, saturation: sat.clamped(to: 0...1), brightness: bright.clamped(to: 0...1), alpha: 1.0)

        case .randomCycle:
            // Smoothly cycle through unpredictable color combinations
            // Use multiple incommensurate sine frequencies for non-repeating feel
            let t = time
            let rawHue = 0.5 + 0.5 * sin(t * 0.47 + 1.3) * cos(t * 0.31 + 0.7)
            let hue = CGFloat(max(0.0, min(1.0, rawHue)))
            let sat = CGFloat(max(0.0, min(1.0, 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 0.73 + 2.8)))))
            let bright = CGFloat(max(0.0, min(1.0, 0.7 + 0.3 * (0.5 + 0.5 * sin(t * 0.59 + 4.1)))))
            return NSColor(calibratedHue: hue, saturation: sat, brightness: bright, alpha: 1.0)
        }
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
    @Published var catColor: PersistedColor { didSet { save() } }
    @Published var catColorMode: String { didSet { save() } }

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
        catColor = Self.color(prefix: Keys.catColor, defaults: defaults, fallback: Defaults.catColor)
        catColorMode = defaults.string(forKey: Keys.catColorMode) ?? Defaults.catColorMode
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
        catColor = Defaults.catColor
        catColorMode = Defaults.catColorMode
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
        save(catColor, prefix: Keys.catColor)
        defaults.set(catColorMode, forKey: Keys.catColorMode)
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
        static let catColor = PersistedColor.white
        static let catColorMode = CatColorMode.solid.rawValue
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
        static let catColor = "statusBar.catColor"
        static let catColorMode = "statusBar.catColorMode"
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
    let catColor: PersistedColor
    let catColorMode: String
    let catColorTimeBucket: Int  // For dynamic modes: time quantized to ~50ms buckets
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
            catCharacter: settings.catCharacter,
            catColor: settings.catColor,
            catColorMode: settings.catColorMode,
            catColorTimeBucket: {
                let mode = CatColorMode(rawValue: settings.catColorMode) ?? .solid
                return mode.isDynamic ? Int(Date().timeIntervalSince1970 * 20) : 0
            }()
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
            let character = RunCatCharacter.byId(settings.catCharacter)
            let resourcePath = "RunCat/\(character.id)"
            let frameIdx = catIndex % character.frameCount
            let catImage: NSImage?
            if let url = Bundle.main.url(forResource: "frame_\(frameIdx)", withExtension: "png", subdirectory: resourcePath) {
                catImage = NSImage(contentsOf: url)
            } else if let resPath = Bundle.main.resourcePath {
                catImage = NSImage(contentsOf: URL(fileURLWithPath: "\(resPath)/RunCat/\(character.id)/frame_\(frameIdx).png"))
            } else {
                catImage = nil
            }

            if let catImg = catImage {
                // Scale: sprite is at 1x (e.g. 28x36). Draw at 1x logical size.
                // Frame width varies by character, use character.frameWidth
                let catWidth: CGFloat = CGFloat(character.frameWidth)
                let catHeight: CGFloat = 18
                let catY = (height - catHeight) / 2
                let catPadding: CGFloat = 3
                let drawRect = NSRect(x: layout.horizontalPadding, y: catY, width: catWidth, height: catHeight)

                if character.isTemplate {
                    // Template mode: tint with color from CatColorMode
                    let colorMode = CatColorMode(rawValue: settings.catColorMode) ?? .solid
                    let now = Date().timeIntervalSince1970
                    let tintColor = colorMode.color(at: now, frameIndex: frameIdx, baseColor: settings.catColor)
                    if let tinted = tintImage(catImg, color: tintColor) {
                        tinted.draw(in: drawRect, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1.0)
                    } else {
                        // Fallback: draw as template
                        catImg.isTemplate = true
                        catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                    }
                } else {
                    // Color mode (gaming-cat, party-parrot, etc.): draw with original colors
                    catImg.isTemplate = false
                    if useTemplate {
                        // In template rendering mode, draw original colors
                        // (color characters look best with their original palette)
                        catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                    } else {
                        catImg.draw(in: drawRect, from: NSRect(origin: .zero, size: catImg.size), operation: .sourceOver, fraction: 1.0)
                    }
                }

                textXOffset = layout.horizontalPadding + catWidth + catPadding
            } else {
                // Fallback: no image loaded, skip cat rendering
                let catWidth: CGFloat = CGFloat(character.frameWidth)
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
        let catChar = RunCatCharacter.byId(settings.catCharacter)
        let catExtraWidth: CGFloat = (catFrameIndex != nil && settings.showsCat) ? CGFloat(catChar.frameWidth) + 3 : 0

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
