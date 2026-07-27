import SwiftUI

enum LivingSignalColorRole: Equatable {
    case signal
    case upload
    case attention
    case critical
    case neutral
}

struct LivingSignalColorSpec: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

enum LivingSignalPalette {
    static let signal = LivingSignalColorSpec(red: 0.12, green: 0.62, blue: 0.57)
    static let upload = LivingSignalColorSpec(red: 0.88, green: 0.41, blue: 0.34)
    static let attention = LivingSignalColorSpec(red: 0.79, green: 0.53, blue: 0.13)
    static let critical = LivingSignalColorSpec(red: 0.85, green: 0.29, blue: 0.29)
    static let neutral = LivingSignalColorSpec(red: 0.42, green: 0.45, blue: 0.50)
}

enum LivingSignalSurface {
    static let windowSignalTintOpacity = 0.022
    static let windowUploadTintOpacity = 0.014
    static let elevatedFillOpacity = 0.82
    static let panelFillOpacity = 0.66
    static let rowFillOpacity = 0.46
    static let selectedFillOpacity = 0.10
    static let toneFillOpacity = 0.055
    static let rowToneFillOpacity = 0.035
    static let borderOpacity = 0.075
    static let selectedBorderOpacity = 0.22
}

enum LivingSignalTone: String, CaseIterable, Equatable {
    case idle
    case normal
    case active
    case uploadHeavy
    case attention
    case critical
    case neutral

    var role: LivingSignalColorRole {
        switch self {
        case .normal, .active:
            return .signal
        case .uploadHeavy:
            return .upload
        case .attention:
            return .attention
        case .critical:
            return .critical
        case .idle, .neutral:
            return .neutral
        }
    }

    var spec: LivingSignalColorSpec {
        switch role {
        case .signal:
            return LivingSignalPalette.signal
        case .upload:
            return LivingSignalPalette.upload
        case .attention:
            return LivingSignalPalette.attention
        case .critical:
            return LivingSignalPalette.critical
        case .neutral:
            return LivingSignalPalette.neutral
        }
    }

    var color: Color {
        spec.color
    }

    var softColor: Color {
        color.opacity(role == .neutral ? 0.10 : 0.12)
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(role == .neutral ? 0.42 : 0.76)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
            return LivingSignalStatusPresentation(
                title: latestEvent.title,
                subtitle: latestEvent.message,
                tone: .attention,
                symbolName: "exclamationmark.circle.fill",
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
        let baseFill = Color(nsColor: .controlBackgroundColor)
            .opacity(isElevated ? LivingSignalSurface.elevatedFillOpacity : LivingSignalSurface.panelFillOpacity)

        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tone.color.opacity(tone.role == .neutral ? 0 : LivingSignalSurface.toneFillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        tone.color.opacity(tone.role == .neutral ? LivingSignalSurface.borderOpacity : LivingSignalSurface.selectedBorderOpacity),
                        lineWidth: 0.7
                    )
            )
    }
}

struct LivingSignalRowModifier: ViewModifier {
    var tone: LivingSignalTone = .neutral
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: LivingSignalLayout.rowCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(LivingSignalSurface.rowFillOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: LivingSignalLayout.rowCornerRadius, style: .continuous)
                            .fill(tone.color.opacity(tone.role == .neutral ? 0 : LivingSignalSurface.rowToneFillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: LivingSignalLayout.rowCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(LivingSignalSurface.borderOpacity), lineWidth: 0.6)
            )
    }
}

struct LivingSignalSelectedSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LivingSignalTone.active.color.opacity(LivingSignalSurface.selectedFillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LivingSignalTone.active.color.opacity(LivingSignalSurface.selectedBorderOpacity), lineWidth: 0.6)
            )
    }
}

struct LivingSignalToolbarSurfaceModifier: ViewModifier {
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: LivingSignalLayout.panelCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LivingSignalLayout.panelCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(LivingSignalSurface.borderOpacity), lineWidth: 0.6)
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

    func livingSignalRow(tone: LivingSignalTone = .neutral, padding: CGFloat = 0) -> some View {
        modifier(LivingSignalRowModifier(tone: tone, padding: padding))
    }

    func livingSignalSelectedSurface(cornerRadius: CGFloat = 8) -> some View {
        modifier(LivingSignalSelectedSurfaceModifier(cornerRadius: cornerRadius))
    }

    func livingSignalToolbarSurface(padding: CGFloat = 0) -> some View {
        modifier(LivingSignalToolbarSurfaceModifier(padding: padding))
    }

    func livingSignalPanelBackground() -> some View {
        background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        LivingSignalTone.active.color.opacity(LivingSignalSurface.windowSignalTintOpacity),
                        LivingSignalTone.uploadHeavy.color.opacity(LivingSignalSurface.windowUploadTintOpacity),
                        Color(nsColor: .windowBackgroundColor).opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
}
