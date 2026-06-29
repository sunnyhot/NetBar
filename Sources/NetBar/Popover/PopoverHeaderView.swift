import SwiftUI

struct PopoverHeaderView: View {
    let presentation: LivingSignalStatusPresentation
    let snapshot: NetworkSnapshot
    @ObservedObject var appPreferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        let policy = LivingSignalMotionPolicy.make(
            reduceMotion: reduceMotion,
            windowVisible: true,
            isActive: presentation.tone != .idle
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: LivingSignalLayout.iconTileSize, height: LivingSignalLayout.iconTileSize)
                    .background(presentation.tone.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(
                        color: presentation.tone.color.opacity(policy.pulseOpacity),
                        radius: isPulsing ? 12 : 4,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isPulsing ? policy.pulseScale : 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(presentation.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                LivingSignalStatusChip(text: presentation.totalSpeed, tone: presentation.tone)
            }

            HStack(spacing: 8) {
                LivingSignalSpeedMetric(
                    title: appPreferences.text("下载", "Download"),
                    value: ByteFormat.speed(snapshot.downloadBytesPerSecond),
                    symbolName: "arrow.down",
                    tone: .active
                )
                LivingSignalSpeedMetric(
                    title: appPreferences.text("上传", "Upload"),
                    value: ByteFormat.speed(snapshot.uploadBytesPerSecond),
                    symbolName: "arrow.up",
                    tone: snapshot.uploadBytesPerSecond > snapshot.downloadBytesPerSecond ? .uploadHeavy : .neutral
                )
                LivingSignalSpeedMetric(
                    title: appPreferences.text("接口", "Interface"),
                    value: presentation.interfaceName,
                    symbolName: "antenna.radiowaves.left.and.right",
                    tone: .neutral
                )
            }
        }
        .livingSignalPanel(tone: presentation.tone, isElevated: true, padding: 14)
        .onAppear {
            guard policy.allowsLoopingEffects else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

struct LivingSignalStatusChip: View {
    let text: String
    let tone: LivingSignalTone

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.softColor, in: Capsule())
            .overlay(Capsule().strokeBorder(tone.color.opacity(0.22), lineWidth: 0.7))
    }
}

private struct LivingSignalSpeedMetric: View {
    let title: String
    let value: String
    let symbolName: String
    let tone: LivingSignalTone

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tone.color)
                .frame(width: 18, height: 18)
                .background(tone.softColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .livingSignalPanel(tone: tone)
    }
}
