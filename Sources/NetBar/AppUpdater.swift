import AppKit
import CommonCrypto
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
    let sha256: String?

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case browserDownloadURL = "browser_download_url"
        case sha256
    }

    init(
        name: String,
        size: Int,
        browserDownloadURL: URL,
        sha256: String? = nil
    ) {
        self.name = name
        self.size = size
        self.browserDownloadURL = browserDownloadURL
        self.sha256 = sha256
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

struct UpdateReleaseFetcher {
    typealias DataLoader = (URLRequest) async throws -> (Data, URLResponse)

    let repository: String
    let currentVersion: String
    let loadData: DataLoader

    init(
        repository: String,
        currentVersion: String,
        loadData: @escaping DataLoader = { request in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.urlCache = nil
            return try await URLSession(configuration: configuration).data(for: request)
        }
    ) {
        self.repository = repository
        self.currentVersion = currentVersion
        self.loadData = loadData
    }

    func fetchLatestRelease() async throws -> GitHubRelease {
        do {
            return try await fetchManifestRelease()
        } catch {
            guard isTransientFetchError(error) else { throw error }
            return try await fetchGitHubAPIRelease()
        }
    }

    private func fetchManifestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://github.com/\(repository)/releases/latest/download/latest.json") else {
            throw UpdateError.invalidUpdateURL
        }

        let (data, response) = try await loadData(manifestRequest(url: url))
        try validateHTTPResponse(response)
        let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: data)

        let assetURL = URL(string: manifest.assetURL)
            ?? URL(string: "https://github.com/\(repository)/releases/download/\(manifest.tag)/\(manifest.asset)")!
        let htmlURL = URL(string: manifest.htmlURL ?? "")
            ?? URL(string: "https://github.com/\(repository)/releases/tag/\(manifest.tag)")!

        let releaseAsset = GitHubReleaseAsset(
            name: manifest.asset,
            size: 0,
            browserDownloadURL: assetURL,
            sha256: manifest.sha256
        )
        return GitHubRelease(
            tagName: manifest.tag,
            name: nil,
            body: manifest.notes,
            htmlURL: htmlURL,
            assets: [releaseAsset]
        )
    }

    private func fetchGitHubAPIRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw UpdateError.invalidUpdateURL
        }

        let (data, response) = try await loadData(apiRequest(url: url))
        try validateHTTPResponse(response)
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func manifestRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }

    private func apiRequest(url: URL) -> URLRequest {
        var request = manifestRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateError.httpStatus(httpResponse.statusCode)
        }
    }

    private func isTransientFetchError(_ error: Error) -> Bool {
        if case UpdateError.httpStatus(let status) = error {
            return (500..<600).contains(status)
        }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
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
        GroupBox(appPreferences.text("更新内容", "What's New")) {
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

enum UpdateArchiveIntegrity {
    static func validate(fileURL: URL, expectedSHA256: String?) throws {
        guard let expected = expectedSHA256?.trimmingCharacters(in: .whitespacesAndNewlines),
              !expected.isEmpty else {
            return
        }

        let actual = try sha256Hex(for: fileURL)
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw UpdateError.checksumMismatch
        }
    }

    static func sha256Hex(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        while true {
            let data = handle.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else { break }
            data.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                CC_SHA256_Update(&context, baseAddress, CC_LONG(data.count))
            }
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
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
    private let releaseFetcher: UpdateReleaseFetcher
    private var automaticTimer: Timer?
    private var preparedAppURL: URL?
    private var updateWindow: NSWindow?

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main, appPreferences: AppPreferences) {
        self.defaults = defaults
        repository = bundle.object(forInfoDictionaryKey: "NBUpdateRepository") as? String ?? "sunnyhot/NetBar"
        assetName = bundle.object(forInfoDictionaryKey: "NBUpdateAssetName") as? String ?? "NetBar.app.zip"
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        currentBundleIdentifier = bundle.bundleIdentifier ?? "local.codex.NetBar"
        releaseFetcher = UpdateReleaseFetcher(repository: repository, currentVersion: currentVersion)
        automaticallyChecksForUpdates = defaults.object(forKey: Keys.automaticallyChecksForUpdates) as? Bool ?? true
        self.appPreferences = appPreferences
    }

    var currentVersionText: String {
        let trimmed = currentVersion.hasPrefix("v") ? String(currentVersion.dropFirst()) : currentVersion
        return "v\(trimmed)"
    }

    var diagnosticsStatusText: String {
        statusMessage
    }

    var diagnosticsBundleIdentifier: String {
        currentBundleIdentifier
    }

    var diagnosticsLastCheckedAt: Date? {
        lastCheckedAt
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

        // 1. Try to get latest tag via redirect first to bypass rate limits
        let latestTag = await fetchLatestTagViaRedirect()
        if let latestTag = latestTag {
            if !version(latestTag, isNewerThan: currentVersion) {
                lastCheckedAt = Date()
                availableUpdate = nil
                statusMessage = "当前已是最新版本 \(currentVersion)"
                isChecking = false
                return
            }
        }

        // 2. If there is a newer version (or redirect check failed), fetch the full release details
        do {
            let release: GitHubRelease
            do {
                release = try await fetchLatestRelease()
            } catch {
                // If API fails (e.g. rate limit), but we have a newer tag, construct a fallback release
                if let latestTag = latestTag {
                    let fallbackURL = URL(string: "https://github.com/\(repository)/releases/download/\(latestTag)/\(assetName)")!
                    let asset = GitHubReleaseAsset(name: assetName, size: 0, browserDownloadURL: fallbackURL)
                    release = GitHubRelease(
                        tagName: latestTag,
                        name: latestTag,
                        body: appPreferences.text(
                            "新版本已发布（因 GitHub API 限制，未能加载更新日志）",
                            "New version released (Changelog unavailable due to GitHub API rate limits)"
                        ),
                        htmlURL: URL(string: "https://github.com/\(repository)/releases/tag/\(latestTag)")!,
                        assets: [asset]
                    )
                } else {
                    throw error
                }
            }

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
            try UpdateArchiveIntegrity.validate(fileURL: downloadedZip, expectedSHA256: availableUpdate.asset.sha256)
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
            try UpdateArchiveIntegrity.validate(fileURL: downloadedZip, expectedSHA256: availableUpdate.asset.sha256)
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

    private func fetchLatestTagViaRedirect() async -> String? {
        guard let url = URL(string: "https://github.com/\(repository)/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("NetBar \(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               let finalURL = httpResponse.url {
                let tag = finalURL.lastPathComponent
                if !tag.isEmpty && tag != "latest" {
                    return tag
                }
            }
        } catch {
            // Ignore error
        }
        return nil
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        try await releaseFetcher.fetchLatestRelease()
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

        let executableName = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "NetBar"
        let executableURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent(executableName)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw UpdateError.codeSignatureInvalid
        }
        try validateExecutableArchitecture(executableURL)

        if !Self.codesignSucceeds(arguments: ["--verify", "--deep", "--strict", appURL.path]) {
            statusMessage = "App 包使用 SwiftPM 签名，将继续安装"
        }

        if normalizeVersion(downloadedVersion) != normalizeVersion(expectedVersion) {
            statusMessage = "版本号为 \(downloadedVersion)，将继续安装"
        }
    }

    private static func codesignSucceeds(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func validateExecutableArchitecture(_ executableURL: URL) throws {
        guard let currentArchitecture = Self.currentExecutableArchitecture else { return }
        let architectures = Self.executableArchitectures(at: executableURL)
        guard architectures.contains(currentArchitecture) else {
            throw UpdateError.incompatibleArchitecture(
                current: currentArchitecture,
                available: architectures.sorted()
            )
        }
    }

    private static var currentExecutableArchitecture: String? {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return nil
        #endif
    }

    private static func executableArchitectures(at executableURL: URL) -> Set<String> {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-archs", executableURL.path]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return Set(text.split(whereSeparator: \.isWhitespace).map(String.init))
        } catch {
            return []
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

        /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
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
    case incompatibleArchitecture(current: String, available: [String])
    case checksumMismatch

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
        case .incompatibleArchitecture(let current, let available):
            let availableText = available.isEmpty ? "未知架构" : available.joined(separator: ", ")
            return "下载的 App 不支持当前 Mac（需要 \(current)，安装包为 \(availableText)）"
        case .checksumMismatch:
            return "下载的安装包校验失败"
        }
    }
}
