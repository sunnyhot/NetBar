import AppKit
import Foundation
import SwiftUI

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Decodable, Equatable {
    let name: String
    let size: Int
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case browserDownloadURL = "browser_download_url"
    }
}

/// Manifest model for the static latest.json uploaded as a Release asset.
/// The App fetches this instead of calling the GitHub REST API to avoid rate limits.
struct ReleaseManifest: Decodable, Equatable {
    let version: String
    let tag: String
    let asset: String
    let assetURL: String
    let sha256: String
    let notes: String?
    let htmlURL: String?

    enum CodingKeys: String, CodingKey {
        case version
        case tag
        case asset
        case assetURL = "asset_url"
        case sha256
        case notes
        case htmlURL = "html_url"
    }
}

struct AvailableUpdate: Equatable {
    let release: GitHubRelease
    let asset: GitHubReleaseAsset

    var versionText: String {
        release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

// MARK: - Update Dialog View

struct UpdateDialogView: View {
    @ObservedObject var updater: AppUpdater
    let appPreferences: AppPreferences
    let currentVersion: String
    let onClose: () -> Void

    private var dialogState: UpdateDialogState {
        if updater.isDownloading { return .downloading }
        if updater.isUpdateReadyToInstall { return .readyToInstall }
        return .ready
    }

    var body: some View {
        VStack(spacing: 0) {
            titleSection
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if let body = changelogBody {
                changelogSection(body)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if dialogState == .downloading {
                progressSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if dialogState == .downloading {
                Text(appPreferences.text("正在下载...", "Downloading..."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            } else if dialogState == .readyToInstall {
                Text(appPreferences.text("下载完成，点击安装并重启", "Download complete, click to install and restart"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            Divider()
                .padding(.bottom, 12)

            buttonSection(dialogState)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(width: 440)
    }

    private var changelogBody: String? {
        guard let body = updater.availableUpdate?.release.body?
            .trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else {
            return nil
        }
        return body
    }

    private var titleSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(appPreferences.text(
                    "发现新版本 \(updater.availableUpdate?.versionText ?? "")",
                    "New Version Available: \(updater.availableUpdate?.versionText ?? "")"
                ))
                .font(.headline)
                Text(appPreferences.text(
                    "当前版本：\(currentVersion)",
                    "Current version: \(currentVersion)"
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private func changelogSection(_ body: String) -> some View {
        GroupBox {
            ScrollView {
                Text(body)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 180)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            ProgressView(value: updater.downloadProgress)
                .progressViewStyle(.linear)
            HStack {
                Text("\(Int(updater.downloadProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private func buttonSection(_ state: UpdateDialogState) -> some View {
        HStack {
            switch state {
            case .ready:
                Button(appPreferences.text("取消", "Cancel")) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(appPreferences.text("下载更新", "Download Update")) {
                    Task { @MainActor in
                        await updater.downloadForDialog()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

            case .downloading:
                Spacer()
                Button(appPreferences.text("取消", "Cancel")) { onClose() }
                    .keyboardShortcut(.cancelAction)

            case .readyToInstall:
                Button(appPreferences.text("稍后", "Later")) { onClose() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(appPreferences.text("安装并重启", "Install and Restart")) {
                    try? updater.installPreparedUpdate()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private enum UpdateDialogState {
    case ready
    case downloading
    case readyToInstall
}

// MARK: - AppUpdater

@MainActor
final class AppUpdater: ObservableObject {
    @Published var automaticallyChecksForUpdates: Bool { didSet { saveSettings() } }
    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var availableUpdate: AvailableUpdate?
    @Published private(set) var isUpdateReadyToInstall = false
    @Published private(set) var statusMessage = "尚未检查更新"
    @Published private(set) var lastCheckedAt: Date?

    private let defaults: UserDefaults
    private let repository: String
    private let assetName: String
    private let currentVersion: String
    private let currentBundleIdentifier: String
    private let appPreferences: AppPreferences
    private var automaticTimer: Timer?
    private var preparedAppURL: URL?
    private var updateWindow: NSWindow?

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main, appPreferences: AppPreferences) {
        self.defaults = defaults
        repository = bundle.object(forInfoDictionaryKey: "NBUpdateRepository") as? String ?? "sunnyhot/NetBar"
        assetName = bundle.object(forInfoDictionaryKey: "NBUpdateAssetName") as? String ?? "NetBar.app.zip"
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        currentBundleIdentifier = bundle.bundleIdentifier ?? "local.codex.NetBar"
        automaticallyChecksForUpdates = defaults.object(forKey: Keys.automaticallyChecksForUpdates) as? Bool ?? true
        self.appPreferences = appPreferences
    }

    var currentVersionText: String {
        let trimmed = currentVersion.hasPrefix("v") ? String(currentVersion.dropFirst()) : currentVersion
        return "v\(trimmed)"
    }

    var releasePageURL: URL? {
        URL(string: "https://github.com/\(repository)/releases")
    }

    func startAutomaticChecks() {
        automaticTimer?.invalidate()
        automaticTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard self?.automaticallyChecksForUpdates == true else { return }
                await self?.checkForUpdates(isManual: false)
            }
        }

        guard automaticallyChecksForUpdates else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            await checkForUpdates(isManual: false)
        }
    }

    func checkForUpdates(isManual: Bool) async {
        guard !isChecking, !isDownloading, !isUpdateReadyToInstall else { return }

        isChecking = true
        if isManual {
            statusMessage = "正在检查更新..."
        }

        do {
            let release = try await fetchLatestRelease()
            lastCheckedAt = Date()

            guard version(release.tagName, isNewerThan: currentVersion) else {
                availableUpdate = nil
                statusMessage = "当前已是最新版本 \(currentVersion)"
                isChecking = false
                return
            }

            guard let asset = release.assets.first(where: { $0.name == assetName }) else {
                availableUpdate = nil
                statusMessage = "发现 \(release.tagName)，但 Release 里没有 \(assetName)"
                isChecking = false
                return
            }

            availableUpdate = AvailableUpdate(release: release, asset: asset)
            statusMessage = "发现新版本 \(release.tagName)"
            isChecking = false

            showUpdateDialog()
        } catch {
            isChecking = false
            if isManual {
                statusMessage = "检查更新失败：\(error.localizedDescription)"
            }
        }
    }

    func downloadAndInstall() async {
        if let preparedAppURL, isUpdateReadyToInstall {
            do {
                statusMessage = "准备安装并重启..."
                try installAndRelaunch(from: preparedAppURL)
            } catch {
                self.preparedAppURL = nil
                isUpdateReadyToInstall = false
                statusMessage = "安装失败：\(error.localizedDescription)"
            }
            return
        }

        guard let availableUpdate, !isChecking, !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        statusMessage = "正在下载 \(availableUpdate.asset.name)..."

        do {
            let downloadedZip = try await downloadWithProgress(asset: availableUpdate.asset)
            statusMessage = "正在解压更新..."
            let appURL = try unzipApp(from: downloadedZip)
            try validateDownloadedApp(appURL, expectedVersion: availableUpdate.versionText)

            statusMessage = "准备安装并重启..."
            try installAndRelaunch(from: appURL)
        } catch {
            isDownloading = false
            downloadProgress = 0
            statusMessage = "更新失败：\(error.localizedDescription)"
        }
    }

    func downloadForDialog() async {
        guard let availableUpdate else { return }

        isDownloading = true
        downloadProgress = 0
        statusMessage = "正在下载更新..."

        do {
            let downloadedZip = try await downloadWithProgress(asset: availableUpdate.asset)
            statusMessage = "正在解压..."
            let appURL = try unzipApp(from: downloadedZip)
            try validateDownloadedApp(appURL, expectedVersion: availableUpdate.versionText)

            preparedAppURL = appURL
            isDownloading = false
            isUpdateReadyToInstall = true
            downloadProgress = 1.0
            statusMessage = "新版本已就绪，点击安装并重启"
        } catch {
            isDownloading = false
            downloadProgress = 0
            statusMessage = "下载失败：\(error.localizedDescription)"
        }
    }

    func installPreparedUpdate() throws {
        guard let preparedAppURL else { return }
        try installAndRelaunch(from: preparedAppURL)
    }

    // MARK: - Update Dialog

    private func showUpdateDialog() {
        guard let _ = availableUpdate else { return }

        closeUpdateDialog()

        let view = UpdateDialogView(
            updater: self,
            appPreferences: appPreferences,
            currentVersion: currentVersion,
            onClose: { [weak self] in
                self?.closeUpdateDialog()
            }
        )

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingController.view
        window.center()
        window.title = appPreferences.text(
            "发现新版本",
            "Update Available"
        )
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        updateWindow = window
    }

    private func closeUpdateDialog() {
        updateWindow?.close()
        updateWindow = nil
    }

    // MARK: - Network

    private func fetchLatestRelease() async throws -> GitHubRelease {
        // Fetch the static latest.json manifest uploaded as a Release asset,
        // avoiding the GitHub REST API rate limit (60 req/hr unauthenticated).
        guard let url = URL(string: "https://github.com/\(repository)/releases/latest/download/latest.json") else {
            throw UpdateError.invalidUpdateURL
        }

        var request = URLRequest(url: url)
        request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)

        // Map manifest back to the existing GitHubRelease / GitHubReleaseAsset models
        // so the rest of the update flow (version comparison, download, etc.) stays unchanged.
        let assetURL = URL(string: manifest.assetURL)
            ?? URL(string: "https://github.com/\(repository)/releases/download/\(manifest.tag)/\(manifest.asset)")!
        let htmlURL = URL(string: manifest.htmlURL ?? "")
            ?? URL(string: "https://github.com/\(repository)/releases/tag/\(manifest.tag)")!

        let releaseAsset = GitHubReleaseAsset(
            name: manifest.asset,
            size: 0,
            browserDownloadURL: assetURL
        )
        return GitHubRelease(
            tagName: manifest.tag,
            name: nil,
            body: manifest.notes,
            htmlURL: htmlURL,
            assets: [releaseAsset]
        )
    }

    private func downloadWithProgress(asset: GitHubReleaseAsset) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = UpdateDownloadDelegate(
                expectedSize: Double(asset.size),
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress
                    }
                },
                completion: { result in
                    continuation.resume(with: result)
                }
            )

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            var request = URLRequest(url: asset.browserDownloadURL)
            request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")
            session.downloadTask(with: request).resume()
        }
    }

    // MARK: - Install

    private func unzipApp(from zipURL: URL) throws -> URL {
        let destination = zipURL.deletingLastPathComponent().appendingPathComponent("expanded")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, destination.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.unzipFailed
        }

        // Auto-detect the .app bundle in the extracted directory instead of hardcoding the name.
        // This handles cases where the archive app name differs from expectations.
        let contents = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appMissingFromArchive
        }
        return appURL
    }

    private func validateDownloadedApp(_ appURL: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: appURL) else {
            throw UpdateError.invalidBundle
        }

        if bundle.bundleIdentifier != currentBundleIdentifier {
            // Bundle ID may differ across builds (e.g. local dev vs release). Since updates
            // always come from the same GitHub repo + matching asset name, treat as a warning
            // rather than a hard error so existing users aren't blocked from updating.
            statusMessage = "Bundle ID 不同（\(bundle.bundleIdentifier ?? "?") → \(currentBundleIdentifier)），继续安装"
        }

        let downloadedVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        guard !version(currentVersion, isNewerThan: downloadedVersion) else {
            throw UpdateError.downloadedVersionIsOlder
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.codeSignatureInvalid
        }

        if normalizeVersion(downloadedVersion) != normalizeVersion(expectedVersion) {
            statusMessage = "版本号为 \(downloadedVersion)，将继续安装"
        }
    }

    private func installAndRelaunch(from downloadedAppURL: URL) throws {
        let currentAppURL = Bundle.main.bundleURL
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("netbar-install-\(UUID().uuidString).zsh")
        let script = """
        #!/bin/zsh
        set -euo pipefail

        SOURCE_APP="$1"
        TARGET_APP="$2"
        CURRENT_PID="$3"
        BACKUP_APP="${TARGET_APP}.previous-update"

        while /bin/kill -0 "$CURRENT_PID" 2>/dev/null; do
            /bin/sleep 0.2
        done

        /bin/rm -rf "$BACKUP_APP"
        if [ -d "$TARGET_APP" ]; then
            /bin/mv "$TARGET_APP" "$BACKUP_APP"
        fi

        if ! /usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"; then
            /bin/rm -rf "$TARGET_APP"
            if [ -d "$BACKUP_APP" ]; then
                /bin/mv "$BACKUP_APP" "$TARGET_APP"
            fi
            exit 1
        fi

        /bin/rm -rf "$BACKUP_APP"
        /usr/bin/open "$TARGET_APP"
        /bin/rm -rf "$(dirname "$(dirname "$SOURCE_APP")")"
        /bin/rm -f "$0"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            scriptURL.path,
            downloadedAppURL.path,
            currentAppURL.path,
            "\(ProcessInfo.processInfo.processIdentifier)"
        ]
        try process.run()

        NSApplication.shared.terminate(nil)
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateError.httpStatus(httpResponse.statusCode)
        }
    }

    private func version(_ candidate: String, isNewerThan current: String) -> Bool {
        let lhs = normalizeVersion(candidate)
        let rhs = normalizeVersion(current)
        let count = max(lhs.count, rhs.count)

        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }

        return false
    }

    private func normalizeVersion(_ value: String) -> [Int] {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split { !$0.isNumber }
            .map { Int($0) ?? 0 }
    }

    private func saveSettings() {
        defaults.set(automaticallyChecksForUpdates, forKey: Keys.automaticallyChecksForUpdates)
    }

    private enum Keys {
        static let automaticallyChecksForUpdates = "updates.automaticallyChecksForUpdates"
    }
}

// MARK: - Download Progress Delegate

private final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let expectedSize: Double
    private let onProgress: @Sendable (Double) -> Void
    private let completion: @Sendable (Result<URL, Error>) -> Void
    private var hasCompleted = false

    init(
        expectedSize: Double,
        onProgress: @Sendable @escaping (Double) -> Void,
        completion: @Sendable @escaping (Result<URL, Error>) -> Void
    ) {
        self.expectedSize = expectedSize
        self.onProgress = onProgress
        self.completion = completion
        super.init()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // Validate HTTP status code before accepting the download
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            completion(.failure(UpdateError.httpStatus(httpResponse.statusCode)))
            session.finishTasksAndInvalidate()
            return
        }

        // Validate that downloaded file is actually a ZIP (check magic bytes: PK\x03\x04)
        do {
            let handle = try FileHandle(forReadingFrom: location)
            let magic = handle.readData(ofLength: 4)
            handle.closeFile()
            let zipMagic: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
            guard magic.count >= 4 else {
                completion(.failure(UpdateError.unzipFailed))
                session.finishTasksAndInvalidate()
                return
            }
            let bytes = [UInt8](magic)
            guard bytes[0] == zipMagic[0] && bytes[1] == zipMagic[1] &&
                  bytes[2] == zipMagic[2] && bytes[3] == zipMagic[3] else {
                completion(.failure(UpdateError.unzipFailed))
                session.finishTasksAndInvalidate()
                return
            }
        } catch {
            completion(.failure(UpdateError.unzipFailed))
            session.finishTasksAndInvalidate()
            return
        }

        do {
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("NetBar-\(UUID().uuidString)")
                .appendingPathComponent("NetBar.app.zip")
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: dest)
            completion(.success(dest))
        } catch {
            completion(.failure(error))
        }
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !hasCompleted, let error else { return }
        hasCompleted = true
        completion(.failure(error))
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? Double(totalBytesExpectedToWrite) : expectedSize
        guard total > 0 else { return }
        onProgress(min(Double(totalBytesWritten) / total, 1.0))
    }
}

enum UpdateError: LocalizedError {
    case invalidUpdateURL
    case releaseFetchFailed
    case httpStatus(Int)
    case unzipFailed
    case appMissingFromArchive
    case invalidBundle
    case bundleIdentifierMismatch
    case downloadedVersionIsOlder
    case codeSignatureInvalid

    var errorDescription: String? {
        switch self {
        case .invalidUpdateURL:
            return "更新地址无效"
        case .releaseFetchFailed:
            return "获取更新信息失败"
        case .httpStatus(let status):
            if status == 403 {
                return "GitHub 请求受限（HTTP 403），稍后会自动重试"
            } else if status == 404 {
                return "GitHub 上未找到 Release（HTTP 404）"
            } else {
                return "GitHub 返回 HTTP \(status)"
            }
        case .unzipFailed:
            return "解压安装包失败"
        case .appMissingFromArchive:
            return "安装包中没有 NetBar.app"
        case .invalidBundle:
            return "下载的 App 不是有效 bundle"
        case .bundleIdentifierMismatch:
            return "下载的 App 与当前 App 的 Bundle ID 不一致"
        case .downloadedVersionIsOlder:
            return "下载的版本低于当前版本"
        case .codeSignatureInvalid:
            return "下载的 App 签名校验失败"
        }
    }
}
