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
        VStack(spacing: 0) {
            PreferencesHeroHeader(appPreferences: appPreferences, updater: updater)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            TabView(selection: $selectedTab) {
                GeneralPreferencesView(appPreferences: appPreferences)
                    .tag(0)
                    .tabItem {
                        Label(appPreferences.text("通用", "General"), systemImage: "gearshape")
                    }

                MenuBarPreferencesView(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore
                )
                    .tag(1)
                    .tabItem {
                        Label(appPreferences.text("菜单栏", "Menu Bar"), systemImage: "menubar.rectangle")
                    }

                AboutPreferencesView(appPreferences: appPreferences, updater: updater)
                    .tag(2)
                    .tabItem {
                        Label(appPreferences.text("关于", "About"), systemImage: "info.circle")
                    }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            preferencesFooter
        }
        .frame(minWidth: 620, minHeight: 520)
        .netBarPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }

    private var preferencesFooter: some View {
        HStack {
            Text("NetBar v\(updater.currentVersionText)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)

            Spacer()

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/sunnyhot/NetBar")!) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 9))
                        Text("GitHub")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "https://github.com/sunnyhot/NetBar/issues")!) {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 9))
                        Text(appPreferences.text("反馈", "Feedback"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
