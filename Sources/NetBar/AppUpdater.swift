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

    var changelog: String? {
        guard let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else {
            return nil
        }
        return body
    }

    var downloadURL: URL {
        asset.browserDownloadURL
    }

    var fileSize: Int? {
        asset.size > 0 ? asset.size : nil
    }
}

enum UpdatePromptAction: Equatable {
    case downloadAndInstall
    case openReleasePage
    case remindLater

    static func response(forButtonIndex index: Int) -> UpdatePromptAction? {
        switch index {
        case 0:
            return .downloadAndInstall
        case 1:
            return .openReleasePage
        case 2:
            return .remindLater
        default:
            return nil
        }
    }

    static func response(forModalResponse response: NSApplication.ModalResponse) -> UpdatePromptAction? {
        switch response {
        case .alertFirstButtonReturn:
            return .downloadAndInstall
        case .alertSecondButtonReturn:
            return .openReleasePage
        case .alertThirdButtonReturn:
            return .remindLater
        default:
            return nil
        }
    }
}

struct UpdatePromptContent: Equatable {
    let messageText: String
    let informativeText: String
    let buttonTitles: [String]
    let releaseNotesText: String?

    static func make(
        for update: AvailableUpdate,
        currentVersion: String,
        automaticCheck: Bool
    ) -> UpdatePromptContent {
        let version = update.versionText
        let releaseName = update.release.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let releaseNotes = update.release.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let assetLine = update.asset.size > 0
            ? "安装包：\(update.asset.name)（\(ByteFormat.bytes(UInt64(update.asset.size)))）"
            : "安装包：\(update.asset.name)"

        var lines = [
            automaticCheck ? "NetBar 自动检测到可用更新。" : "NetBar 检测到可用更新。",
            "当前版本：\(currentVersion)",
            "最新版本：\(version)",
            assetLine
        ]

        if let releaseName, !releaseName.isEmpty, releaseName != version {
            lines.append("版本名称：\(releaseName)")
        }

        lines.append("你可以立即下载并安装，也可以先打开 Release 页面查看详情。")

        return UpdatePromptContent(
            messageText: "发现新版本 \(version)",
            informativeText: lines.joined(separator: "\n"),
            buttonTitles: ["下载并安装", "查看 Release 页面", "稍后提醒"],
            releaseNotesText: releaseNotes?.isEmpty == false ? releaseNotes : nil
        )
    }
}

enum GitHubLatestReleaseLookup {
    static func request(repository: String, currentVersion: String) throws -> URLRequest {
        guard let url = URL(string: "https://github.com/\(repository)/releases/latest") else {
            throw UpdateError.invalidUpdateURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        return request
    }

    static func release(from responseURL: URL?, repository: String, assetName: String) throws -> GitHubRelease {
        guard
            let tagName = tagName(from: responseURL),
            let htmlURL = URL(string: "https://github.com/\(repository)/releases/tag/\(tagName)"),
            let assetURL = URL(string: "https://github.com/\(repository)/releases/download/\(tagName)/\(assetName)")
        else {
            throw UpdateError.latestReleaseRedirectMissing
        }

        return GitHubRelease(
            tagName: tagName,
            name: nil,
            body: nil,
            htmlURL: htmlURL,
            assets: [
                GitHubReleaseAsset(
                    name: assetName,
                    size: 0,
                    browserDownloadURL: assetURL
                )
            ]
        )
    }

    private static func tagName(from responseURL: URL?) -> String? {
        guard let responseURL else { return nil }
        let pathComponents = responseURL.pathComponents
        guard
            let tagIndex = pathComponents.firstIndex(of: "tag"),
            pathComponents.indices.contains(pathComponents.index(after: tagIndex))
        else {
            return nil
        }
        return pathComponents[pathComponents.index(after: tagIndex)]
    }
}

@MainActor
final class AppUpdater: ObservableObject {
    @Published var automaticallyChecksForUpdates: Bool { didSet { saveSettings() } }
    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var downloadError: Error?
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

            showUpdateInfoDialog(automaticCheck: !isManual)
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
        downloadError = nil
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
            downloadError = error
            statusMessage = "更新失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Auto Download

    private func autoDownloadAndPrepare() async {
        guard let availableUpdate else { return }

        isDownloading = true
        downloadError = nil
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
            downloadError = error
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

    private func showUpdateInfoDialog(automaticCheck: Bool) {
        guard let update = availableUpdate else { return }
        let prompt = UpdatePromptContent.make(
            for: update,
            currentVersion: currentVersion,
            automaticCheck: automaticCheck
        )

        let alert = NSAlert()
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        alert.alertStyle = .informational
        prompt.buttonTitles.forEach { alert.addButton(withTitle: $0) }

        if let releaseNotes = prompt.releaseNotesText {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
            textView.string = releaseNotes
            textView.isEditable = false
            textView.isSelectable = true
            textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .textColor
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            scrollView.documentView = textView
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            alert.accessoryView = scrollView
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch UpdatePromptAction.response(forModalResponse: response) {
        case .downloadAndInstall:
            Task { @MainActor in
                await downloadAndInstall()
            }
        case .openReleasePage:
            NSWorkspace.shared.open(update.release.htmlURL)
        case .remindLater, nil:
            break
        }
    }

    private func installPreparedUpdate() throws {
        guard let preparedAppURL else { return }
        try installAndRelaunch(from: preparedAppURL)
    }

    // MARK: - Network

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(repository)/releases/latest"
        guard let url = URL(string: urlString) else {
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
    case latestReleaseRedirectMissing
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
        case .latestReleaseRedirectMissing:
            return "无法解析 GitHub 最新版本地址"
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
