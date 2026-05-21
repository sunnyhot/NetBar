import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let customCharacterStore: CustomCharacterStore
    private let updater: AppUpdater
    private var window: NSWindow?

    init(
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        customCharacterStore: CustomCharacterStore,
        updater: AppUpdater
    ) {
        self.settings = settings
        self.appPreferences = appPreferences
        self.customCharacterStore = customCharacterStore
        self.updater = updater
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
                updater: updater
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
    @ObservedObject var updater: AppUpdater
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
                    customCharacterStore: customCharacterStore
                )
                    .tabItem {
                        Label(appPreferences.text("菜单栏", "Menu Bar"), systemImage: "menubar.rectangle")
                    }
                    .tag(1)

                AboutPreferencesView(appPreferences: appPreferences, updater: updater)
                    .tabItem {
                        Label(appPreferences.text("关于", "About"), systemImage: "info.circle")
                    }
                    .tag(2)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .netBarPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }
}
