import Foundation

enum MenuBarPreset: String, CaseIterable, Identifiable {
    case minimal
    case upDown
    case totalTraffic
    case appFocus
    case petMode

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .minimal:
            return language.text("极简", "Minimal")
        case .upDown:
            return language.text("上下行", "Up/Down")
        case .totalTraffic:
            return language.text("总流量", "Total Traffic")
        case .appFocus:
            return language.text("应用关注", "App Focus")
        case .petMode:
            return language.text("宠物模式", "Pet Mode")
        }
    }

    @MainActor
    func apply(to settings: StatusBarSettings) {
        settings.usesAutomaticWidth = true
        settings.showsBackground = false
        settings.catAnimationSpeedSource = AnimationSpeedSource.networkSpeed.rawValue

        switch self {
        case .minimal:
            settings.trafficDisplayMode = .downloadOnly
            settings.showsArrows = false
            settings.catScale = 0.8
        case .upDown:
            settings.trafficDisplayMode = .upDown
            settings.showsArrows = true
            settings.catScale = 1.0
        case .totalTraffic:
            settings.trafficDisplayMode = .total
            settings.showsArrows = false
            settings.catScale = 0.9
        case .appFocus:
            settings.trafficDisplayMode = .upDown
            settings.showsArrows = true
            settings.catScale = 0.75
        case .petMode:
            settings.trafficDisplayMode = .upDown
            settings.showsArrows = true
            settings.catScale = 1.2
            settings.catAnimationSpeedSource = AnimationSpeedSource.autoComposite.rawValue
        }
    }

    @MainActor
    static func matching(settings: StatusBarSettings) -> MenuBarPreset? {
        allCases.first { preset in
            let suiteName = "MenuBarPreset.match.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let copy = StatusBarSettings(defaults: defaults)
            preset.apply(to: copy)

            return copy.trafficDisplayMode == settings.trafficDisplayMode
                && copy.showsArrows == settings.showsArrows
                && copy.showsBackground == settings.showsBackground
                && copy.usesAutomaticWidth == settings.usesAutomaticWidth
                && abs(copy.fontSize - settings.fontSize) < 0.001
                && abs(copy.catScale - settings.catScale) < 0.001
                && copy.catAnimationSpeedSource == settings.catAnimationSpeedSource
        }
    }
}
