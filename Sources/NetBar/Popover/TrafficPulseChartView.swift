import SwiftUI

struct TrafficPulseChartView: View {
    let presentation: TrafficHistoryWindowPresentationModel
    @Binding var selectedWindow: TrafficHistoryWindow
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        let isActive = presentation.peakDownloadBytesPerSecond > 0 || presentation.peakUploadBytesPerSecond > 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appPreferences.text("实时信号", "Realtime Signal"))
                        .font(.system(size: 13, weight: .bold))
                    Text(appPreferences.text(
                        "最近 \(selectedWindow.title(language: appPreferences.resolvedLanguage)) 下载 / 上传",
                        "Last \(selectedWindow.title(language: appPreferences.resolvedLanguage)) down / up"
                    ))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Picker("", selection: $selectedWindow) {
                    ForEach(TrafficHistoryWindow.allCases) { window in
                        Text(window.title(language: appPreferences.resolvedLanguage)).tag(window)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            GeometryReader { geometry in
                ZStack {
                    chartWellBackground

                    TrafficPulseGrid()

                    TrafficPulseLine(
                        normalizedValues: presentation.normalizedUploadValues,
                        size: geometry.size,
                        color: LivingSignalTone.uploadHeavy.color
                    )
                    TrafficPulseLine(
                        normalizedValues: presentation.normalizedDownloadValues,
                        size: geometry.size,
                        color: LivingSignalTone.active.color
                    )

                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            TrafficPulseLegendDot(
                                title: appPreferences.text("下载", "Down"),
                                color: LivingSignalTone.active.color
                            )
                            TrafficPulseLegendDot(
                                title: appPreferences.text("上传", "Up"),
                                color: LivingSignalTone.uploadHeavy.color
                            )
                            Spacer()
                            Text("\(presentation.points.count) pts")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(height: LivingSignalLayout.chartHeight)
        }
        .livingSignalPanel(tone: isActive ? .active : .idle, isElevated: true, padding: 12)
    }

    private var chartWellBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.54))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(LivingSignalSurface.borderOpacity), lineWidth: 0.6)
            )
    }
}

private struct TrafficPulseGrid: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 0.5)
                Spacer()
            }
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

private struct TrafficPulseLegendDot: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct TrafficPulseLine: View {
    let normalizedValues: [Double]
    let size: CGSize
    let color: Color

    var body: some View {
        ZStack {
            filledPath
                .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            linePath
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var linePath: Path {
        Path { path in
            guard normalizedValues.count > 1 else { return }
            let step = size.width / CGFloat(normalizedValues.count - 1)
            for index in normalizedValues.indices {
                let x = CGFloat(index) * step
                let y = size.height - (CGFloat(normalizedValues[index]) * (size.height - 12)) - 6
                if index == normalizedValues.startIndex {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private var filledPath: Path {
        Path { path in
            guard normalizedValues.count > 1 else { return }
            let step = size.width / CGFloat(normalizedValues.count - 1)
            for index in normalizedValues.indices {
                let x = CGFloat(index) * step
                let y = size.height - (CGFloat(normalizedValues[index]) * (size.height - 12)) - 6
                if index == normalizedValues.startIndex {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.addLine(to: CGPoint(x: CGFloat(normalizedValues.count - 1) * step, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }
}
