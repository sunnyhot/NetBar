import SwiftUI

struct MenuBarAnimationSection: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    private var rotationPoolSet: Set<String> {
        Set(settings.catRotationPool.split(separator: ",").map(String.init))
    }

    private func toggleRotationPoolCharacter(_ characterID: String) {
        var ids = settings.catRotationPool.split(separator: ",").map(String.init)
        if ids.contains(characterID) {
            ids.removeAll { $0 == characterID }
        } else {
            ids.append(characterID)
        }
        settings.catRotationPool = ids.joined(separator: ",")
    }

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

                let pool = rotationPoolSet
                VStack(alignment: .leading, spacing: 6) {
                    MenuBarSubsectionHeader(
                        systemImage: "shuffle",
                        title: appPreferences.text("轮换角色池（空=全部）", "Rotation Pool (empty=all)")
                    )

                    ForEach(RunCatCharacter.Category.allCases, id: \.rawValue) { category in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            let charsInCategory = RunCatCharacter.allCharacters.filter { $0.category == category }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86))], spacing: 3) {
                                ForEach(charsInCategory) { character in
                                    Button(action: {
                                        toggleRotationPoolCharacter(character.id)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: pool.contains(character.id) ? "checkmark.square" : "square")
                                                .font(.system(size: 9))
                                            Text(character.displayName)
                                                .font(.system(size: 11))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            Text(appPreferences.text(
                "启用角色后可配置动画速度、朝向与轮换。",
                "Enable the character to configure speed, facing, and rotation."
            ))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
    }
}
