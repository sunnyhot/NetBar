import AppKit
import SwiftUI

// MARK: - Shared Preference UI Components

struct PreferenceSection<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .netBarCard(cornerRadius: 12, padding: 12)
        }
    }
}

struct SliderPreference: View {
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

struct PresetColorButton: View {
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

// MARK: - Preferences Hero Header

struct PreferencesHeroHeader: View {
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
