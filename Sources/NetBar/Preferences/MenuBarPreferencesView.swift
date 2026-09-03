import SwiftUI

struct MenuBarPreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    @ObservedObject var historyStore: NetworkHistoryStore

    private var characterSection: MenuBarCharacterSection {
        MenuBarCharacterSection(
            settings: settings,
            appPreferences: appPreferences,
            customCharacterStore: customCharacterStore,
            historyStore: historyStore
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AnimatedPreviewSection(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore,
                    selectedCharacterAsset: characterSection.selectedCharacterAsset()
                )

                CollapsiblePreferenceSection(
                    title: appPreferences.text("显示与布局", "Display & Layout"),
                    systemImage: "textformat.size",
                    defaultExpanded: true
                ) {
                    MenuBarDisplaySectionContent(settings: settings, appPreferences: appPreferences)

                    Divider()

                    MenuBarLayoutSectionContent(settings: settings, appPreferences: appPreferences)
                }

                CollapsiblePreferenceSection(
                    title: appPreferences.text("角色与动画", "Character & Animation"),
                    systemImage: "pawprint",
                    defaultExpanded: true
                ) {
                    characterSection
                }

                HStack {
                    Spacer()
                    Button(appPreferences.text("恢复菜单栏默认值", "Restore Menu Bar Defaults")) {
                        settings.reset()
                    }
                }
            }
            .padding(.trailing, 2)
        }
    }
}
