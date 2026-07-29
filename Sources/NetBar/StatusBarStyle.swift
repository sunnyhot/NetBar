import AppKit
import Combine

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
