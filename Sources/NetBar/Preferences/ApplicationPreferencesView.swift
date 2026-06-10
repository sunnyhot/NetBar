import SwiftUI

struct ApplicationPreferencesView: View {
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceSection(title: appPreferences.text("应用列表", "Application List")) {
                Toggle(appPreferences.text("隐藏系统进程", "Hide system processes"), isOn: $appPreferences.hidesSystemProcesses)

                Picker(appPreferences.text("默认排序", "Default sort"), selection: $appPreferences.applicationSort) {
                    ForEach(ApplicationSortMode.displayModes) { sortMode in
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
