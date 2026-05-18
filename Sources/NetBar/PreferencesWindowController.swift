import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let customCharacterStore: CustomCharacterStore
    private let updater: AppUpdater
    private var window: NSWindow?

    init(
        settings: StatusBarSettings,
        appPreferences: AppPreferences,
        customCharacterStore: CustomCharacterStore,
        updater: AppUpdater
    ) {
        self.settings = settings
        self.appPreferences = appPreferences
        self.customCharacterStore = customCharacterStore
        self.updater = updater
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
                updater: updater
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
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(spacing: 16) {
            PreferencesHeroHeader(appPreferences: appPreferences, updater: updater)

            TabView {
                GeneralPreferencesView(appPreferences: appPreferences)
                    .tabItem {
                        Label(appPreferences.text("通用", "General"), systemImage: "gearshape")
                    }

                MenuBarPreferencesView(
                    settings: settings,
                    appPreferences: appPreferences,
                    customCharacterStore: customCharacterStore
                )
                    .tabItem {
                        Label(appPreferences.text("菜单栏", "Menu Bar"), systemImage: "menubar.rectangle")
                    }

                ApplicationPreferencesView(appPreferences: appPreferences)
                    .tabItem {
                        Label(appPreferences.text("应用", "Apps"), systemImage: "app.connected.to.app.below.fill")
                    }

                UpdatePreferencesView(appPreferences: appPreferences, updater: updater)
                    .tabItem {
                        Label(appPreferences.text("更新", "Updates"), systemImage: "arrow.triangle.2.circlepath")
                    }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .netBarPanelBackground()
        .preferredColorScheme(appPreferences.appearanceMode.preferredColorScheme)
    }
}

private struct PreferencesHeroHeader: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        HStack(spacing: 12) {
            NetBarIconTile(systemName: "waveform.path.ecg.rectangle", tone: .download, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(appPreferences.text("NetBar 设置工作台", "NetBar Control Center"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(appPreferences.text(
                    "调整菜单栏指标、悬浮面板、应用流量和更新策略。",
                    "Tune menu bar metrics, floating panels, app traffic, and update behavior."
                ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            NetBarBadge(text: updater.currentVersionText, tone: .neutral)
        }
        .netBarCard(cornerRadius: 14, padding: 14, isProminent: true)
    }
}

private struct GeneralPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PreferenceSection(title: appPreferences.text("启动与窗口", "Startup and Windows")) {
                    Toggle(appPreferences.text("开机启动", "Launch at login"), isOn: Binding(
                        get: { appPreferences.launchesAtLogin },
                        set: { newValue in
                            Task {
                                await appPreferences.setLaunchesAtLogin(newValue)
                            }
                        }
                    ))

                    Toggle(appPreferences.text("显示 Dock 图标", "Show Dock icon"), isOn: $appPreferences.showsDockIcon)

                    Text(appPreferences.text(
                        "关闭 Dock 图标后，NetBar 会作为菜单栏 App 运行。仍可从菜单栏图标右键打开流量窗口或偏好设置。",
                        "When the Dock icon is hidden, NetBar runs as a menu bar app. You can still right-click the menu bar item to open the traffic window or preferences."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let loginItemErrorMessage = appPreferences.loginItemErrorMessage {
                        Label(loginItemErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PreferenceSection(title: appPreferences.text("语言", "Language")) {
                    Picker(appPreferences.text("界面语言", "Interface language"), selection: $appPreferences.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title(language: appPreferences.resolvedLanguage)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appPreferences.text(
                        "菜单、偏好设置和主要状态文案会跟随此语言。系统语言会使用 macOS 的首选语言。",
                        "Menus, preferences, and primary status copy follow this language. System uses your macOS preferred language."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PreferenceSection(title: appPreferences.text("外观", "Appearance")) {
                    Picker(appPreferences.text("显示模式", "Display mode"), selection: $appPreferences.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { appearanceMode in
                            Text(appearanceMode.title(language: appPreferences.resolvedLanguage)).tag(appearanceMode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appPreferences.text(
                        "跟随系统会使用 macOS 当前外观；浅色和暗黑会立即应用到偏好设置、流量窗口和菜单。",
                        "System follows the current macOS appearance. Light and Dark apply immediately to preferences, the traffic window, and menus."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PreferenceSection(title: appPreferences.text("悬浮框", "Popover")) {
                    Picker(appPreferences.text("弹出位置", "Popover position"), selection: $appPreferences.popoverPosition) {
                        ForEach(PopoverPosition.allCases) { position in
                            Text(position.title(language: appPreferences.resolvedLanguage)).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appPreferences.text(
                        "选择悬浮框相对于菜单栏图标的弹出方向。左侧会从图标左边弹出，右侧会从图标右边弹出。",
                        "Choose the popover direction relative to the menu bar icon. Left pops out from the left side, Right from the right side."
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Button(appPreferences.text("恢复通用默认值", "Restore General Defaults")) {
                        appPreferences.resetAppPreferences()
                    }
                }
            }
            .padding(.trailing, 2)
        }
    }
}

enum MenuBarPreferenceGroup: String, CaseIterable {
    case preview
    case display
    case character
    case animation
    case layout

    func title(language: AppLanguage) -> String {
        switch self {
        case .preview:
            return language.text("实时预览", "Live Preview")
        case .display:
            return language.text("显示内容", "Display")
        case .character:
            return language.text("角色", "Character")
        case .animation:
            return language.text("动画与轮换", "Animation & Rotation")
        case .layout:
            return language.text("宽度与布局", "Width & Layout")
        }
    }
}

private struct MenuBarPreferencesView: View {
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

private struct ApplicationPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceSection(title: appPreferences.text("应用列表", "Application List")) {
                Toggle(appPreferences.text("隐藏系统进程", "Hide system processes"), isOn: $appPreferences.hidesSystemProcesses)

                Picker(appPreferences.text("默认排序", "Default sort"), selection: $appPreferences.applicationSort) {
                    ForEach(ApplicationSortMode.allCases) { sortMode in
                        Text(sortMode.title(language: appPreferences.resolvedLanguage)).tag(sortMode)
                    }
                }
                .pickerStyle(.menu)

                Text(appPreferences.text(
                    "隐藏系统进程会过滤 networkd、mDNSResponder 等后台服务。浏览器、IDE 等用户应用仍会显示。",
                    "Hiding system processes filters services such as networkd and mDNSResponder. Browsers, IDEs, and other user apps remain visible."
                ))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

private struct UpdatePreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceSection(title: appPreferences.text("软件更新", "Software Update")) {
                HStack {
                    Text(appPreferences.text("当前版本", "Current version"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(updater.currentVersionText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Toggle(appPreferences.text("自动检测更新", "Automatically check for updates"), isOn: $updater.automaticallyChecksForUpdates)

                if updater.isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: updater.downloadProgress)
                            .progressViewStyle(.linear)
                        Text("\(Int(updater.downloadProgress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(updater.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let lastCheckedAt = updater.lastCheckedAt {
                        Text("\(appPreferences.text("上次检查", "Last checked")): \(lastCheckedAt, style: .time)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await updater.checkForUpdates(isManual: true)
                        }
                    } label: {
                        Label(updater.isChecking ? appPreferences.text("检查中", "Checking") : appPreferences.text("检查更新", "Check for Updates"), systemImage: "arrow.clockwise")
                    }
                    .disabled(updater.isChecking || updater.isDownloading)

                    if updater.isUpdateReadyToInstall {
                        Button {
                            Task {
                                await updater.downloadAndInstall()
                            }
                        } label: {
                            Label(appPreferences.text("安装并重启", "Install and Restart"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                    } else if updater.availableUpdate != nil {
                        Button {
                            Task {
                                await updater.downloadAndInstall()
                            }
                        } label: {
                            Label(updater.isDownloading ? appPreferences.text("下载中", "Downloading") : appPreferences.text("下载并安装", "Download and Install"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(updater.isChecking || updater.isDownloading)
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()

                    if let releasePageURL = updater.releasePageURL {
                        Link(destination: releasePageURL) {
                            Image(systemName: "safari")
                                .foregroundStyle(.secondary)
                        }
                        .help("打开 GitHub Releases")
                    }
                }
            }

            PreferenceSection(title: appPreferences.text("关于项目", "About Project")) {
                HStack {
                    Text(appPreferences.text("GitHub 仓库", "GitHub Repository"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Link(destination: URL(string: "https://github.com/sunnyhot/NetBar")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                            Text("sunnyhot/NetBar")
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    .help(appPreferences.text("在浏览器中打开 GitHub 仓库", "Open GitHub repository in browser"))
                }
            }

            Spacer()
        }
    }
}

private struct MenuBarSettingsSummary: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    let characterName: String

    var body: some View {
        HStack(spacing: 8) {
            NetBarBadge(
                text: settings.showsCat ? characterName : appPreferences.text("无角色", "No character"),
                tone: settings.showsCat ? .download : .neutral
            )
            NetBarBadge(
                text: settings.usesAutomaticWidth ? appPreferences.text("自动宽度", "Auto width") : appPreferences.text("手动宽度", "Manual width"),
                tone: .neutral
            )
            NetBarBadge(
                text: settings.showsBackground ? appPreferences.text("背景开启", "Background on") : appPreferences.text("透明背景", "Transparent"),
                tone: settings.showsBackground ? .success : .neutral
            )
            if settings.showsCat {
                NetBarBadge(text: String(format: "%.1fx", settings.catSpeedMultiplier), tone: .upload)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuBarSubsectionHeader: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusBarPreview: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    let catFrameIndex: Int?

    private let previewSnapshot = NetworkSnapshot(
        timestamp: Date(timeIntervalSince1970: 0),
        interfaces: [],
        downloadBytesPerSecond: 1_280_000,
        uploadBytesPerSecond: 84_000,
        totalReceivedBytes: 0,
        totalSentBytes: 0,
        sampleCount: 1
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appPreferences.text("菜单栏预览", "Menu Bar Preview"))
                .font(.system(size: 12, weight: .bold))

            HStack {
                Spacer()
                let presentation = StatusBarDisplayRenderer.presentation(
                    snapshot: previewSnapshot,
                    settings: settings,
                    customCharacterStore: customCharacterStore,
                    catFrameIndex: catFrameIndex
                )

                if presentation.kind == .nativeTitle {
                    Text(AttributedString(StatusBarDisplayRenderer.attributedTitle(snapshot: previewSnapshot, settings: settings)))
                        .multilineTextAlignment(textAlignment)
                        .frame(
                            width: presentation.width,
                            height: max(NSStatusBar.system.thickness, 24)
                        )
                } else {
                    Image(nsImage: StatusBarDisplayRenderer.image(
                        snapshot: previewSnapshot,
                        settings: settings,
                        customCharacterStore: customCharacterStore,
                        catFrameIndex: catFrameIndex
                    ))
                        .frame(
                            width: presentation.width,
                            height: max(NSStatusBar.system.thickness, 24)
                        )
                }
                Spacer()
            }
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
        }
    }

    private var textAlignment: TextAlignment {
        switch settings.alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private struct CharacterChoiceLabel<Icon: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
            icon
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}

private struct CharacterPickerPreviewIcon: View {
    let character: RunCatCharacter
    let frameIndex: Int

    private static let imageCache = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let image = Self.cachedImage(for: character, frameIndex: frameIndex) {
                Image(nsImage: image)
                    .renderingMode(character.isTemplate ? .template : .original)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: character.isGooglyEyes ? "eye" : "questionmark.square.dashed")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .foregroundStyle(.primary)
        .frame(width: 24, height: 18)
        .accessibilityHidden(true)
    }

    private static func cachedImage(for character: RunCatCharacter, frameIndex: Int) -> NSImage? {
        let safeFrameIndex = frameIndex % max(character.frameCount, 1)
        let cacheKey = "\(character.id)_\(safeFrameIndex)" as NSString

        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        let image = loadFromDisk(character: character, frameIndex: safeFrameIndex)
        if let image {
            imageCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    private static func loadFromDisk(character: RunCatCharacter, frameIndex: Int) -> NSImage? {
        let resourcePath = "RunCat/\(character.id)"
        if let url = Bundle.main.url(
            forResource: "frame_\(frameIndex)",
            withExtension: "png",
            subdirectory: resourcePath
        ) {
            return NSImage(contentsOf: url)
        }
        if let resourcePath = Bundle.main.resourcePath {
            return NSImage(contentsOf: URL(fileURLWithPath: "\(resourcePath)/RunCat/\(character.id)/frame_\(frameIndex).png"))
        }
        return nil
    }
}

private struct PreferenceSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NetBarSectionHeader(title: title)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .netBarCard(cornerRadius: 12, padding: 12)
        }
    }
}

private struct SliderPreference: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}

private struct PresetColorButton: View {
    let color: Color
    let label: String
    @ObservedObject var settings: StatusBarSettings

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 16, height: 16)
            .overlay(
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            .onTapGesture {
                let newColor = PersistedColor(color: color)
                settings.catColor = newColor
                if newColor != PersistedColor.white && settings.usesSystemTextColor {
                    settings.usesSystemTextColor = false
                }
            }
    }
}

// MARK: - Animated Preview Section (owns its own timer)

private struct AnimatedPreviewSection: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    let selectedCharacterAsset: CharacterAsset

    @State private var previewFrameTimeline = CharacterPreviewFrameTimeline()

    private static let previewFrameInterval: TimeInterval = 1.0 / 8.0

    private var selectedPreviewFrameIndex: Int? {
        guard settings.showsCat else { return nil }
        return previewFrameTimeline.frameIndex(for: selectedCharacterAsset)
    }

    var body: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.preview.title(language: appPreferences.resolvedLanguage)) {
            StatusBarPreview(
                settings: settings,
                appPreferences: appPreferences,
                customCharacterStore: customCharacterStore,
                catFrameIndex: selectedPreviewFrameIndex
            )

            MenuBarSettingsSummary(
                settings: settings,
                appPreferences: appPreferences,
                characterName: selectedCharacterAsset.displayName
            )
        }
        .onReceive(Timer.publish(every: Self.previewFrameInterval, on: .main, in: .common).autoconnect()) { _ in
            guard settings.showsCat else {
                previewFrameTimeline.reset()
                return
            }
            previewFrameTimeline.advance(for: selectedCharacterAsset)
        }
    }
}

// MARK: - Animated Character Catalog (owns its own timer)

private struct AnimatedCharacterCatalog: View {
    @ObservedObject var settings: StatusBarSettings
    let characterPickerFrameTick: Int?

    @State private var frameTick = 0

    private static let frameInterval: TimeInterval = 1.0 / 8.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(RunCatCharacter.Category.allCases, id: \.rawValue) { category in
                VStack(alignment: .leading, spacing: 5) {
                    Text(category.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    let charsInCategory = RunCatCharacter.allCharacters.filter { $0.category == category }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118))], spacing: 5) {
                        ForEach(charsInCategory) { character in
                            Button(action: {
                                settings.catCharacter = character.id
                            }) {
                                CharacterChoiceLabel(
                                    title: character.displayName,
                                    isSelected: settings.catCharacter == character.id
                                ) {
                                    CharacterPickerPreviewIcon(
                                        character: character,
                                        frameIndex: frameTick
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: Self.frameInterval, on: .main, in: .common).autoconnect()) { _ in
            frameTick = (frameTick + 1) % 10_000
        }
    }
}
