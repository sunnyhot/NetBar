import SwiftUI

struct NetworkHealthPanel: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences

    private var health: NetworkHealthSnapshot { monitor.healthSnapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                healthDot(for: health.state)

                VStack(alignment: .leading, spacing: 2) {
                    Text(health.state.title(language: appPreferences.resolvedLanguage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(
                        health.primaryCause?.shortLabel(language: appPreferences.resolvedLanguage)
                            ?? appPreferences.text("本地接口状态", "Local interface status")
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(toneColor(for: health.state))
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                localMetric(
                    title: appPreferences.text("外部接口", "External interface"),
                    isAvailable: health.metrics.hasEligibleExternalInterface
                )
                localMetric(
                    title: appPreferences.text("本地路径", "Local path"),
                    isAvailable: health.metrics.isLocalPathAvailable
                )
            }

            if let cause = health.primaryCause {
                Text(cause.explanation(language: appPreferences.resolvedLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(cause.recommendation(language: appPreferences.resolvedLanguage))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(toneColor(for: health.state))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(appPreferences.text(
                "仅依据 macOS 本地网络接口状态，不会发起额外网络请求。",
                "Uses only local macOS network-interface state and makes no additional network requests."
            ))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .netBarCard(cornerRadius: 14, padding: 14)
    }

    private func localMetric(title: String, isAvailable: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isAvailable ? LivingSignalPalette.signal.color : LivingSignalPalette.critical.color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(appPreferences.text(isAvailable ? "可用" : "不可用", isAvailable ? "Available" : "Unavailable"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.5),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func healthDot(for state: NetworkHealthState) -> some View {
        let color = toneColor(for: state)
        return ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 26, height: 26)
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Circle()
                .strokeBorder(color.opacity(0.32), lineWidth: 1)
                .frame(width: 16, height: 16)
        }
        .accessibilityHidden(true)
    }

    private func toneColor(for state: NetworkHealthState) -> Color {
        switch state {
        case .good:
            return LivingSignalPalette.signal.color
        case .offline:
            return LivingSignalPalette.critical.color
        }
    }
}
