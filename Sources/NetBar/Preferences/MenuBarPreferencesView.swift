import SwiftUI

struct MenuBarPreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore

    private var characterSection: MenuBarCharacterSection {
        MenuBarCharacterSection(
            settings: settings,
            appPreferences: appPreferences,
            customCharacterStore: customCharacterStore
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

                MenuBarDisplaySection(settings: settings, appPreferences: appPreferences)
                characterSection
                MenuBarAnimationSection(settings: settings, appPreferences: appPreferences)
                MenuBarLayoutSection(settings: settings, appPreferences: appPreferences)

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
