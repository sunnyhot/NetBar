import AppKit
import SwiftUI
import ServiceManagement

enum ApplicationSortMode: String, CaseIterable, Identifiable {
    case activity
    case download
    case upload
    case total
    case memory
    case cpu
    case name

    var id: String { rawValue }

    static let displayModes: [ApplicationSortMode] = [.activity, .memory, .cpu]

    var displayModeFallback: ApplicationSortMode {
        Self.displayModes.contains(self) ? self : .activity
    }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .activity:
            return language.text("实时流量", "Live traffic")
        case .download:
            return language.text("下载速度", "Download")
        case .upload:
            return language.text("上传速度", "Upload")
        case .total:
            return language.text("累计流量", "Total traffic")
        case .memory:
            return language.text("内存占用", "Memory")
        case .cpu:
            return language.text("CPU 占用", "CPU")
        case .name:
            return language.text("应用名称", "App name")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .system:
            return language.text("跟随系统", "System")
        case .simplifiedChinese:
            return language.text("简体中文", "Simplified Chinese")
        case .english:
            return "English"
        }
    }

    var resolved: AppLanguage {
        switch self {
        case .system:
            let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferredLanguage.hasPrefix("zh") ? .simplifiedChinese : .english
        case .simplifiedChinese, .english:
            return self
        }
    }

    func text(_ simplifiedChinese: String, _ english: String) -> String {
        resolved == .english ? english : simplifiedChinese
    }
}

enum PopoverPosition: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .left:
            return language.text("左侧", "Left")
        case .right:
            return language.text("右侧", "Right")
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .system:
            return language.text("跟随系统", "System")
        case .light:
            return language.text("浅色", "Light")
        case .dark:
            return language.text("暗黑", "Dark")
        }
    }

    var nsAppearanceName: NSAppearance.Name? {
        switch self {
        case .system:
            return nil
        case .light:
            return .aqua
        case .dark:
            return .darkAqua
        }
    }

    var nsAppearance: NSAppearance? {
        nsAppearanceName.flatMap { NSAppearance(named: $0) }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// MARK: - Dock Icon Visibility

/// Describes whether the app shows a Dock icon or runs as a menu-bar-only app.
///
/// Use this type instead of manually writing `showsDockIcon ? .regular : .accessory`
/// or checking `!showsDockIcon` — the semantic name makes intent explicit at every call site.
enum DockIconVisibility: String, CaseIterable, Identifiable {
    /// App appears in both the Dock and the menu bar.
    case visible
    /// App runs as a menu-bar-only app (no Dock icon, activation policy = `.accessory`).
    case menuBarOnly

    var id: String { rawValue }

    init(showsDockIcon: Bool) {
        self = showsDockIcon ? .visible : .menuBarOnly
    }

    /// Whether the Dock icon is currently visible.
    var showsDockIcon: Bool {
        self == .visible
    }

    /// Alias for Bool representation, useful for round-trip tests.
    var boolValue: Bool { showsDockIcon }

    /// Alias for clarity in some call sites.
    var isDockVisible: Bool { self == .visible }

    /// The corresponding `NSApplication.ActivationPolicy` for this visibility mode.
    var activationPolicy: NSApplication.ActivationPolicy {
        switch self {
        case .visible:    return .regular
        case .menuBarOnly: return .accessory
        }
    }

    var title: String {
        title(language: .simplifiedChinese)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .visible:
            return language.text("显示 Dock 图标", "Show Dock icon")
        case .menuBarOnly:
            return language.text("仅菜单栏", "Menu bar only")
        }
    }
}

// MARK: - Animation Speed Source

/// Determines what system metric drives the RunCat character animation speed.
/// Default is `.networkSpeed` to preserve backward compatibility.
enum AnimationSpeedSource: String, CaseIterable, Identifiable {
    case networkSpeed
    case memoryUsage
    case cpuUsage
    case thermalState
    case autoComposite

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .networkSpeed:
            return language.text("网速", "Network Speed")
        case .memoryUsage:
            return language.text("内存占用", "Memory Usage")
        case .cpuUsage:
            return language.text("CPU 使用率", "CPU Usage")
        case .thermalState:
            return language.text("热状态", "Thermal State")
        case .autoComposite:
            return language.text("自动综合", "Auto Composite")
        }
    }
}

protocol LoginItemManaging: AnyObject {
    func refreshStatus() -> Bool
    func setEnabled(_ isEnabled: Bool) throws
}

final class MainAppLoginItemManager: LoginItemManaging {
    func refreshStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    /// Backing Bool storage — `true` means Dock icon visible, `false` means menu-bar-only.
    /// Prefer using ``dockIconVisibility`` / ``setDockIconVisibility(_:)`` for clearer semantics.
    @Published var showsDockIcon: Bool {
        willSet { pendingShowsDockIcon = newValue }
        didSet {
            save()
            pendingShowsDockIcon = nil
        }
    }
    @Published var hidesSystemProcesses: Bool { didSet { save() } }
    @Published var applicationSort: ApplicationSortMode { didSet { save() } }
    @Published var language: AppLanguage { didSet { save() } }
    @Published var appearanceMode: AppAppearanceMode { didSet { save() } }
    @Published var popoverPosition: PopoverPosition { didSet { save() } }
    @Published private(set) var hasCompletedOnboarding: Bool { didSet { save() } }
    @Published var networkIntelligenceSettings: NetworkIntelligenceSettings { didSet { save() } }
    @Published private(set) var launchesAtLogin: Bool
    @Published private(set) var loginItemErrorMessage: String?

    private let defaults: UserDefaults
    private let loginItemManager: LoginItemManaging
    private var pendingShowsDockIcon: Bool?

    init(
        defaults: UserDefaults = .standard,
        loginItemManager: LoginItemManaging = MainAppLoginItemManager()
    ) {
        self.defaults = defaults
        self.loginItemManager = loginItemManager
        showsDockIcon = defaults.object(forKey: Keys.showsDockIcon) as? Bool ?? Defaults.showsDockIcon
        hidesSystemProcesses = defaults.object(forKey: Keys.hidesSystemProcesses) as? Bool ?? Defaults.hidesSystemProcesses
        applicationSort = (ApplicationSortMode(rawValue: defaults.string(forKey: Keys.applicationSort) ?? "") ?? Defaults.applicationSort).displayModeFallback
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? Defaults.language
        appearanceMode = AppAppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? Defaults.appearanceMode
        popoverPosition = PopoverPosition(rawValue: defaults.string(forKey: Keys.popoverPosition) ?? "") ?? Defaults.popoverPosition
        hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? Defaults.hasCompletedOnboarding
        if let data = defaults.data(forKey: Keys.networkIntelligenceSettings),
           let decoded = try? JSONDecoder().decode(NetworkIntelligenceSettings.self, from: data) {
            networkIntelligenceSettings = decoded
        } else {
            networkIntelligenceSettings = Defaults.networkIntelligenceSettings
        }
        launchesAtLogin = loginItemManager.refreshStatus()
    }

    var resolvedLanguage: AppLanguage {
        language.resolved
    }

    // MARK: - Dock Icon Visibility

    /// The current Dock visibility mode, derived from the backing `showsDockIcon` Bool.
    var dockIconVisibility: DockIconVisibility {
        DockIconVisibility(showsDockIcon: effectiveShowsDockIcon)
    }

    /// Sets the Dock visibility mode. Centralises the mapping so call sites
    /// never need to think about the Bool ↔ enum direction.
    func setDockIconVisibility(_ visibility: DockIconVisibility) {
        showsDockIcon = visibility.showsDockIcon
    }

    /// The AppKit activation policy that matches the current Dock visibility setting.
    var activationPolicy: NSApplication.ActivationPolicy {
        dockIconVisibility.activationPolicy
    }

    /// Whether clicking the Dock icon should reopen/show the traffic window.
    /// Only meaningful when Dock icon is visible; in menu-bar-only mode the Dock
    /// tile is absent so the reopen delegate is never called.
    var shouldHandleDockReopen: Bool {
        dockIconVisibility.isDockVisible
    }

    private var effectiveShowsDockIcon: Bool {
        pendingShowsDockIcon ?? showsDockIcon
    }

    func text(_ simplifiedChinese: String, _ english: String) -> String {
        resolvedLanguage.text(simplifiedChinese, english)
    }

    func refreshLoginItemStatus() {
        launchesAtLogin = loginItemManager.refreshStatus()
    }

    func setLaunchesAtLogin(_ isEnabled: Bool) async {
        do {
            try loginItemManager.setEnabled(isEnabled)
            launchesAtLogin = loginItemManager.refreshStatus()
            loginItemErrorMessage = nil
        } catch {
            launchesAtLogin = loginItemManager.refreshStatus()
            loginItemErrorMessage = error.localizedDescription
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetAppPreferences() {
        showsDockIcon = Defaults.showsDockIcon
        hidesSystemProcesses = Defaults.hidesSystemProcesses
        applicationSort = Defaults.applicationSort
        language = Defaults.language
        appearanceMode = Defaults.appearanceMode
        popoverPosition = Defaults.popoverPosition
        networkIntelligenceSettings = Defaults.networkIntelligenceSettings
    }

    private func save() {
        defaults.set(showsDockIcon, forKey: Keys.showsDockIcon)
        defaults.set(hidesSystemProcesses, forKey: Keys.hidesSystemProcesses)
        defaults.set(applicationSort.rawValue, forKey: Keys.applicationSort)
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
        defaults.set(popoverPosition.rawValue, forKey: Keys.popoverPosition)
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        if let data = try? JSONEncoder().encode(networkIntelligenceSettings) {
            defaults.set(data, forKey: Keys.networkIntelligenceSettings)
        }
    }

    private enum Defaults {
        static let showsDockIcon = true
        static let hidesSystemProcesses = true
        static let applicationSort = ApplicationSortMode.activity
        static let language = AppLanguage.system
        static let appearanceMode = AppAppearanceMode.system
        static let popoverPosition = PopoverPosition.right
        static let hasCompletedOnboarding = false
        static let networkIntelligenceSettings = NetworkIntelligenceSettings.default
    }

    private enum Keys {
        static let showsDockIcon = "app.showsDockIcon"
        static let hidesSystemProcesses = "app.hidesSystemProcesses"
        static let applicationSort = "app.applicationSort"
        static let language = "app.language"
        static let appearanceMode = "app.appearanceMode"
        static let popoverPosition = "app.popoverPosition"
        static let hasCompletedOnboarding = "app.hasCompletedOnboarding"
        static let networkIntelligenceSettings = "app.networkIntelligenceSettings"
    }
}
