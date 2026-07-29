import CommonCrypto
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
    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

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
