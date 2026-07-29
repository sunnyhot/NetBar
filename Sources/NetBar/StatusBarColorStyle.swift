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
    case crystalPrism    // Crystal chroma facets inspired by magical pets
    case starlightShift  // Starlight color-shift with bright accents
    case phantomChroma   // Iridescent randomized chroma flow
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
        case .crystalPrism: return zh ? "水晶炫彩" : "Crystal Prism"
        case .starlightShift: return zh ? "星辉流彩" : "Starlight Shift"
        case .phantomChroma: return zh ? "幻影炫彩" : "Phantom Chroma"
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

        case .crystalPrism:
            let t = CGFloat(time.truncatingRemainder(dividingBy: 3.6) / 3.6)
            let hue = (0.58 + t * 0.32 + CGFloat(frameIndex % 4) * 0.035).truncatingRemainder(dividingBy: 1)
            let glint = 0.5 + 0.5 * sin(t * .pi * 8)
            return NSColor(
                calibratedHue: hue,
                saturation: 0.82 + 0.16 * glint,
                brightness: 0.88 + 0.12 * glint,
                alpha: 1.0
            )

        case .starlightShift:
            let t = CGFloat(time.truncatingRemainder(dividingBy: 4.2) / 4.2)
            let hue = (0.64 + t * 0.48 + CGFloat(frameIndex % 3) * 0.05).truncatingRemainder(dividingBy: 1)
            let pulse = 0.5 + 0.5 * cos(t * .pi * 10)
            return NSColor(
                calibratedHue: hue,
                saturation: 0.68 + 0.22 * pulse,
                brightness: 0.9 + 0.1 * pulse,
                alpha: 1.0
            )

        case .phantomChroma:
            let bucket = Int(time * 3)
            let mixed = UInt32(truncatingIfNeeded: bucket &* 2246822519 &+ frameIndex &* 3266489917)
            let seed = mixed ^ (mixed &>> 13)
            let hue = CGFloat(Double(seed % 360) / 360.0)
            let sat = CGFloat(0.74 + 0.24 * Double((seed >> 8) % 100) / 100.0)
            let bright = CGFloat(0.82 + 0.18 * Double((seed >> 16) % 100) / 100.0)
            return NSColor(calibratedHue: hue, saturation: sat.clamped(to: 0...1), brightness: bright.clamped(to: 0...1), alpha: 1.0)

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

        case .crystalPrism:
            let drift = CGFloat((time.truncatingRemainder(dividingBy: 3.6)) / 3.6) * 0.28
                + CGFloat(frameIndex % 4) * 0.018
            let stops: [(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, position: CGFloat)] = [
                (0.58, 0.88, 1.00, 0.0),
                (0.72, 0.82, 0.96, 0.14),
                (0.86, 0.92, 1.00, 0.32),
                (0.50, 0.78, 0.98, 0.52),
                (0.13, 0.90, 1.00, 0.73),
                (0.94, 0.84, 0.98, 1.0),
            ]
            return stops.map { stop in
                (
                    color: NSColor(
                        calibratedHue: (stop.hue + drift).truncatingRemainder(dividingBy: 1),
                        saturation: stop.saturation,
                        brightness: stop.brightness,
                        alpha: 1.0
                    ),
                    position: stop.position
                )
            }

        case .starlightShift:
            let drift = CGFloat((time.truncatingRemainder(dividingBy: 4.2)) / 4.2) * 0.34
            let shimmer = CGFloat(0.5 + 0.5 * sin(time * 5.4 + Double(frameIndex) * 0.7))
            return [
                (color: NSColor(calibratedHue: (0.62 + drift).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.95, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: (0.72 + drift).truncatingRemainder(dividingBy: 1), saturation: 0.92, brightness: 0.9 + 0.1 * shimmer, alpha: 1.0), position: 0.22),
                (color: NSColor(calibratedHue: (0.88 + drift).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 1.0, alpha: 1.0), position: 0.45),
                (color: NSColor(calibratedHue: (0.10 + drift).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 1.0, alpha: 1.0), position: 0.68),
                (color: NSColor(calibratedHue: (0.55 + drift).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.96, alpha: 1.0), position: 1.0),
            ]

        case .phantomChroma:
            let timeBucket = Int(time * 2.5)
            let seed = UInt32(truncatingIfNeeded: timeBucket &* 374761393 &+ frameIndex &* 668265263)
            let hue1 = CGFloat(Double((seed &+ 37) % 360) / 360.0)
            let hue2 = CGFloat(Double(((seed >> 7) &+ 149) % 360) / 360.0)
            let hue3 = CGFloat(Double(((seed >> 13) &+ 251) % 360) / 360.0)
            let hue4 = (hue1 + 0.62).truncatingRemainder(dividingBy: 1)
            return [
                (color: NSColor(calibratedHue: hue1, saturation: 0.86, brightness: 0.98, alpha: 1.0), position: 0.0),
                (color: NSColor(calibratedHue: hue2, saturation: 0.72, brightness: 1.00, alpha: 1.0), position: 0.24),
                (color: NSColor(calibratedHue: hue3, saturation: 0.88, brightness: 0.92, alpha: 1.0), position: 0.48),
                (color: NSColor(calibratedHue: hue4, saturation: 0.78, brightness: 1.0, alpha: 1.0), position: 0.76),
                (color: NSColor(calibratedHue: hue2, saturation: 0.90, brightness: 0.94, alpha: 1.0), position: 1.0),
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
        case .galaxy, .neon, .aurora, .cyber, .candy, .arcanePrism, .heatVision, .crystalPrism, .starlightShift, .phantomChroma, .randomPop, .rainbow:
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
