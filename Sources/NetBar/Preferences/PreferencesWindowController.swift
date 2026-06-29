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
    @State private var selectedTab: PreferencesTab = .general

    var body: some View {
        VStack(spacing: 16) {
            PreferencesHeroHeader(appPreferences: appPreferences, updater: updater)

            PreferencesTabBar(selectedTab: $selectedTab, appPreferences: appPreferences)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .livingSignalPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .general:
            GeneralPreferencesView(appPreferences: appPreferences)
        case .menuBar:
            MenuBarPreferencesView(
                settings: settings,
                appPreferences: appPreferences,
                customCharacterStore: customCharacterStore,
                historyStore: historyStore
            )
        case .intelligence:
            IntelligencePreferencesView(
                appPreferences: appPreferences,
                notificationController: notificationController,
                petController: petController,
                clearHistory: clearNetworkHistory
            )
        case .about:
            AboutPreferencesView(
                appPreferences: appPreferences,
                updater: updater,
                diagnosticsSnapshot: diagnosticsSnapshot()
            )
        }
    }
}

private enum PreferencesTab: Int, CaseIterable, Identifiable {
    case general
    case menuBar
    case intelligence
    case about

    var id: Int { rawValue }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .menuBar:
            return "menubar.rectangle"
        case .intelligence:
            return "sparkles"
        case .about:
            return "info.circle"
        }
    }

    @MainActor
    func title(appPreferences: AppPreferences) -> String {
        switch self {
        case .general:
            return appPreferences.text("通用", "General")
        case .menuBar:
            return appPreferences.text("菜单栏", "Menu Bar")
        case .intelligence:
            return appPreferences.text("智能", "Intelligence")
        case .about:
            return appPreferences.text("关于", "About")
        }
    }
}

private struct PreferencesTabBar: View {
    @Binding var selectedTab: PreferencesTab
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PreferencesTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title(appPreferences: appPreferences), systemImage: tab.systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(selectedTab == tab ? LivingSignalTone.active.color : Color.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(minWidth: 92)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selectedTab == tab ? LivingSignalTone.active.softColor : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(
                                    selectedTab == tab ? LivingSignalTone.active.color.opacity(0.18) : Color.clear,
                                    lineWidth: 0.6
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .livingSignalPanel(tone: .neutral, padding: 4)
    }
}
