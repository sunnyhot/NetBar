import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PreferenceSection(
                    title: appPreferences.text("启动", "Startup"),
                    systemImage: "power"
                ) {
                    Toggle(appPreferences.text("开机启动", "Launch at login"), isOn: Binding(
                        get: { appPreferences.launchesAtLogin },
                        set: { newValue in
                            Task {
                                await appPreferences.setLaunchesAtLogin(newValue)
                            }
                        }
                    ))
                    .help(appPreferences.text(
                        "开机时自动启动 NetBar",
                        "Automatically launch NetBar at login"
                    ))

                    Picker(appPreferences.text("Dock 图标", "Dock icon"), selection: Binding(
                        get: { appPreferences.dockIconVisibility },
                        set: { appPreferences.setDockIconVisibility($0) }
                    )) {
                        ForEach(DockIconVisibility.allCases) { visibility in
                            Text(visibility.title(language: appPreferences.resolvedLanguage)).tag(visibility)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help(appPreferences.text(
                        "选择“显示 Dock 图标”时，NetBar 会出现在 Dock 栏；选择“仅菜单栏”时，NetBar 会隐藏 Dock 图标并保留菜单栏入口。",
                        "Choose Show Dock icon to keep NetBar in the Dock, or Menu bar only to hide the Dock icon while keeping the menu bar item."
                    ))

                    if appPreferences.dockIconVisibility == .menuBarOnly {
                        Label(
                            appPreferences.text(
                                "NetBar 正在以菜单栏模式运行。点击菜单栏图标可查看流量，右键可打开偏好设置",
                                "NetBar is running in menu bar mode. Click the menu bar icon to view traffic; right-click to open preferences"
                            ),
                            systemImage: "menubar.rectangle"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if let loginItemErrorMessage = appPreferences.loginItemErrorMessage {
                        Label(loginItemErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PreferenceSection(
                    title: appPreferences.text("外观", "Appearance"),
                    systemImage: "paintbrush"
                ) {
                    Picker(appPreferences.text("界面语言", "Interface language"), selection: $appPreferences.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title(language: appPreferences.resolvedLanguage)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help(appPreferences.text(
                        "菜单、偏好设置和主要状态文案会跟随此语言",
                        "Menus, preferences, and status copy follow this language"
                    ))

                    Picker(appPreferences.text("显示模式", "Display mode"), selection: $appPreferences.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { appearanceMode in
                            Text(appearanceMode.title(language: appPreferences.resolvedLanguage)).tag(appearanceMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help(appPreferences.text(
                        "跟随系统会使用 macOS 当前外观；浅色和暗黑会立即应用",
                        "System follows macOS appearance. Light and Dark apply immediately"
                    ))

                    Picker(appPreferences.text("弹出位置", "Popover position"), selection: $appPreferences.popoverPosition) {
                        ForEach(PopoverPosition.allCases) { position in
                            Text(position.title(language: appPreferences.resolvedLanguage)).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help(appPreferences.text(
                        "选择悬浮框相对于菜单栏图标的弹出方向",
                        "Choose the popover direction relative to the menu bar icon"
                    ))
                }

                PreferenceSection(
                    title: appPreferences.text("应用流量", "App Traffic"),
                    systemImage: "chart.bar"
                ) {
                    Toggle(appPreferences.text("隐藏系统进程", "Hide system processes"), isOn: $appPreferences.hidesSystemProcesses)
                    .help(appPreferences.text(
                        "隐藏 system services 等后台服务，浏览器和 IDE 等用户应用仍会显示",
                        "Hide background services. Browsers, IDEs, and other user apps remain visible"
                    ))

                    Picker(appPreferences.text("默认排序", "Default sort"), selection: $appPreferences.applicationSort) {
                        ForEach(ApplicationSortMode.displayModes) { sortMode in
                            Text(sortMode.title(language: appPreferences.resolvedLanguage)).tag(sortMode)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Spacer()
                    Button(appPreferences.text("恢复通用默认值", "Restore General Defaults")) {
                        showResetConfirmation = true
                    }
                    .alert(appPreferences.text("确认恢复默认值", "Confirm Restore Defaults"), isPresented: $showResetConfirmation) {
                        Button(appPreferences.text("恢复", "Restore"), role: .destructive) {
                            appPreferences.resetAppPreferences()
                        }
                        Button(appPreferences.text("取消", "Cancel"), role: .cancel) {}
                    } message: {
                        Text(appPreferences.text(
                            "将所有通用设置恢复为默认值，此操作不可撤销。",
                            "Restore all general settings to defaults. This cannot be undone."
                        ))
                    }
                }
            }
            .padding(.trailing, 2)
        }
    }
}
