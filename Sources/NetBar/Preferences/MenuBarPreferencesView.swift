import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarPreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore

    private func applyCatColor(_ color: Color) {
        let newColor = PersistedColor(color: color)
        settings.catColor = newColor
        if newColor != PersistedColor.white && settings.usesSystemTextColor {
            settings.usesSystemTextColor = false
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

    private var selectedCustomCharacter: CustomCharacter? {
        customCharacterStore.character(id: settings.catCharacter)
    }

    private func selectedCharacterAsset() -> CharacterAsset {
        CharacterAsset.resolve(id: settings.catCharacter, customCharacters: customCharacterStore.characters)
    }

    private func importCustomCharacter() {
        let panel = NSOpenPanel()
        panel.title = appPreferences.text("导入自定义角色", "Import Custom Character")
        panel.prompt = appPreferences.text("导入", "Import")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp"]
            .compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK, let selection = CustomCharacterImportSelection.classify(panel.urls) else {
            return
        }

        let defaultName = selection.urls.first?.deletingPathExtension().lastPathComponent ?? appPreferences.text("自定义角色", "Custom Character")
        Task {
            do {
                let character = try await customCharacterStore.importSelection(
                    selection,
                    displayName: defaultName,
                    motionStyle: .bounceBreathe,
                    pixelationScale: .off
                )
                settings.catCharacter = character.id
                settings.showsCat = true
                settings.usesSystemTextColor = false
            } catch {
                showImportError(error)
            }
        }
    }

    private func renameSelectedCustomCharacter(_ name: String) {
        guard let selectedCustomCharacter else { return }
        try? customCharacterStore.rename(id: selectedCustomCharacter.id, displayName: name)
    }

    private func updateSelectedCustomMotion(_ motionStyle: CustomCharacterMotionStyle) {
        guard let selectedCustomCharacter else { return }
        Task {
            do {
                try await customCharacterStore.updateStaticCharacter(
                    id: selectedCustomCharacter.id,
                    motionStyle: motionStyle,
                    pixelationScale: selectedCustomCharacter.pixelationScale
                )
            } catch {
                showImportError(error)
            }
        }
    }

    private func updateSelectedCustomPixelation(_ pixelationScale: CustomCharacterPixelationScale) {
        guard let selectedCustomCharacter else { return }
        Task {
            do {
                if selectedCustomCharacter.sourceKind == .staticImage {
                    try await customCharacterStore.updateStaticCharacter(
                        id: selectedCustomCharacter.id,
                        motionStyle: selectedCustomCharacter.motionStyle ?? .bounceBreathe,
                        pixelationScale: pixelationScale
                    )
                } else {
                    try await customCharacterStore.updatePixelation(id: selectedCustomCharacter.id, pixelationScale: pixelationScale)
                }
            } catch {
                showImportError(error)
            }
        }
    }

    private func deleteSelectedCustomCharacter() {
        guard let selectedCustomCharacter else { return }
        do {
            try customCharacterStore.delete(id: selectedCustomCharacter.id)
            settings.catCharacter = RunCatCharacter.defaultCat.id
        } catch {
            showImportError(error)
        }
    }

    private func showImportError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = appPreferences.text("无法导入角色", "Unable to Import Character")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: appPreferences.text("知道了", "OK"))
        alert.runModal()
    }

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

    private func customCharacterIconName(for character: CustomCharacter) -> String {
        switch character.sourceKind {
        case .staticImage:
            return "photo"
        case .gif, .frameSequence:
            return "film"
        }
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
                characterPreferences
                animationPreferences
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

    private var characterPreferences: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.character.title(language: appPreferences.resolvedLanguage)) {
            Toggle(appPreferences.text("启用角色", "Enable Character"), isOn: $settings.showsCat)

            if settings.showsCat {
                MenuBarSubsectionHeader(
                    systemImage: "pawprint",
                    title: appPreferences.text("内置角色", "Built-in Characters")
                )

                characterCatalog

                Divider()

                customCharacterCatalog

                if let selectedCustomCharacter {
                    Divider()
                    selectedCustomCharacterControls(selectedCustomCharacter)
                }

                let selectedChar = selectedCharacterAsset()
                if selectedChar.supportsColorControls {
                    Divider()
                    characterColorControls
                }
            } else {
                Text(appPreferences.text(
                    "开启后可选择内置角色或导入自定义角色。",
                    "Enable this to choose built-in characters or import your own."
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var characterCatalog: some View {
        AnimatedCharacterCatalog(
            settings: settings,
            characterPickerFrameTick: nil
        )
    }

    private var customCharacterCatalog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MenuBarSubsectionHeader(
                    systemImage: "photo.badge.plus",
                    title: appPreferences.text("自定义角色", "Custom Characters")
                )
                Spacer()
                Button {
                    importCustomCharacter()
                } label: {
                    Label(appPreferences.text("导入", "Import"), systemImage: "plus")
                }
                .font(.system(size: 11, weight: .medium))
            }

            if customCharacterStore.characters.isEmpty {
                Text(appPreferences.text(
                    "可导入静态图、GIF 或多张帧图。",
                    "Import a static image, GIF, or multiple frame images."
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108))], spacing: 5) {
                    ForEach(customCharacterStore.characters) { character in
                        Button(action: {
                            settings.catCharacter = character.id
                            settings.usesSystemTextColor = false
                        }) {
                        CharacterChoiceLabel(
                            title: character.displayName,
                            isSelected: settings.catCharacter == character.id
                        ) {
                            Image(systemName: customCharacterIconName(for: character))
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 24, height: 18)
                        }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func selectedCustomCharacterControls(_ character: CustomCharacter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MenuBarSubsectionHeader(
                systemImage: "slider.horizontal.3",
                title: appPreferences.text("当前自定义角色", "Selected Custom Character")
            )

            HStack {
                Text(appPreferences.text("名称", "Name"))
                    .font(.subheadline)
                TextField("", text: Binding(
                    get: { character.displayName },
                    set: { renameSelectedCustomCharacter($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)

                Button(role: .destructive) {
                    deleteSelectedCustomCharacter()
                } label: {
                    Label(appPreferences.text("删除", "Delete"), systemImage: "trash")
                }
                .font(.system(size: 11, weight: .medium))
            }

            if character.sourceKind == .staticImage {
                Picker(appPreferences.text("静态图动效", "Static Motion"), selection: Binding(
                    get: { character.motionStyle ?? .bounceBreathe },
                    set: { updateSelectedCustomMotion($0) }
                )) {
                    ForEach(CustomCharacterMotionStyle.allCases) { style in
                        Text(style.title(language: appPreferences.resolvedLanguage)).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240)
            }

            Picker(appPreferences.text("像素化", "Pixelation"), selection: Binding(
                get: { character.pixelationScale },
                set: { updateSelectedCustomPixelation($0) }
            )) {
                ForEach(CustomCharacterPixelationScale.allCases) { scale in
                    Text(scale.displayValue).tag(scale)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var characterColorControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            MenuBarSubsectionHeader(
                systemImage: "paintpalette",
                title: appPreferences.text("角色颜色", "Character Color")
            )

            HStack {
                Text(appPreferences.text("颜色模式", "Color Mode"))
                    .font(.subheadline)
                Picker("", selection: $settings.catColorMode) {
                    ForEach(CatColorMode.allCases) { mode in
                        Text(mode.displayName(zh: appPreferences.resolvedLanguage == .simplifiedChinese))
                            .tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                .onChange(of: settings.catColorMode) { newMode in
                    if newMode != CatColorMode.solid.rawValue && settings.usesSystemTextColor {
                        settings.usesSystemTextColor = false
                    }
                }
            }

            if settings.catColorMode == CatColorMode.solid.rawValue {
                HStack {
                    Text(appPreferences.text("纯色", "Solid Color"))
                        .font(.subheadline)
                    ColorPicker("", selection: Binding(
                        get: { settings.catColor.swiftUIColor },
                        set: { applyCatColor($0) }
                    ))
                    .labelsHidden()

                    HStack(spacing: 4) {
                        PresetColorButton(color: Color.white, label: "白", settings: settings)
                        PresetColorButton(color: Color.black, label: "黑", settings: settings)
                        PresetColorButton(color: Color.red, label: "红", settings: settings)
                        PresetColorButton(color: Color.orange, label: "橙", settings: settings)
                        PresetColorButton(color: Color.yellow, label: "黄", settings: settings)
                        PresetColorButton(color: Color.green, label: "绿", settings: settings)
                        PresetColorButton(color: Color.cyan, label: "青", settings: settings)
                        PresetColorButton(color: Color.blue, label: "蓝", settings: settings)
                        PresetColorButton(color: Color.purple, label: "紫", settings: settings)
                    }

                    Button(appPreferences.text("重置", "Reset")) {
                        settings.catColor = .white
                    }
                    .font(.system(size: 10))
                }
            }

            if settings.catColorMode != CatColorMode.solid.rawValue {
                Text(appPreferences.text(
                    "炫彩模式会自动变化颜色。",
                    "Dynamic modes change color automatically."
                ))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            if settings.usesSystemTextColor && (settings.catColorMode != CatColorMode.solid.rawValue || settings.catColor != PersistedColor.white) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text(appPreferences.text(
                        "系统文字颜色会覆盖角色颜色，已自动切换为自定义颜色",
                        "System text color overrides character color, auto-switched to custom color"
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                }
            }
        }
    }

    private var animationPreferences: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.animation.title(language: appPreferences.resolvedLanguage)) {
            if settings.showsCat {
                Picker(appPreferences.text("角色位置", "Character Position"), selection: $settings.catPosition) {
                    ForEach(StatusBarCharacterPosition.allCases) { position in
                        Text(position.title(language: appPreferences.resolvedLanguage)).tag(position)
                    }
                }
                .pickerStyle(.segmented)

                Picker(appPreferences.text("角色朝向", "Character Facing"), selection: $settings.catFacing) {
                    ForEach(StatusBarCharacterFacing.allCases) { facing in
                        Text(facing.title(language: appPreferences.resolvedLanguage)).tag(facing)
                    }
                }
                .pickerStyle(.segmented)

                SliderPreference(
                    title: appPreferences.text("角色大小", "Character Size"),
                    value: $settings.catScale,
                    range: 0.7...1.3,
                    displayValue: "\(Int((settings.catScale * 100).rounded()))%"
                )

                SliderPreference(
                    title: appPreferences.text("动画速度", "Animation Speed"),
                    value: $settings.catSpeedMultiplier,
                    range: 0.25...4.0,
                    displayValue: String(format: "%.1fx", settings.catSpeedMultiplier)
                )

                Text(appPreferences.text(
                    "速度倍率影响动画快慢：1.0x 为默认，2.0x 为两倍速，0.5x 为半速。",
                    "Speed multiplier affects animation rate: 1.0x is default, 2.0x is double speed, 0.5x is half speed."
                ))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

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
}
