import SwiftUI

struct MenuBarPreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore

    private func selectedCharacterAsset() -> CharacterAsset {
        CharacterAsset.resolve(id: settings.catCharacter, customCharacters: customCharacterStore.characters)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AnimatedPreviewSection(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore,
                    selectedCharacterAsset: selectedCharacterAsset()
                )

                displayPreferences
                MenuBarCharacterSection(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore
                )
                MenuBarAnimationSection(
                    settings: settings,
                    appPreferences: appPreferences
                )
                layoutPreferences

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

    private var displayPreferences: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.display.title(language: appPreferences.resolvedLanguage)) {
            MenuBarSubsectionHeader(
                systemImage: "textformat.size",
                title: appPreferences.text("文字样式", "Text Style")
            )

            SliderPreference(
                title: appPreferences.text("字号", "Font size"),
                value: $settings.fontSize,
                range: 8...18,
                displayValue: "\(Int(settings.fontSize.rounded()))"
            )

            HStack {
                Toggle(appPreferences.text("系统文字颜色", "System text color"), isOn: $settings.usesSystemTextColor)
                Toggle(appPreferences.text("加粗", "Bold"), isOn: $settings.isBold)
                Toggle(appPreferences.text("显示箭头", "Show arrows"), isOn: $settings.showsArrows)
            }

            if !settings.usesSystemTextColor {
                ColorPicker(appPreferences.text("文字颜色", "Text color"), selection: textColorBinding, supportsOpacity: true)
            }

            Divider()

            MenuBarSubsectionHeader(
                systemImage: "rectangle.inset.filled",
                title: appPreferences.text("背景", "Background")
            )

            Toggle(appPreferences.text("透明背景", "Transparent background"), isOn: transparentBackgroundBinding)

            if settings.showsBackground {
                ColorPicker(appPreferences.text("背景颜色", "Background color"), selection: backgroundColorBinding, supportsOpacity: true)

                SliderPreference(
                    title: appPreferences.text("不透明度", "Opacity"),
                    value: $settings.backgroundOpacity,
                    range: 0...1,
                    displayValue: "\(Int((settings.backgroundOpacity * 100).rounded()))%"
                )

                Text(appPreferences.text(
                    "启用背景时会使用 Retina bitmap 渲染；透明背景会使用原生菜单栏文字渲染，性能和清晰度更稳。",
                    "Backgrounds use Retina bitmap rendering. Transparent mode uses native menu bar text for steadier performance and clarity."
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var layoutPreferences: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.layout.title(language: appPreferences.resolvedLanguage)) {
            Toggle(appPreferences.text("自动宽度", "Automatic width"), isOn: $settings.usesAutomaticWidth)

            if !settings.usesAutomaticWidth {
                SliderPreference(
                    title: appPreferences.text("手动宽度", "Manual width"),
                    value: $settings.itemWidth,
                    range: 36...220,
                    displayValue: "\(Int(settings.itemWidth.rounded()))"
                )
            }

            SliderPreference(
                title: appPreferences.text("行距", "Line spacing"),
                value: $settings.lineSpacing,
                range: -5...8,
                displayValue: String(format: "%.1f", settings.lineSpacing)
            )

            Picker(appPreferences.text("排列", "Order"), selection: $settings.order) {
                ForEach(StatusBarOrder.allCases) { order in
                    Text(order.title(language: appPreferences.resolvedLanguage)).tag(order)
                }
            }
            .pickerStyle(.segmented)

            Picker(appPreferences.text("对齐", "Alignment"), selection: $settings.alignment) {
                ForEach(StatusBarAlignment.allCases) { alignment in
                    Text(alignment.title(language: appPreferences.resolvedLanguage)).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { settings.textColor.swiftUIColor },
            set: { settings.textColor = PersistedColor(color: $0) }
        )
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { settings.backgroundColor.swiftUIColor },
            set: { settings.backgroundColor = PersistedColor(color: $0) }
        )
    }

    private var transparentBackgroundBinding: Binding<Bool> {
        Binding(
            get: { !settings.showsBackground },
            set: { isTransparent in
                settings.showsBackground = !isTransparent
                if isTransparent {
                    settings.backgroundOpacity = 0
                } else if settings.backgroundOpacity == 0 {
                    settings.backgroundOpacity = 0.8
                }
            }
        )
    }
}
