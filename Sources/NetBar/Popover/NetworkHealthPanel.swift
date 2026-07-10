import SwiftUI

/// The network-health summary panel for the details popover. Placed directly
/// below the realtime chart, it answers: what is happening, is connectivity
/// good/fluctuating/poor/offline, what evidence supports that, and what to do next.
struct NetworkHealthPanel: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    @State private var showingConsentSheet = false
    @State private var isDetailExpanded = false

    private var health: NetworkHealthSnapshot { monitor.healthSnapshot }
    private var settings: NetworkIntelligenceSettings { appPreferences.networkIntelligenceSettings }

    var body: some View {
        if settings.isActiveNetworkDiagnosticsEnabled {
            activeDiagnosticsContent
        } else {
            localOnlyContent
        }
    }

    // MARK: - Local-only (before consent)

    private var localOnlyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                healthDot(for: health.state)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appPreferences.text("本地网络状态正常", "Local network looks normal"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(appPreferences.text("未检测公网质量", "Internet quality not checked"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button {
                    showingConsentSheet = true
                } label: {
                    Label(appPreferences.text("启用", "Enable"), systemImage: "checkmark.shield")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .netBarCard(cornerRadius: 14, padding: 14)
        .sheet(isPresented: $showingConsentSheet) {
            ActiveDiagnosticsConsentSheet(
                appPreferences: appPreferences,
                isPresented: $showingConsentSheet,
                onConfirm: {
                    updateSettings { $0.isActiveNetworkDiagnosticsEnabled = true }
                    monitor.updateHealthScheduling(
                        isEnabled: true,
                        isDetailWindowVisible: true,
                        isLowPowerMode: false,
                        isScreenLocked: false
                    )
                }
            )
        }
    }

    // MARK: - Active diagnostics enabled

    private var activeDiagnosticsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                healthDot(for: health.state)
                VStack(alignment: .leading, spacing: 2) {
                    Text(health.state.title(language: appPreferences.resolvedLanguage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let cause = health.primaryCause {
                        Text(cause.shortLabel(language: appPreferences.resolvedLanguage))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(toneColor(for: health.state))
                    } else {
                        Text(health.evidenceMode.title(language: appPreferences.resolvedLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if health.isRetestInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        monitor.requestHealthRetest()
                    } label: {
                        Label(appPreferences.text("立即复测", "Retest Now"), systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Metric grid: latency, DNS, recent failures, last check.
            HStack(spacing: 8) {
                healthMetric(
                    title: appPreferences.text("响应", "Latency"),
                    value: latencyText,
                    symbol: "bolt.horizontal"
                )
                healthMetric(
                    title: appPreferences.text("DNS", "DNS"),
                    value: dnsText,
                    symbol: "magnifyingglass"
                )
                healthMetric(
                    title: appPreferences.text("失败", "Failures"),
                    value: health.failureRatioText(),
                    symbol: "exclamationmark.triangle"
                )
                healthMetric(
                    title: appPreferences.text("上次", "Last"),
                    value: lastCheckText,
                    symbol: "clock"
                )
            }

            // Primary cause explanation + recommendation.
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

            // Expandable evidence detail.
            DisclosureGroup(isExpanded: $isDetailExpanded) {
                evidenceDetail
            } label: {
                Text(appPreferences.text("证据明细", "Evidence detail"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .netBarCard(cornerRadius: 14, padding: 14)
    }

    private var evidenceDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dns = health.metrics.dnsDurationMS {
                evidenceRow(appPreferences.text("DNS 解析", "DNS resolution"), value: String(format: "%.0f ms", dns))
            }
            if let latency = health.metrics.responseLatencyMS {
                evidenceRow(appPreferences.text("HTTPS 响应", "HTTPS response"), value: String(format: "%.0f ms", latency))
            }
            evidenceRow(
                appPreferences.text("最近检测", "Recent attempts"),
                value: "\(health.metrics.recentAttemptCount)"
            )
            evidenceRow(
                appPreferences.text("参考目标", "Reference target"),
                value: appPreferences.text("github.com（已用于更新检查）", "github.com (also used for updates)")
            )
            Text(appPreferences.text(
                "响应延迟是访问参考目标的时间，不代表整体网速；失败指参考目标不可达，不是丢包。",
                "Latency is measured against the reference target and does not represent overall speed. Failures mean the reference target was unreachable, not packet loss."
            ))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var latencyText: String {
        if let latency = health.metrics.responseLatencyMS {
            return String(format: "%.0fms", latency)
        }
        return "—"
    }

    private var dnsText: String {
        if let dns = health.metrics.dnsDurationMS {
            return String(format: "%.0fms", dns)
        }
        return "—"
    }

    private var lastCheckText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: health.sampledAt, relativeTo: Date())
    }

    private func healthMetric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func evidenceRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
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
        case .good: return LivingSignalPalette.signal.color
        case .fluctuating: return LivingSignalPalette.attention.color
        case .poor: return LivingSignalPalette.critical.color
        case .offline: return LivingSignalPalette.critical.color
        }
    }

    private func updateSettings(_ update: (inout NetworkIntelligenceSettings) -> Void) {
        var settings = appPreferences.networkIntelligenceSettings
        update(&settings)
        appPreferences.networkIntelligenceSettings = settings
    }
}

/// Confirmation sheet shown before enabling active diagnostics. States what
/// NetBar will do and what it will not do.
private struct ActiveDiagnosticsConsentSheet: View {
    @ObservedObject var appPreferences: AppPreferences
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appPreferences.text("启用主动网络诊断", "Enable Active Network Diagnostics"))
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                consentRow(appPreferences.text(
                    "NetBar 会解析并连接到已用于更新检查的 GitHub。",
                    "NetBar will resolve and connect to GitHub, already used for update checks."
                ))
                consentRow(appPreferences.text(
                    "检测会测量 DNS 耗时、HTTPS 连接/响应延迟和最近成功/失败次数。",
                    "Checks measure DNS duration, HTTPS connection/response latency, and recent success/failure counts."
                ))
                consentRow(appPreferences.text(
                    "不会上传任何流量、应用、浏览历史或本地网络统计数据。",
                    "No traffic, application, browsing history, or local network statistics are uploaded."
                ))
                consentRow(appPreferences.text(
                    "可以随时在偏好设置中关闭。",
                    "You can disable it at any time in Preferences."
                ))
            }

            Text(appPreferences.text(
                "GitHub 是参考目标，不是对整个互联网质量的声明。本地网络路径仍可用时，参考目标失败只表示参考目标不可达。",
                "GitHub is a reference target, not a claim about the entire internet. When the local network path is available, reference failures only mean the reference target was unreachable."
            ))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(appPreferences.text("取消", "Cancel"), role: .cancel) {
                    isPresented = false
                }
                Spacer()
                Button(appPreferences.text("启用诊断", "Enable Diagnostics")) {
                    onConfirm()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func consentRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(LivingSignalPalette.signal.color)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
