import SwiftUI

enum NetworkIntelligenceTone: Equatable {
    case normal
    case attention
    case critical
}

struct NetworkIntelligenceStatusPresentation: Equatable {
    let title: String
    let message: String
    let tone: NetworkIntelligenceTone
    let symbolName: String

    init(event: NetworkAnomalyEvent?, language: AppLanguage) {
        guard let event else {
            title = language.text("网络状态正常", "Network status normal")
            message = language.text("没有检测到需要注意的网络异常。", "No network anomalies need attention.")
            tone = .normal
            symbolName = "checkmark.seal.fill"
            return
        }

        title = event.title
        message = event.message
        switch event.severity {
        case .info:
            tone = .normal
            symbolName = "info.circle.fill"
        case .warning:
            tone = .attention
            symbolName = "exclamationmark.circle.fill"
        case .critical:
            tone = .critical
            symbolName = "exclamationmark.triangle.fill"
        }
    }
}

struct NetworkIntelligenceStatusCard: View {
    let presentation: NetworkIntelligenceStatusPresentation
    @ObservedObject var appPreferences: AppPreferences
    let openPreferences: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(livingTone.color)
                .frame(width: 28, height: 28)
                .background(livingTone.softColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                Text(presentation.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button { openPreferences() } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(NetBarIconButtonStyle())
            .help(appPreferences.text("调整智能检测", "Adjust Intelligence"))
        }
        .livingSignalPanel(tone: livingTone, isElevated: presentation.tone != .normal, padding: 11)
    }

    private var livingTone: LivingSignalTone {
        switch presentation.tone {
        case .normal:
            return .normal
        case .attention:
            return .attention
        case .critical:
            return .critical
        }
    }
}
