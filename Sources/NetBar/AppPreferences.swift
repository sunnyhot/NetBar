import AppKit
import ServiceManagement

enum ApplicationSortMode: String, CaseIterable, Identifiable {
    case activity
    case download
    case upload
    case total
    case name

    var id: String { rawValue }

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
    @Published var showsDockIcon: Bool { didSet { save() } }
    @Published var hidesSystemProcesses: Bool { didSet { save() } }
    @Published var applicationSort: ApplicationSortMode { didSet { save() } }
    @Published var language: AppLanguage { didSet { save() } }
    @Published var appearanceMode: AppAppearanceMode { didSet { save() } }
    @Published private(set) var hasCompletedOnboarding: Bool { didSet { save() } }
    @Published private(set) var launchesAtLogin: Bool
    @Published private(set) var loginItemErrorMessage: String?

    private let defaults: UserDefaults
    private let loginItemManager: LoginItemManaging

    init(
        defaults: UserDefaults = .standard,
        loginItemManager: LoginItemManaging = MainAppLoginItemManager()
    ) {
        self.defaults = defaults
        self.loginItemManager = loginItemManager
        showsDockIcon = defaults.object(forKey: Keys.showsDockIcon) as? Bool ?? Defaults.showsDockIcon
        hidesSystemProcesses = defaults.object(forKey: Keys.hidesSystemProcesses) as? Bool ?? Defaults.hidesSystemProcesses
        applicationSort = ApplicationSortMode(rawValue: defaults.string(forKey: Keys.applicationSort) ?? "") ?? Defaults.applicationSort
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? Defaults.language
        appearanceMode = AppAppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? Defaults.appearanceMode
        hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? Defaults.hasCompletedOnboarding
        launchesAtLogin = loginItemManager.refreshStatus()
    }

    var resolvedLanguage: AppLanguage {
        language.resolved
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
    }

    private func save() {
        defaults.set(showsDockIcon, forKey: Keys.showsDockIcon)
        defaults.set(hidesSystemProcesses, forKey: Keys.hidesSystemProcesses)
        defaults.set(applicationSort.rawValue, forKey: Keys.applicationSort)
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
    }

    private enum Defaults {
        static let showsDockIcon = true
        static let hidesSystemProcesses = true
        static let applicationSort = ApplicationSortMode.activity
        static let language = AppLanguage.system
        static let appearanceMode = AppAppearanceMode.system
        static let hasCompletedOnboarding = false
    }

    private enum Keys {
        static let showsDockIcon = "app.showsDockIcon"
        static let hidesSystemProcesses = "app.hidesSystemProcesses"
        static let applicationSort = "app.applicationSort"
        static let language = "app.language"
        static let appearanceMode = "app.appearanceMode"
        static let hasCompletedOnboarding = "app.hasCompletedOnboarding"
    }
}
