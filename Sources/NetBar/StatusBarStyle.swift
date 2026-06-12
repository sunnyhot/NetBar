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
    case arcanePrism     // Arcane prism (gem-like magic color flow)
    case heatVision      // Heat vision (red eye beams)
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
        case .arcanePrism: return zh ? "魔法炫彩" : "Arcane Prism"
        case .heatVision:  return zh ? "热视线" : "Heat Vision"
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

        case .arcanePrism:
            // Gem-like magical highlight: violet → azure → cyan → gold → rose.
            let cycleTime = time.truncatingRemainder(dividingBy: 4.8)
            let progress = CGFloat(cycleTime / 4.8)
            let hue = (0.76 + progress * 0.42 + CGFloat(frameIndex % 5) * 0.025).truncatingRemainder(dividingBy: 1.0)
            let pulse = 0.5 + 0.5 * sin(progress * .pi * 4)
            return NSColor(
                calibratedHue: hue,
                saturation: 0.86 + 0.12 * pulse,
                brightness: 0.9 + 0.1 * (1 - pulse),
                alpha: 1.0
            )

        case .heatVision:
            let cycleTime = time.truncatingRemainder(dividingBy: 1.6)
            let progress = CGFloat(cycleTime / 1.6)
            let pulse = 0.5 + 0.5 * sin(progress * .pi * 2)
            let hue = 0.01 + 0.035 * pulse
            return NSColor(
                calibratedHue: hue,
                saturation: 0.95,
                brightness: 0.92 + 0.08 * pulse,
                alpha: 1.0
            )

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

    // MARK: - Gradient Colors for Multi-Color Tinting

    /// Returns an array of (color, position) pairs for gradient tinting.
    /// Each fancy mode produces a vertical gradient that makes the character
    /// appear with multiple colors simultaneously (not just a flat solid color).
    /// - Parameters:
    ///   - time: Current time for cycling
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

        case .ocean:
            // Ocean: top cyan → middle blue → bottom deep navy
            return [
                (color: NSColor(calibratedHue: 0.52, saturation: 0.7, brightness: 0.95, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.6, saturation: 0.9, brightness: 0.8, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.65, saturation: 1.0, brightness: 0.5, alpha: 1.0), position: 1.0),
            ]

        case .aurora:
            // Northern lights: green → cyan → purple flowing across
            return [
                (color: NSColor(calibratedHue: 0.33, saturation: 0.7, brightness: 0.9, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.5, saturation: 0.8, brightness: 0.95, alpha: 1.0), position: 0.4),
                (color: NSColor(calibratedHue: 0.75, saturation: 0.6, brightness: 0.9, alpha: 1.0), position: 0.7),
                (color: NSColor(calibratedHue: 0.85, saturation: 0.5, brightness: 0.85, alpha: 1.0), position: 1.0),
            ]

        case .sakura:
            // Cherry blossom: top pink → middle white → bottom light pink
            return [
                (color: NSColor(calibratedHue: 0.95, saturation: 0.5, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.95, saturation: 0.15, brightness: 1.0, alpha: 1.0), position: 0.4),
                (color: NSColor(calibratedHue: 0.93, saturation: 0.4, brightness: 1.0, alpha: 1.0), position: 1.0),
            ]

        case .cyber:
            // Cyberpunk: magenta ↔ electric blue split
            return [
                (color: NSColor(calibratedHue: 0.83, saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.7, saturation: 0.9, brightness: 0.9, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.58, saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 1.0),
            ]

        case .sunset:
            // Sunset: top purple → middle orange → bottom deep red
            return [
                (color: NSColor(calibratedHue: 0.8, saturation: 0.7, brightness: 0.85, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.08, saturation: 0.95, brightness: 1.0, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.0, saturation: 1.0, brightness: 0.8, alpha: 1.0), position: 1.0),
            ]

        case .forest:
            // Forest: top golden → middle lime → bottom dark green
            return [
                (color: NSColor(calibratedHue: 0.12, saturation: 0.7, brightness: 0.8, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.25, saturation: 0.8, brightness: 0.7, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.35, saturation: 0.9, brightness: 0.5, alpha: 1.0), position: 1.0),
            ]

        case .candy:
            let candyHues: [CGFloat] = [0.95, 0.08, 0.5, 0.75]
            let candySats: [CGFloat] = [0.6, 0.7, 0.5, 0.6]
            let cycleTime = time.truncatingRemainder(dividingBy: 4.0)
            let idx = Int(cycleTime) % candyHues.count
            return [
                (color: NSColor(calibratedHue: candyHues[idx], saturation: candySats[idx], brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: candyHues[(idx + 1) % candyHues.count], saturation: candySats[(idx + 1) % candySats.count], brightness: 1.0, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: candyHues[(idx + 2) % candyHues.count], saturation: candySats[(idx + 2) % candySats.count], brightness: 1.0, alpha: 1.0), position: 1.0),
            ]

        case .lava:
            // Lava: top bright yellow → middle orange → bottom dark red
            return [
                (color: NSColor(calibratedHue: 0.13, saturation: 1.0, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.06, saturation: 1.0, brightness: 0.9, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.0, saturation: 1.0, brightness: 0.5, alpha: 1.0), position: 1.0),
            ]

        case .galaxy:
            // Galaxy: top white sparkle → middle pink → bottom deep purple
            return [
                (color: NSColor(calibratedHue: 0.7, saturation: 0.15, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.85, saturation: 0.6, brightness: 0.9, alpha: 1.0), position: 0.4),
                (color: NSColor(calibratedHue: 0.72, saturation: 0.9, brightness: 0.6, alpha: 1.0), position: 1.0),
            ]

        case .matrix:
            // Matrix: top bright green → middle → bottom dark green
            return [
                (color: NSColor(calibratedHue: 0.33, saturation: 0.6, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.33, saturation: 0.9, brightness: 0.7, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.33, saturation: 1.0, brightness: 0.35, alpha: 1.0), position: 1.0),
            ]

        case .roseGold:
            // Rose gold: top warm pink → middle gold → bottom copper
            return [
                (color: NSColor(calibratedHue: 0.95, saturation: 0.45, brightness: 0.95, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.1, saturation: 0.6, brightness: 0.9, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: 0.06, saturation: 0.7, brightness: 0.75, alpha: 1.0), position: 1.0),
            ]

        case .arcanePrism:
            // Arcane prism: saturated gem facets with a slow hue drift.
            let drift = CGFloat((time.truncatingRemainder(dividingBy: 4.8)) / 4.8) * 0.2 + CGFloat(frameIndex % 5) * 0.012
            let stops: [(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, position: CGFloat)] = [
                (0.77, 0.92, 0.98, 0.0),
                (0.63, 0.90, 1.00, 0.16),
                (0.54, 0.86, 1.00, 0.31),
                (0.46, 0.82, 0.96, 0.47),
                (0.12, 0.88, 1.00, 0.64),
                (0.93, 0.86, 1.00, 0.81),
                (0.82, 0.92, 0.98, 1.0),
            ]
            return stops.map { stop in
                (
                    color: NSColor(
                        calibratedHue: (stop.hue + drift).truncatingRemainder(dividingBy: 1.0),
                        saturation: stop.saturation,
                        brightness: stop.brightness,
                        alpha: 1.0
                    ),
                    position: stop.position
                )
            }

        case .heatVision:
            let pulse = CGFloat(0.5 + 0.5 * sin(time * 4.2 + Double(frameIndex) * 0.3))
            let redCore = 0.98 + 0.02 * pulse
            return [
                (color: NSColor(calibratedHue: 0.0, saturation: 0.98, brightness: redCore, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: 0.025, saturation: 0.96, brightness: 1.0, alpha: 1.0), position: 0.28),
                (color: NSColor(calibratedHue: 0.07, saturation: 0.88, brightness: 1.0, alpha: 1.0), position: 0.55),
                (color: NSColor(calibratedHue: 0.0, saturation: 1.0, brightness: 0.82 + 0.14 * pulse, alpha: 1.0), position: 1.0),
            ]

        case .randomPop:
            // Random: 2-3 random colors split across the body
            let timeBucket = Int(time * 2)
            let mixed = UInt32(truncatingIfNeeded: timeBucket &* 2654435761 &+ Int(frameIndex))
            let seed = mixed &+ mixed &>> 16
            let hue1 = CGFloat(Double(seed % 360) / 360.0)
            let hue2 = CGFloat(Double((seed >> 8) % 360) / 360.0)
            let hue3 = CGFloat(Double((seed >> 16) % 360) / 360.0)
            return [
                (color: NSColor(calibratedHue: hue1, saturation: 0.85, brightness: 1.0, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: hue2, saturation: 0.9, brightness: 0.95, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: hue3, saturation: 0.85, brightness: 1.0, alpha: 1.0), position: 1.0),
            ]

        case .randomCycle:
            // Smooth cycling multi-color
            let t = time
            let hue1 = CGFloat(max(0.0, min(1.0, 0.5 + 0.5 * sin(t * 0.47 + 1.3))))
            let hue2 = CGFloat(max(0.0, min(1.0, 0.5 + 0.5 * sin(t * 0.31 + 2.7))))
            let hue3 = CGFloat(max(0.0, min(1.0, 0.5 + 0.5 * sin(t * 0.59 + 4.1))))
            return [
                (color: NSColor(calibratedHue: hue1, saturation: 0.8, brightness: 0.95, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: hue2, saturation: 0.9, brightness: 1.0, alpha: 1.0), position: 0.5),
                (color: NSColor(calibratedHue: hue3, saturation: 0.85, brightness: 0.9, alpha: 1.0), position: 1.0),
            ]
        }
    }

    /// Whether this mode should show sparkle/star decorations on the character
    var hasSparkles: Bool {
        switch self {
        case .galaxy, .neon, .aurora, .cyber, .candy, .arcanePrism, .heatVision, .randomPop, .rainbow:
            return true
        default:
            return false
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

@MainActor
final class StatusBarSettings: ObservableObject {
    @Published var fontSize: Double { didSet { save() } }
    @Published var itemWidth: Double { didSet { save() } }
    @Published var usesAutomaticWidth: Bool { didSet { save() } }
    @Published var lineSpacing: Double { didSet { save() } }
    @Published var trafficDisplayMode: StatusBarTrafficDisplayMode { didSet { save() } }
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
    @Published var catScale: Double { didSet { save() } }
    @Published var catPosition: StatusBarCharacterPosition { didSet { save() } }
    @Published var catFacing: StatusBarCharacterFacing { didSet { save() } }
    @Published var catSpeedMultiplier: Double { didSet { save() } }
    @Published var catColor: PersistedColor { didSet { save() } }
    @Published var catColorMode: String { didSet { save() } }
    @Published var catRotationEnabled: Bool { didSet { save() } }
    @Published var catRotationIntervalMinutes: Double { didSet { save() } }
    @Published var catRotationPool: String { didSet { save() } }  // comma-separated character IDs
    @Published var catHeadSwing: Bool { didSet { save() } }  // horizontally flip alternate frames for head-bobbing effect
    @Published var catAnimationSpeedSource: String { didSet { save() } }  // AnimationSpeedSource raw value

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? Defaults.fontSize
        itemWidth = defaults.object(forKey: Keys.itemWidth) as? Double ?? Defaults.itemWidth
        usesAutomaticWidth = defaults.object(forKey: Keys.usesAutomaticWidth) as? Bool ?? Defaults.usesAutomaticWidth
        lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? Defaults.lineSpacing
        trafficDisplayMode = StatusBarTrafficDisplayMode(rawValue: defaults.string(forKey: Keys.trafficDisplayMode) ?? "") ?? Defaults.trafficDisplayMode
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
        catScale = defaults.object(forKey: Keys.catScale) as? Double ?? Defaults.catScale
        catPosition = StatusBarCharacterPosition(rawValue: defaults.string(forKey: Keys.catPosition) ?? "") ?? Defaults.catPosition
        catFacing = StatusBarCharacterFacing(rawValue: defaults.string(forKey: Keys.catFacing) ?? "") ?? Defaults.catFacing
        catSpeedMultiplier = defaults.object(forKey: Keys.catSpeedMultiplier) as? Double ?? Defaults.catSpeedMultiplier
        catColor = Self.color(prefix: Keys.catColor, defaults: defaults, fallback: Defaults.catColor)
        catColorMode = defaults.string(forKey: Keys.catColorMode) ?? Defaults.catColorMode
        catRotationEnabled = defaults.object(forKey: Keys.catRotationEnabled) as? Bool ?? Defaults.catRotationEnabled
        catRotationIntervalMinutes = defaults.object(forKey: Keys.catRotationIntervalMinutes) as? Double ?? Defaults.catRotationIntervalMinutes
        catRotationPool = defaults.string(forKey: Keys.catRotationPool) ?? Defaults.catRotationPool
        catHeadSwing = defaults.object(forKey: Keys.catHeadSwing) as? Bool ?? Defaults.catHeadSwing
        catAnimationSpeedSource = defaults.string(forKey: Keys.catAnimationSpeedSource) ?? Defaults.catAnimationSpeedSource
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

    var clampedCatScale: CGFloat {
        CGFloat(catScale.clamped(to: 0.7...1.3))
    }

    /// The resolved animation speed source, falling back to `.networkSpeed` for invalid raw values.
    var resolvedAnimationSpeedSource: AnimationSpeedSource {
        AnimationSpeedSource(rawValue: catAnimationSpeedSource) ?? .networkSpeed
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
        trafficDisplayMode = Defaults.trafficDisplayMode
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
        catScale = Defaults.catScale
        catPosition = Defaults.catPosition
        catFacing = Defaults.catFacing
        catSpeedMultiplier = Defaults.catSpeedMultiplier
        catColor = Defaults.catColor
        catColorMode = Defaults.catColorMode
        catRotationEnabled = Defaults.catRotationEnabled
        catRotationIntervalMinutes = Defaults.catRotationIntervalMinutes
        catRotationPool = Defaults.catRotationPool
        catHeadSwing = Defaults.catHeadSwing
        catAnimationSpeedSource = Defaults.catAnimationSpeedSource
    }

    private func save() {
        defaults.set(fontSize, forKey: Keys.fontSize)
        defaults.set(itemWidth, forKey: Keys.itemWidth)
        defaults.set(usesAutomaticWidth, forKey: Keys.usesAutomaticWidth)
        defaults.set(lineSpacing, forKey: Keys.lineSpacing)
        defaults.set(trafficDisplayMode.rawValue, forKey: Keys.trafficDisplayMode)
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
        defaults.set(catScale, forKey: Keys.catScale)
        defaults.set(catPosition.rawValue, forKey: Keys.catPosition)
        defaults.set(catFacing.rawValue, forKey: Keys.catFacing)
        defaults.set(catSpeedMultiplier, forKey: Keys.catSpeedMultiplier)
        save(catColor, prefix: Keys.catColor)
        defaults.set(catColorMode, forKey: Keys.catColorMode)
        defaults.set(catRotationEnabled, forKey: Keys.catRotationEnabled)
        defaults.set(catRotationIntervalMinutes, forKey: Keys.catRotationIntervalMinutes)
        defaults.set(catRotationPool, forKey: Keys.catRotationPool)
        defaults.set(catHeadSwing, forKey: Keys.catHeadSwing)
        defaults.set(catAnimationSpeedSource, forKey: Keys.catAnimationSpeedSource)
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
        static let trafficDisplayMode = StatusBarTrafficDisplayMode.upDown
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
        static let catScale = 1.0
        static let catPosition = StatusBarCharacterPosition.left
        static let catFacing = StatusBarCharacterFacing.right
        static let catSpeedMultiplier = 1.0
        static let catColor = PersistedColor.white
        static let catColorMode = CatColorMode.solid.rawValue
        static let catRotationEnabled = false
        static let catRotationIntervalMinutes = 5.0
        static let catRotationPool = ""  // empty = all characters
        static let catHeadSwing = false
        static let catAnimationSpeedSource = AnimationSpeedSource.networkSpeed.rawValue
    }

    private enum Keys {
        static let fontSize = "statusBar.fontSize"
        static let itemWidth = "statusBar.itemWidth"
        static let usesAutomaticWidth = "statusBar.usesAutomaticWidth"
        static let lineSpacing = "statusBar.lineSpacing"
        static let trafficDisplayMode = "statusBar.trafficDisplayMode"
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
        static let catScale = "statusBar.catScale"
        static let catPosition = "statusBar.catPosition"
        static let catFacing = "statusBar.catFacing"
        static let catSpeedMultiplier = "statusBar.catSpeedMultiplier"
        static let catColor = "statusBar.catColor"
        static let catColorMode = "statusBar.catColorMode"
        static let catRotationEnabled = "statusBar.catRotationEnabled"
        static let catRotationIntervalMinutes = "statusBar.catRotationIntervalMinutes"
        static let catRotationPool = "statusBar.catRotationPool"
        static let catHeadSwing = "statusBar.catHeadSwing"
        static let catAnimationSpeedSource = "statusBar.catAnimationSpeedSource"
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
    let smartContext: SmartStatusBarContext
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
    let googlyEyesState: GooglyEyesRenderState?
}

struct GooglyEyesRenderState: Equatable {
    let mouseLocation: CGPoint
    let statusItemFrame: CGRect
    let isBlinking: Bool
}

@MainActor
enum StatusBarDisplayRenderer {

    // MARK: - Image Caches

    private static let characterImageCache = NSCache<CharacterImageCacheKey, NSImage>()

    private static let tintImageCache = NSCache<TintImageCacheKey, NSImage>()

    private static let gradientTintImageCache: NSCache<GradientTintImageCacheKey, NSImage> = {
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
        catFrameIndex: Int? = nil,
        smartContext: SmartStatusBarContext = .manual
    ) -> StatusBarPresentation {
        let layout = layout(
            snapshot: snapshot,
            settings: settings,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex,
            smartContext: smartContext
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
        googlyEyesState: GooglyEyesRenderState? = nil,
        smartContext: SmartStatusBarContext = .manual
    ) -> StatusBarRenderSignature {
        StatusBarRenderSignature(
            presentation: presentation(
                snapshot: snapshot,
                settings: settings,
                customCharacterStore: customCharacterStore,
                catFrameIndex: catFrameIndex,
                smartContext: smartContext
            ),
            smartContext: smartContext,
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
            appearanceName: appearanceName,
            catFrameIndex: catFrameIndex,
            catCharacter: settings.catCharacter,
            catScale: settings.catScale,
            catPosition: settings.catPosition,
            catFacing: settings.catFacing,
            catColor: settings.catColor,
            catColorMode: settings.catColorMode,
            catColorTimeBucket: Self.colorTimeBucket(forMode: settings.catColorMode),
            catHeadSwing: settings.catHeadSwing,
            customCharacterRevision: customCharacterStore?.revision ?? 0,
            googlyEyesState: googlyEyesState
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
        googlyEyesState: GooglyEyesRenderState? = nil,
        smartContext: SmartStatusBarContext = .manual
    ) -> NSImage {
        image(
            snapshot: snapshot,
            settings: settings,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex,
            googlyEyesState: googlyEyesState,
            smartContext: smartContext
        )
    }

    static func image(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        scale: CGFloat,
        customCharacterStore: CustomCharacterStore? = nil,
        catFrameIndex: Int? = nil,
        googlyEyesState: GooglyEyesRenderState? = nil,
        smartContext: SmartStatusBarContext = .manual
    ) -> NSImage {
        let layout = layout(
            snapshot: snapshot,
            settings: settings,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex,
            smartContext: smartContext
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
        }

        // Determine if cat has custom coloring (non-default-white solid or fancy mode)
        let colorMode = CatColorMode(rawValue: settings.catColorMode) ?? .solid
        let catHasCustomColor: Bool
        if settings.showsCat, catFrameIndex != nil {
            let character = characterAsset(settings: settings, customCharacterStore: customCharacterStore)
            if character.isCustom {
                catHasCustomColor = true
            } else if character.isGooglyEyes {
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
            let character = characterAsset(settings: settings, customCharacterStore: customCharacterStore)
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

            if character.isGooglyEyes {
                drawGooglyEyes(
                    in: drawRect,
                    state: googlyEyesState,
                    accentColor: googlyEyesAccentColor(colorMode: colorMode, settings: settings, frameIndex: frameIdx),
                    colorMode: colorMode,
                    facing: settings.catFacing
                )
            } else {
                let catImage = characterImage(
                    for: character,
                    frameIndex: frameIdx,
                    customCharacterStore: customCharacterStore
                )

                if let catImg = catImage {
                    let now = Date().timeIntervalSince1970

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

                    if character.isTemplate {
                        // Template mode: tint with color from CatColorMode
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
                            if let tinted = tintImageGradient(catImg, colors: colors) {
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
                        // Color mode (gaming-cat, party-parrot, etc.): draw with original colors
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

    private static func drawGooglyEyes(
        in rect: NSRect,
        state: GooglyEyesRenderState?,
        accentColor: NSColor,
        colorMode: CatColorMode,
        facing: StatusBarCharacterFacing
    ) {
        let scale = max(min(rect.width / 36, rect.height / 18), 0.1)
        let eyeDiameter: CGFloat = 13.8 * scale
        let pupilDiameter: CGFloat = 5.2 * scale
        let maximumPupilTravel: CGFloat = 3.4 * scale
        let eyeY = rect.midY - eyeDiameter / 2
        let centers = [
            CGPoint(x: rect.minX + rect.width * 0.32, y: rect.midY),
            CGPoint(x: rect.minX + rect.width * 0.68, y: rect.midY)
        ]

        for center in centers {
            let eyeRect = NSRect(
                x: center.x - eyeDiameter / 2,
                y: eyeY,
                width: eyeDiameter,
                height: eyeDiameter
            )
            let eyePath = NSBezierPath(ovalIn: eyeRect)
            NSColor.white.withAlphaComponent(0.96).setFill()
            eyePath.fill()
            accentColor.withAlphaComponent(0.38).setStroke()
            eyePath.lineWidth = 0.8 * scale
            eyePath.stroke()

            if state?.isBlinking == true {
                let blinkPath = NSBezierPath()
                blinkPath.move(to: CGPoint(x: eyeRect.minX + 1.8 * scale, y: center.y))
                blinkPath.curve(
                    to: CGPoint(x: eyeRect.maxX - 1.8 * scale, y: center.y),
                    controlPoint1: CGPoint(x: center.x - 2.2 * scale, y: center.y - 1.3 * scale),
                    controlPoint2: CGPoint(x: center.x + 2.2 * scale, y: center.y - 1.3 * scale)
                )
                accentColor.withAlphaComponent(0.82).setStroke()
                blinkPath.lineWidth = 1.6 * scale
                blinkPath.lineCapStyle = .round
                blinkPath.stroke()
                continue
            }

            let offset: CGSize
            if let state {
                let screenCenter = GooglyEyesTracker.screenCenter(
                    forLocalCenter: center,
                    statusItemFrame: state.statusItemFrame
                )
                offset = GooglyEyesTracker.pupilOffset(
                    from: screenCenter,
                    toward: state.mouseLocation,
                    maximumDistance: maximumPupilTravel
                )
            } else {
                offset = .zero
            }

            let pupilRect = NSRect(
                x: center.x + offset.width - pupilDiameter / 2,
                y: center.y + offset.height - pupilDiameter / 2,
                width: pupilDiameter,
                height: pupilDiameter
            )
            let pupilCenter = CGPoint(x: pupilRect.midX, y: pupilRect.midY)
            if colorMode == .heatVision {
                drawHeatVisionBeam(from: pupilCenter, gazeOffset: offset, in: rect, facing: facing, scale: scale)
            }

            accentColor.withAlphaComponent(0.88).setFill()
            NSBezierPath(ovalIn: pupilRect).fill()

            let catchlightRect = NSRect(
                x: pupilRect.minX + 1.2 * scale,
                y: pupilRect.maxY - 2.2 * scale,
                width: 1.2 * scale,
                height: 1.2 * scale
            )
            NSColor.white.withAlphaComponent(0.82).setFill()
            NSBezierPath(ovalIn: catchlightRect).fill()
        }
    }

    static func heatVisionBeamEnd(
        from start: CGPoint,
        gazeOffset: CGSize = .zero,
        in rect: NSRect,
        facing: StatusBarCharacterFacing,
        scale: CGFloat
    ) -> CGPoint {
        let travel = rect.width * 0.9 + 7 * scale
        let gazeDistance = hypot(gazeOffset.width, gazeOffset.height)
        if gazeDistance > 0.01 {
            return CGPoint(
                x: start.x + gazeOffset.width / gazeDistance * travel,
                y: start.y + gazeOffset.height / gazeDistance * travel
            )
        }

        let verticalDrift = (start.y - rect.midY) * 0.08
        switch facing {
        case .right:
            return CGPoint(x: start.x + travel, y: start.y + verticalDrift)
        case .left:
            return CGPoint(x: start.x - travel, y: start.y + verticalDrift)
        }
    }

    private static func drawHeatVisionBeam(
        from start: CGPoint,
        gazeOffset: CGSize,
        in rect: NSRect,
        facing: StatusBarCharacterFacing,
        scale: CGFloat
    ) {
        let end = heatVisionBeamEnd(from: start, gazeOffset: gazeOffset, in: rect, facing: facing, scale: scale)

        func strokeBeam(color: NSColor, lineWidth: CGFloat) {
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineCapStyle = .round
            path.lineWidth = lineWidth
            color.setStroke()
            path.stroke()
        }

        if let context = NSGraphicsContext.current {
            context.cgContext.saveGState()
            context.cgContext.setShadow(
                offset: .zero,
                blur: 3.6 * scale,
                color: NSColor.systemRed.withAlphaComponent(0.55).cgColor
            )
            strokeBeam(color: NSColor.systemRed.withAlphaComponent(0.32), lineWidth: 4.8 * scale)
            context.cgContext.restoreGState()
        }

        strokeBeam(color: NSColor.systemRed.withAlphaComponent(0.75), lineWidth: 2.4 * scale)
        strokeBeam(color: NSColor(calibratedRed: 1, green: 0.9, blue: 0.54, alpha: 0.9), lineWidth: 0.85 * scale)
    }

    private static func googlyEyesAccentColor(
        colorMode: CatColorMode,
        settings: StatusBarSettings,
        frameIndex: Int
    ) -> NSColor {
        if colorMode == .solid, settings.catColor == PersistedColor.white {
            return NSColor.black
        }
        return colorMode.color(at: Date().timeIntervalSince1970, frameIndex: frameIndex, baseColor: settings.catColor)
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
                    return NSImage(contentsOf: URL(fileURLWithPath: "\(resPath)/RunCat/\(runCatCharacter.id)/frame_\(frameIndex).png"))
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
        let character = characterAsset(settings: settings, customCharacterStore: customCharacterStore)
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

    static func shouldMirrorCharacter(settings: StatusBarSettings, frameIndex: Int) -> Bool {
        let baseMirror = settings.catFacing == .left
        let swingMirror = settings.catHeadSwing && frameIndex % 2 == 1
        return baseMirror != swingMirror
    }

    static func width(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore? = nil,
        smartContext: SmartStatusBarContext = .manual
    ) -> CGFloat {
        layout(
            snapshot: snapshot,
            settings: settings,
            customCharacterStore: customCharacterStore,
            smartContext: smartContext
        ).width
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

    private static func layout(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        customCharacterStore: CustomCharacterStore?,
        catFrameIndex: Int? = nil,
        smartContext: SmartStatusBarContext = .manual
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
        let displayMode = smartContext.trafficDisplayModeOverride ?? settings.trafficDisplayMode
        let lines: [String] = {
            if let overrideLine = smartContext.overrideLine {
                return [overrideLine]
            }
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
        let horizontalPadding: CGFloat = settings.showsBackground ? 8 : 2
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
        let automaticTextWidth = smartContext.overrideLine == nil ? max(measuredWidth, stableWidth) : measuredWidth
        let automaticWidth = ceil(automaticTextWidth + horizontalPadding * 2 + catExtraWidth)
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
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
