import SwiftUI

enum InterfacePresentation {
    static func iconName(for interfaceName: String) -> String {
        let name = interfaceName.lowercased()
        if name.hasPrefix("en") && !name.contains("bridge") {
            return "wifi"
        }
        if name.hasPrefix("bridge") {
            return "network.badge.shieldbell.fill"
        }
        if name.hasPrefix("lo") {
            return "arrow.triangle.2.circlepath"
        }
        if name.hasPrefix("utun") || name.hasPrefix("awdl") {
            return "antenna.radiowaves.left.and.right"
        }
        return "network"
    }
}

enum NetBarTone: Equatable {
    case download
    case upload
    case neutral
    case success
    case warning
    case purple
    case danger

    var color: Color {
        switch self {
        case .download:
            return .blue
        case .upload:
            return .orange
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .purple:
            return .purple
        case .danger:
            return .red
        }
    }

    var softColor: Color {
        color.opacity(0.12)
    }

    var gradient: LinearGradient {
        switch self {
        case .download:
            return LinearGradient(
                colors: [Color(red: 0.17, green: 0.47, blue: 0.98), Color(red: 0.14, green: 0.74, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .upload:
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.46, blue: 0.16), Color(red: 0.98, green: 0.69, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            return LinearGradient(
                colors: [Color.secondary.opacity(0.42), Color.secondary.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .success:
            return LinearGradient(
                colors: [Color.green, Color.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warning:
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .purple:
            return LinearGradient(
                colors: [Color.purple, Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .danger:
            return LinearGradient(
                colors: [Color.red, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

enum NetBarMotion {
    static let quick = Animation.easeOut(duration: 0.16)
    static let settle = Animation.spring(response: 0.28, dampingFraction: 0.86)
}

struct NetBarSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 10)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct NetBarBadge: View {
    let text: String
    var tone: NetBarTone = .neutral

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tone.softColor, in: Capsule())
            .overlay(Capsule().strokeBorder(tone.color.opacity(0.18), lineWidth: 0.5))
    }
}

struct NetBarIconTile: View {
    let systemName: String
    var tone: NetBarTone
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tone.gradient, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .shadow(color: tone.color.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

struct NetBarIconButtonStyle: ButtonStyle {
    var tone: NetBarTone = .neutral

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tone == .neutral ? Color.secondary : tone.color)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? tone.softColor.opacity(1.4) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.055), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(NetBarMotion.quick, value: configuration.isPressed)
    }
}

struct NetBarCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 0
    var isProminent = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(isProminent ? Color.primary.opacity(0.035) : Color(nsColor: .controlBackgroundColor).opacity(0.72))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.6)
            )
    }
}

extension View {
    func netBarCard(cornerRadius: CGFloat = 12, padding: CGFloat = 0, isProminent: Bool = false) -> some View {
        modifier(NetBarCardModifier(cornerRadius: cornerRadius, padding: padding, isProminent: isProminent))
    }

    func netBarPanelBackground() -> some View {
        livingSignalPanelBackground()
    }
}
