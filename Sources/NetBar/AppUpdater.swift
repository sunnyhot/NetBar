import AppKit
import Foundation

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

struct AvailableUpdate: Equatable {
    let release: GitHubRelease
    let asset: GitHubReleaseAsset

    var versionText: String {
        release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

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
    private var automaticTimer: Timer?
    private var preparedAppURL: URL?

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        repository = bundle.object(forInfoDictionaryKey: "NBUpdateRepository") as? String ?? "sunnyhot/NetBar"
        assetName = bundle.object(forInfoDictionaryKey: "NBUpdateAssetName") as? String ?? "NetBar.app.zip"
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        currentBundleIdentifier = bundle.bundleIdentifier ?? "local.codex.NetBar"
        automaticallyChecksForUpdates = defaults.object(forKey: Keys.automaticallyChecksForUpdates) as? Bool ?? true
    }

    var currentVersionText: String {
        currentVersion
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

            if automaticallyChecksForUpdates {
                await autoDownloadAndPrepare()
            }
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

    // MARK: - Auto Download

    private func autoDownloadAndPrepare() async {
        guard let availableUpdate else { return }

        isDownloading = true
        downloadProgress = 0
        statusMessage = "正在自动下载更新..."

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

            showUpdateReadyAlert()
        } catch {
            isDownloading = false
            downloadProgress = 0
            statusMessage = "自动下载失败：\(error.localizedDescription)"
        }
    }

    private func showUpdateReadyAlert() {
        let version = availableUpdate?.versionText ?? ""
        let alert = NSAlert()
        alert.messageText = "新版本 \(version) 已下载完成"
        alert.informativeText = "需要重启 NetBar 以完成安装。"
        alert.addButton(withTitle: "安装并重启")
        alert.addButton(withTitle: "稍后提醒")
        alert.alertStyle = .informational

        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            try? installPreparedUpdate()
        }
    }

    private func installPreparedUpdate() throws {
        guard let preparedAppURL else { return }
        try installAndRelaunch(from: preparedAppURL)
    }

    // MARK: - Network

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw UpdateError.invalidUpdateURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
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

    private func download(asset: GitHubReleaseAsset) async throws -> URL {
        var request = URLRequest(url: asset.browserDownloadURL)
        request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        try validateHTTPResponse(response)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetBar-\(UUID().uuidString)")
            .appendingPathComponent(asset.name)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
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

        let appURL = destination.appendingPathComponent("NetBar.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw UpdateError.appMissingFromArchive
        }
        return appURL
    }

    private func validateDownloadedApp(_ appURL: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: appURL) else {
            throw UpdateError.invalidBundle
        }

        guard bundle.bundleIdentifier == currentBundleIdentifier else {
            throw UpdateError.bundleIdentifierMismatch
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
        case .httpStatus(let status):
            return "GitHub 返回 HTTP \(status)"
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
