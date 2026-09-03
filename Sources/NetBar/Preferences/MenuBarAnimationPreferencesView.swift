import SwiftUI

struct MenuBarAnimationSection: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        if settings.showsCat {
            SliderPreference(
                title: appPreferences.text("动画速度", "Animation Speed"),
                value: $settings.catSpeedMultiplier,
                range: 0.25...4.0,
                displayValue: String(format: "%.1fx", settings.catSpeedMultiplier)
            )

            Picker(
                appPreferences.text("速度关联", "Speed Source"),
                selection: $settings.catAnimationSpeedSource
            ) {
                ForEach(AnimationSpeedSource.allCases) { source in
                    Text(source.title(language: appPreferences.resolvedLanguage)).tag(source.rawValue)
                }
            }

            Divider()

            Toggle(appPreferences.text("摇头效果", "Head Swing"), isOn: $settings.catHeadSwing)

            Toggle(appPreferences.text("角色轮换", "Character Rotation"), isOn: $settings.catRotationEnabled)

            if settings.catRotationEnabled {
                SliderPreference(
                    title: appPreferences.text("轮换间隔", "Rotation Interval"),
                    value: $settings.catRotationIntervalMinutes,
                    range: 1...60,
                    displayValue: String(format: "%.0f分钟", settings.catRotationIntervalMinutes)
                )
            }
        } else {
            Text(appPreferences.text(
                "启用角色后可配置动画速度与轮换。",
                "Enable the character to configure speed and rotation."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
    }
}
