import SwiftUI

enum LivingSignalTone: String, CaseIterable, Equatable {
    case idle
    case normal
    case active
    case uploadHeavy
    case attention
    case critical
    case neutral

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .normal:
            return .green
        case .active:
            return Color(red: 0.31, green: 0.86, blue: 0.77)
        case .uploadHeavy:
            return Color(red: 1.0, green: 0.48, blue: 0.4)
        case .attention:
            return .orange
        case .critical:
            return .red
        case .neutral:
            return .secondary
        }
    }

    var softColor: Color {
        color.opacity(0.14)
    }

    var gradient: LinearGradient {
        switch self {
        case .active:
            return LinearGradient(
                colors: [
                    Color(red: 0.31, green: 0.86, blue: 0.77),
                    Color(red: 0.95, green: 0.78, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .uploadHeavy:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.48, blue: 0.4),
                    Color(red: 0.95, green: 0.78, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .critical:
            return LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .attention:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .normal:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .idle, .neutral:
            return LinearGradient(
                colors: [Color.secondary.opacity(0.38), Color.secondary.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

enum LivingSignalLayout {
    static let minimumPopoverWidth: CGFloat = 480
    static let preferredPopoverWidth: CGFloat = 500
    static let maximumPopoverWidth: CGFloat = 520
    static let minimumPopoverHeight: CGFloat = 500
    static let preferredPopoverHeight: CGFloat = 720
    static let panelCornerRadius: CGFloat = 12
    static let elevatedPanelCornerRadius: CGFloat = 16
    static let rowCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 18
    static let verticalSectionSpacing: CGFloat = 14
    static let chartHeight: CGFloat = 156
    static let iconTileSize: CGFloat = 34
}

struct LivingSignalMotionPolicy: Equatable {
    let allowsLoopingEffects: Bool
    let allowsScan: Bool
    let pulseScale: CGFloat
    let pulseOpacity: Double
    let scanDuration: Double

    static func make(
        reduceMotion: Bool,
        windowVisible: Bool,
        isActive: Bool
    ) -> LivingSignalMotionPolicy {
        guard !reduceMotion, windowVisible, isActive else {
            return LivingSignalMotionPolicy(
                allowsLoopingEffects: false,
                allowsScan: false,
                pulseScale: 1,
                pulseOpacity: 0,
                scanDuration: 0
            )
        }

        return LivingSignalMotionPolicy(
            allowsLoopingEffects: true,
            allowsScan: true,
            pulseScale: 1.035,
            pulseOpacity: 0.18,
            scanDuration: 2.6
        )
    }
}

struct LivingSignalStatusPresentation: Equatable {
    let title: String
    let subtitle: String
    let tone: LivingSignalTone
    let symbolName: String
    let totalSpeed: String
    let interfaceName: String

    static func make(
        snapshot: NetworkSnapshot,
        latestEvent: NetworkAnomalyEvent?,
        language: AppLanguage
    ) -> LivingSignalStatusPresentation {
        let primaryInterface = snapshot.interfaces.first(where: \.isPrimary)?.displayName
            ?? snapshot.interfaces.first?.displayName
            ?? language.text("无接口", "No Interface")
        let totalSpeed = ByteFormat.speed(snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond)

        if let latestEvent {
            let tone: LivingSignalTone = latestEvent.severity == .critical ? .critical : .attention
            return LivingSignalStatusPresentation(
                title: latestEvent.title,
                subtitle: latestEvent.message,
                tone: tone,
                symbolName: latestEvent.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill",
                totalSpeed: totalSpeed,
                interfaceName: primaryInterface
            )
        }

        if snapshot.downloadBytesPerSecond < 1, snapshot.uploadBytesPerSecond < 1 {
            return LivingSignalStatusPresentation(
                title: language.text("空闲", "Idle"),
                subtitle: language.text("等待新的网络活动", "Waiting for network activity"),
                tone: .idle,
                symbolName: "pause.circle.fill",
                totalSpeed: totalSpeed,
                interfaceName: primaryInterface
            )
        }

        if snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond * 1.6,
           snapshot.uploadBytesPerSecond > 100_000 {
            return LivingSignalStatusPresentation(
                title: language.text("上传占优", "Upload Heavy"),
                subtitle: language.text("上传速率高于下载", "Upload is leading download"),
                tone: .uploadHeavy,
                symbolName: "arrow.up.circle.fill",
                totalSpeed: totalSpeed,
                interfaceName: primaryInterface
            )
        }

        return LivingSignalStatusPresentation(
            title: language.text("活跃", "Active"),
            subtitle: language.text("实时信号正在流动", "Realtime signal is flowing"),
            tone: .active,
            symbolName: "waveform.path.ecg",
            totalSpeed: totalSpeed,
            interfaceName: primaryInterface
        )
    }
}

struct LivingSignalPanelModifier: ViewModifier {
    var tone: LivingSignalTone = .neutral
    var isElevated = false
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        let radius = isElevated ? LivingSignalLayout.elevatedPanelCornerRadius : LivingSignalLayout.panelCornerRadius
        let baseFill = Color(nsColor: .controlBackgroundColor).opacity(isElevated ? 0.86 : 0.72)

        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tone.softColor.opacity(isElevated ? 0.85 : 0.45))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tone.color.opacity(isElevated ? 0.2 : 0.11), lineWidth: 0.7)
            )
    }
}

extension View {
    func livingSignalPanel(
        tone: LivingSignalTone = .neutral,
        isElevated: Bool = false,
        padding: CGFloat = 0
    ) -> some View {
        modifier(LivingSignalPanelModifier(tone: tone, isElevated: isElevated, padding: padding))
    }

    func livingSignalPanelBackground() -> some View {
        background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        Color(red: 0.31, green: 0.86, blue: 0.77).opacity(0.07),
                        Color(red: 1.0, green: 0.48, blue: 0.4).opacity(0.035),
                        Color(nsColor: .windowBackgroundColor).opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
}
