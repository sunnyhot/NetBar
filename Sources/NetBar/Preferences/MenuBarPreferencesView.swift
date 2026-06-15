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

                PreferenceSection(
                    title: appPreferences.text("预设", "Presets"),
                    systemImage: "wand.and.stars"
                ) {
                    Picker(
                        appPreferences.text("菜单栏预设", "Menu bar preset"),
                        selection: Binding<MenuBarPreset?>(
                            get: { MenuBarPreset.matching(settings: settings) },
                            set: { preset in preset?.apply(to: settings) }
                        )
                    ) {
                        Text(appPreferences.text("自定义", "Custom")).tag(Optional<MenuBarPreset>.none)
                        ForEach(MenuBarPreset.allCases) { preset in
                            Text(preset.title(language: appPreferences.resolvedLanguage)).tag(Optional(preset))
                        }
                    }
                    .pickerStyle(.menu)
                }

                PreferenceSection(
                    title: appPreferences.text("智能菜单栏", "Smart Menu Bar"),
                    systemImage: "bolt.badge.automatic"
                ) {
                    Toggle(
                        appPreferences.text("启用智能菜单栏模式", "Enable smart menu bar mode"),
                        isOn: intelligenceBinding(\.isSmartStatusBarModeEnabled)
                    )
                    Toggle(
                        appPreferences.text("异常状态标识", "Anomaly marker"),
                        isOn: intelligenceBinding(\.showsSmartAnomalyMarker)
                    )
                    Toggle(
                        appPreferences.text("Top 应用提示", "Top app hint"),
                        isOn: intelligenceBinding(\.showsSmartTopApplication)
                    )
                }

                CollapsiblePreferenceSection(
                    title: appPreferences.text("显示内容", "Display"),
                    systemImage: "textformat.size",
                    defaultExpanded: true
                ) {
                    MenuBarDisplaySectionContent(settings: settings, appPreferences: appPreferences)
                }

                CollapsiblePreferenceSection(
                    title: appPreferences.text("角色", "Character"),
                    systemImage: "pawprint",
                    defaultExpanded: true
                ) {
                    characterSection
                }

                CollapsiblePreferenceSection(
                    title: appPreferences.text("动画与轮换", "Animation & Rotation"),
                    systemImage: "hare",
                    defaultExpanded: false
                ) {
                    MenuBarAnimationSection(settings: settings, appPreferences: appPreferences)
                }

                CollapsiblePreferenceSection(
                    title: appPreferences.text("宽度与布局", "Width & Layout"),
                    systemImage: "rectangle.split.3x1",
                    defaultExpanded: false
                ) {
                    MenuBarLayoutSectionContent(settings: settings, appPreferences: appPreferences)
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

    private func intelligenceBinding<Value>(
        _ keyPath: WritableKeyPath<NetworkIntelligenceSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { appPreferences.networkIntelligenceSettings[keyPath: keyPath] },
            set: { newValue in
                var copy = appPreferences.networkIntelligenceSettings
                copy[keyPath: keyPath] = newValue
                appPreferences.networkIntelligenceSettings = copy
            }
        )
    }
}
