import SwiftUI

struct MenuBarLayoutSectionContent: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        Toggle(appPreferences.text("自动宽度", "Automatic width"), isOn: Binding(
            get: { settings.usesAutomaticWidth },
            set: { newValue in withAnimation(NetBarMotion.settle) { settings.usesAutomaticWidth = newValue } }
        ))

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

struct MenuBarLayoutSection: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.layout.title(language: appPreferences.resolvedLanguage)) {
            MenuBarLayoutSectionContent(settings: settings, appPreferences: appPreferences)
        }
    }
}
