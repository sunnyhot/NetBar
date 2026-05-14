import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let settings: StatusBarSettings
    private let appPreferences: AppPreferences
    private let updater: AppUpdater
    private var window: NSWindow?

    init(settings: StatusBarSettings, appPreferences: AppPreferences, updater: AppUpdater) {
        self.settings = settings
        self.appPreferences = appPreferences
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
            rootView: PreferencesView(settings: settings, appPreferences: appPreferences, updater: updater)
        )
        preferencesWindow.collectionBehavior = [.moveToActiveSpace]

        window = preferencesWindow
        return preferencesWindow
    }
}

private struct PreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(spacing: 16) {
            PreferencesHeroHeader(appPreferences: appPreferences, updater: updater)

            TabView {
                GeneralPreferencesView(appPreferences: appPreferences)
                    .tabItem {
                        Label(appPreferences.text("通用", "General"), systemImage: "gearshape")
                    }

                MenuBarPreferencesView(settings: settings, appPreferences: appPreferences)
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

private struct MenuBarPreferencesView: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatusBarPreview(settings: settings, appPreferences: appPreferences)

                PreferenceSection(title: appPreferences.text("文字", "Text")) {
                    SliderPreference(
                        title: appPreferences.text("字号", "Font size"),
                        value: $settings.fontSize,
                        range: 8...18,
                        displayValue: "\(Int(settings.fontSize.rounded()))"
                    )

                    Toggle(appPreferences.text("系统文字颜色", "System text color"), isOn: $settings.usesSystemTextColor)

                    if !settings.usesSystemTextColor {
                        ColorPicker(appPreferences.text("文字颜色", "Text color"), selection: textColorBinding, supportsOpacity: true)
                    }

                    Toggle(appPreferences.text("加粗", "Bold"), isOn: $settings.isBold)
                    Toggle(appPreferences.text("显示箭头", "Show arrows"), isOn: $settings.showsArrows)
                    Toggle(appPreferences.text("奔跑的小猫", "Running Cat"), isOn: $settings.showsCat)

                    if settings.showsCat {
                        // Character picker with categories
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appPreferences.text("角色", "Character"))
                                .font(.headline)

                            ForEach(RunCatCharacter.Category.allCases, id: \.rawValue) { category in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    let charsInCategory = RunCatCharacter.allCharacters.filter { $0.category == category }
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                                        ForEach(charsInCategory) { character in
                                            Button(action: {
                                                settings.catCharacter = character.id
                                            }) {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(settings.catCharacter == character.id ? Color.accentColor : Color.clear)
                                                        .frame(width: 6, height: 6)
                                                    Text(character.displayName)
                                                        .font(.system(size: 12))
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(settings.catCharacter == character.id ? Color.accentColor.opacity(0.15) : Color.clear)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            // Color mode + picker for tintable characters
                            let selectedChar = RunCatCharacter.byId(settings.catCharacter)
                            if selectedChar.supportsColorControls {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Color mode picker
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
                                        .frame(maxWidth: 200)
                                        .onChange(of: settings.catColorMode) { newMode in
                                            // Auto-disable system text color when fancy mode is selected
                                            // because template rendering would override the custom colors
                                            if newMode != CatColorMode.solid.rawValue && settings.usesSystemTextColor {
                                                settings.usesSystemTextColor = false
                                            }
                                        }
                                    }

                                    // Solid color picker (only shown in solid mode)
                                    if settings.catColorMode == CatColorMode.solid.rawValue {
                                        HStack {
                                            Text(appPreferences.text("角色颜色", "Character Color"))
                                                .font(.subheadline)
                                            ColorPicker("", selection: Binding(
                                                get: { settings.catColor.swiftUIColor },
                                                set: {
                                                    settings.catColor = PersistedColor(color: $0)
                                                    // Auto-disable system text color when choosing a non-white color
                                                    if PersistedColor(color: $0) != PersistedColor.white && settings.usesSystemTextColor {
                                                        settings.usesSystemTextColor = false
                                                    }
                                                }
                                            ))
                                            .labelsHidden()

                                            // Preset colors (with black and white)
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

                                            // Reset to white
                                            Button(appPreferences.text("重置", "Reset")) {
                                                settings.catColor = .white
                                            }
                                            .font(.system(size: 10))
                                        }
                                    }

                                    // Dynamic mode preview hint
                                    if settings.catColorMode != CatColorMode.solid.rawValue {
                                        Text(appPreferences.text(
                                            "炫彩模式：颜色将自动变化 ✨",
                                            "Dynamic mode: color will change automatically ✨"
                                        ))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    }

                                    // Warning when usesSystemTextColor is on but cat has custom color
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
                        }
                        .padding(.leading, 16)

                        Picker(appPreferences.text("角色位置", "Character Position"), selection: $settings.catPosition) {
                            ForEach(StatusBarCharacterPosition.allCases) { position in
                                Text(position.title(language: appPreferences.resolvedLanguage)).tag(position)
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

                        // Rotation settings
                        Divider()
                        Toggle(appPreferences.text("角色轮换", "Character Rotation"), isOn: $settings.catRotationEnabled)
                        Toggle(appPreferences.text("摇头效果", "Head Swing"), isOn: $settings.catHeadSwing)

                        if settings.catRotationEnabled {
                            SliderPreference(
                                title: appPreferences.text("轮换间隔", "Rotation Interval"),
                                value: $settings.catRotationIntervalMinutes,
                                range: 1...60,
                                displayValue: String(format: "%.0f分钟", settings.catRotationIntervalMinutes)
                            )
                            Text(appPreferences.text(
                                "每隔一定时间随机切换到下一个角色。",
                                "Randomly switch to the next character at intervals."
                            ))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(appPreferences.text("轮换角色池（空=全部）", "Rotation Pool (empty=all)"))
                                    .font(.subheadline)
                                ForEach(RunCatCharacter.Category.allCases, id: \.rawValue) { category in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.rawValue)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        let charsInCategory = RunCatCharacter.allCharacters.filter { $0.category == category }
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 2) {
                                            ForEach(charsInCategory) { character in
                                                Button(action: {
                                                    var ids = settings.catRotationPool.split(separator: ",").map(String.init)
                                                    if ids.contains(character.id) {
                                                        ids.removeAll { $0 == character.id }
                                                    } else {
                                                        ids.append(character.id)
                                                    }
                                                    settings.catRotationPool = ids.joined(separator: ",")
                                                }) {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: settings.catRotationPool.split(separator: ",").map(String.init).contains(character.id) ? "checkmark.square" : "square")
                                                            .font(.system(size: 9))
                                                        Text(character.displayName)
                                                            .font(.system(size: 11))
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                PreferenceSection(title: appPreferences.text("宽度与布局", "Width and Layout")) {
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

                PreferenceSection(title: appPreferences.text("背景", "Background")) {
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

private struct StatusBarPreview: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

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
                if StatusBarDisplayRenderer.presentation(snapshot: previewSnapshot, settings: settings, catFrameIndex: settings.showsCat ? 0 : nil).kind == .nativeTitle {
                    Text(AttributedString(StatusBarDisplayRenderer.attributedTitle(snapshot: previewSnapshot, settings: settings)))
                        .multilineTextAlignment(textAlignment)
                        .frame(
                            width: StatusBarDisplayRenderer.width(snapshot: previewSnapshot, settings: settings),
                            height: max(NSStatusBar.system.thickness, 24)
                        )
                } else {
                    Image(nsImage: StatusBarDisplayRenderer.image(snapshot: previewSnapshot, settings: settings, catFrameIndex: settings.showsCat ? 0 : nil))
                        .frame(
                            width: StatusBarDisplayRenderer.width(snapshot: previewSnapshot, settings: settings),
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
