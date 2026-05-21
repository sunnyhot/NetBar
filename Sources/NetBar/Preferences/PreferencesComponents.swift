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
                .netBarCard(cornerRadius: 12, padding: 12)
                .transition(.opacity.combined(with: .move(edge: .top)).animation(NetBarMotion.settle))
            }
        }
    }
}

struct PreferenceSection<Content: View>: View {
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
