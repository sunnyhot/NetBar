import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let customCharacterStore: CustomCharacterStore
    private let historyStore: NetworkHistoryStore
    private let updater: AppUpdater
    private let notificationController: NetworkNotificationController
    private let petController: PetController
    private let diagnosticsSnapshot: () -> DiagnosticsSnapshot
    private let clearNetworkHistory: () -> Void
    private var window: NSWindow?

    init(
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        customCharacterStore: CustomCharacterStore,
        historyStore: NetworkHistoryStore,
        updater: AppUpdater,
        notificationController: NetworkNotificationController,
        petController: PetController,
        diagnosticsSnapshot: @escaping () -> DiagnosticsSnapshot,
        clearNetworkHistory: @escaping () -> Void
    ) {
        self.settings = settings
        self.appPreferences = appPreferences
        self.customCharacterStore = customCharacterStore
        self.historyStore = historyStore
        self.updater = updater
        self.notificationController = notificationController
        self.petController = petController
        self.diagnosticsSnapshot = diagnosticsSnapshot
        self.clearNetworkHistory = clearNetworkHistory
    }

    func show() {
        let preferencesWindow = makeWindowIfNeeded()
        preferencesWindow.title = appPreferences.text("NetBar 偏好设置", "NetBar Preferences")
        preferencesWindow.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
        preferencesWindow.makeKeyAndOrderFront(nil)
    }

    private func makeWindowIfNeeded() -> NSWindow {
        if let window {
            return window
        }

        let preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow.title = appPreferences.text("NetBar 偏好设置", "NetBar Preferences")
        preferencesWindow.minSize = NSSize(width: 620, height: 520)
        preferencesWindow.isReleasedWhenClosed = false
        preferencesWindow.delegate = self
        preferencesWindow.contentViewController = NSHostingController(
            rootView: PreferencesView(
                settings: settings,
                appPreferences: appPreferences,
                customCharacterStore: customCharacterStore,
                historyStore: historyStore,
                updater: updater,
                notificationController: notificationController,
                petController: petController,
                diagnosticsSnapshot: diagnosticsSnapshot,
                clearNetworkHistory: clearNetworkHistory
            )
        )
        preferencesWindow.collectionBehavior = [.moveToActiveSpace]

        window = preferencesWindow
        return preferencesWindow
    }
}

private struct PreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    @ObservedObject var historyStore: NetworkHistoryStore
    @ObservedObject var updater: AppUpdater
    @ObservedObject var notificationController: NetworkNotificationController
    @ObservedObject var petController: PetController
    let diagnosticsSnapshot: () -> DiagnosticsSnapshot
    let clearNetworkHistory: () -> Void
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 16) {
            PreferencesHeroHeader(appPreferences: appPreferences, updater: updater)

            TabView(selection: $selectedTab) {
                GeneralPreferencesView(appPreferences: appPreferences)
                    .tabItem {
                        Label(appPreferences.text("通用", "General"), systemImage: "gearshape")
                    }
                    .tag(0)

                MenuBarPreferencesView(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore,
                    historyStore: historyStore
                )
                    .tabItem {
                        Label(appPreferences.text("菜单栏", "Menu Bar"), systemImage: "menubar.rectangle")
                    }
                    .tag(1)

                IntelligencePreferencesView(
                    appPreferences: appPreferences,
                    notificationController: notificationController,
                    petController: petController,
                    clearHistory: clearNetworkHistory
                )
                    .tabItem {
                        Label(appPreferences.text("智能", "Intelligence"), systemImage: "sparkles")
                    }
                    .tag(2)

                AboutPreferencesView(
                    appPreferences: appPreferences,
                    updater: updater,
                    diagnosticsSnapshot: diagnosticsSnapshot()
                )
                    .tabItem {
                        Label(appPreferences.text("关于", "About"), systemImage: "info.circle")
                    }
                    .tag(3)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .livingSignalPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }
}
