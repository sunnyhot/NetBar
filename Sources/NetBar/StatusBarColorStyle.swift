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
    case aurora          // Northern lights (green → cyan → purple)

    var id: String { rawValue }

    func displayName(zh: Bool = true) -> String {
        switch self {
        case .solid:       return zh ? "纯色" : "Solid"
        case .rainbow:     return zh ? "彩虹" : "Rainbow"
        case .neon:        return zh ? "霓虹" : "Neon"
        case .flame:       return zh ? "火焰" : "Flame"
        case .aurora:      return zh ? "极光" : "Aurora"
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

        case .aurora:
            // Green → cyan → purple
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let progress = CGFloat(cycleTime / 4.0)
            let hue = 0.33 + 0.37 * (0.5 + 0.5 * sin(progress * .pi * 2))
            return NSColor(calibratedHue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)
        }
    }

    // MARK: - Gradient Colors for Multi-Color Tinting

    /// Returns an array of (color, position) pairs for gradient tinting.
    /// Each fancy mode produces a vertical gradient that makes the character
    /// appear with multiple colors simultaneously (not just a flat solid color).
    ///
    /// - Parameters:
    ///   - time: Current time (used for cycling)
    ///   - frameIndex: Animation frame index
    ///   - baseColor: Base color (for solid fallback)
    ///   - size: Image size (for positioning)
    /// - Returns: Array of (NSColor, CGFloat position 0-1) tuples
    func gradientColors(at time: TimeInterval, frameIndex: Int, baseColor: PersistedColor, size: NSSize) -> [(color: NSColor, position: CGFloat)] {
        switch self {
        case .solid:
            // Solid mode: uniform single color (no gradient needed)
            return [(color: baseColor.nsColor, position: 0.0), (color: baseColor.nsColor, position: 1.0)]

        case .rainbow:
            // Full rainbow across the character body
            let hue = CGFloat((time.truncatingRemainder(dividingBy: 3.0)) / 3.0)
            return [
                (color: NSColor(calibratedHue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: (hue + 0.15).truncatingRemainder(dividingBy: 1.0), saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: (hue + 0.3).truncatingRemainder(dividingBy: 1.0), saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 1.0),
            ]

        case .neon:
            let neonHues: [CGFloat] = [0.83, 0.5, 0.33, 0.17]
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let idx = Int((cycleTime / 1.0)) % neonHues.count
            let nextIdx = (idx + 1) % neonHues.count
            return [
                (color: NSColor(calibratedHue: neonHues[idx], saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: neonHues[nextIdx], saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 1.0),
            ]

        case .flame:
            // Fire: bottom yellow → middle orange → top red
            return [
                (color: NSColor(calibratedHue: 0.12, saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.06, saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.0, saturation: 1.0, brightness: 0.9, alpha: 1.0), position: 1.0),
            ]

        case .aurora:
            // Northern lights: green → cyan → purple flowing across
            return [
                (color: NSColor(calibratedHue: 0.33, saturation: 0.7, brightness: 0.9, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.5, saturation: 0.8, brightness: 0.95, alpha: 1.0), position: 0.4),
                (color: NSColor(calibratedHue: 0.75, saturation: 0.6, brightness: 0.9, alpha: 1.0), position: 0.7),
                (color: NSColor(calibratedHue: 0.85, saturation: 0.5, brightness: 0.85, alpha: 1.0), position: 1.0),
            ]
        }
    }

    /// Whether this mode should show sparkle/star decorations on the character
    var hasSparkles: Bool {
        switch self {
        case .neon, .aurora, .rainbow:
            return true
        case .solid, .flame:
            return false
        }
    }
}

enum StatusBarOrder: String, CaseIterable, Identifiable {
    case uploadFirst
    case downloadFirst

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .uploadFirst:
            return language.text("上传在上", "Upload first")
        case .downloadFirst:
            return language.text("下载在上", "Download first")
        }
    }
}

enum StatusBarTrafficDisplayMode: String, CaseIterable, Identifiable {
    case upDown
    case downloadOnly
    case uploadOnly
    case total

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .upDown:
            return language.text("上下行", "Up / Down")
        case .downloadOnly:
            return language.text("仅下载", "Download")
        case .uploadOnly:
            return language.text("仅上传", "Upload")
        case .total:
            return language.text("总流量", "Total")
        }
    }
}

enum StatusBarAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

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

enum StatusBarCharacterPosition: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .left:
            return language.text("左侧", "Left")
        case .right:
            return language.text("右侧", "Right")
        }
    }
}

enum StatusBarCharacterFacing: String, CaseIterable, Identifiable {
    case right
    case left

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .right:
            return language.text("向右", "Right")
        case .left:
            return language.text("向左", "Left")
        }
    }
}
