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
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow.title = appPreferences.text("NetBar 偏好设置", "NetBar Preferences")
        preferencesWindow.minSize = NSSize(width: 560, height: 480)
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
        .padding(20)
        .frame(minWidth: 560, minHeight: 480)
    }
}

private struct GeneralPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 18) {
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
                            .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 18) {
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
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 18) {
            PreferenceSection(title: appPreferences.text("软件更新", "Software Update")) {
                HStack {
                    Text(appPreferences.text("当前版本", "Current version"))
                    Spacer()
                    Text(updater.currentVersionText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Toggle(appPreferences.text("自动检测更新", "Automatically check for updates"), isOn: $updater.automaticallyChecksForUpdates)

                VStack(alignment: .leading, spacing: 6) {
                    Text(updater.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let lastCheckedAt = updater.lastCheckedAt {
                        Text("\(appPreferences.text("上次检查", "Last checked")): \(lastCheckedAt, style: .time)")
                            .font(.system(size: 11, weight: .medium))
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

                    if updater.availableUpdate != nil {
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
                        }
                        .help("打开 GitHub Releases")
                    }
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
        VStack(alignment: .leading, spacing: 10) {
            Text(appPreferences.text("菜单栏预览", "Menu Bar Preview"))
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Spacer()
                if StatusBarDisplayRenderer.presentation(snapshot: previewSnapshot, settings: settings).kind == .nativeTitle {
                    Text(AttributedString(StatusBarDisplayRenderer.attributedTitle(snapshot: previewSnapshot, settings: settings)))
                        .multilineTextAlignment(textAlignment)
                        .frame(
                            width: StatusBarDisplayRenderer.width(snapshot: previewSnapshot, settings: settings),
                            height: max(NSStatusBar.system.thickness, 24)
                        )
                } else {
                    Image(nsImage: StatusBarDisplayRenderer.image(snapshot: previewSnapshot, settings: settings))
                        .frame(
                            width: StatusBarDisplayRenderer.width(snapshot: previewSnapshot, settings: settings),
                            height: max(NSStatusBar.system.thickness, 24)
                        )
                }
                Spacer()
            }
            .frame(height: 52)
            .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SliderPreference: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium))

            Slider(value: $value, in: range)
        }
    }
}
