import SwiftUI

struct GeneralPreferencesView: View {
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
