import SwiftUI

struct StatusBarPopoverContentView: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences
    let openMainWindow: () -> Void
    let openPreferences: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with speed info
            HStack(spacing: 12) {
                // Download speed
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        Text(appPreferences.text("下载", "Down"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(ByteFormat.speed(monitor.snapshot.downloadBytesPerSecond))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Divider()
                    .frame(height: 32)

                // Upload speed
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text(appPreferences.text("上传", "Up"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(ByteFormat.speed(monitor.snapshot.uploadBytesPerSecond))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    openMainWindow()
                } label: {
                    Label(appPreferences.text("打开主界面", "Open Main Window"), systemImage: "square.grid.2x2")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    openPreferences()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help(appPreferences.text("偏好设置", "Preferences"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
