import SwiftUI

struct MenuBarDisplaySectionContent: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { settings.textColor.swiftUIColor },
            set: { settings.textColor = PersistedColor(color: $0) }
        )
    }

    var body: some View {
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
    }
}
