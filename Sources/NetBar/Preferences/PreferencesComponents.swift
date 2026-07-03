import AppKit
import SwiftUI

// MARK: - Shared Preference UI Components

struct CollapsiblePreferenceSection<Content: View>: View {
    let title: String
    let systemImage: String?
    @State private var isExpanded: Bool
    @ViewBuilder var content: Content

    init(title: String, systemImage: String? = nil, defaultExpanded: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self._isExpanded = State(initialValue: defaultExpanded)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(NetBarMotion.settle) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                    }
                    NetBarSectionHeader(title: title)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .livingSignalRow(tone: .neutral, padding: 12)
                .transition(.opacity.combined(with: .move(edge: .top)).animation(NetBarMotion.settle))
            }
        }
    }
}

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
            .livingSignalRow(tone: .neutral, padding: 12)
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

// MARK: - Preferences Header

struct PreferencesHeader: View {
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var updater: AppUpdater

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LivingSignalTone.active.color)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LivingSignalTone.active.color.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(LivingSignalTone.active.color.opacity(0.20), lineWidth: 0.6)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(appPreferences.text("NetBar 偏好设置", "NetBar Preferences"))
                    .font(.system(size: 16, weight: .semibold))
                Text(appPreferences.text(
                    "调整菜单栏显示、详情面板、应用流量和更新策略。",
                    "Tune menu bar display, detail panels, app traffic, and update behavior."
                ))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer()

            LivingSignalStatusChip(text: updater.currentVersionText, tone: .neutral)
        }
        .livingSignalToolbarSurface(padding: 12)
    }
}
