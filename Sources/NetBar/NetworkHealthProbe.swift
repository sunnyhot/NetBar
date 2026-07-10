import Foundation

/// The typed outcome of a single active diagnostic attempt. Cancellation due to
/// sleep, lock, disabling the setting, or coordinator shutdown is `.cancelled`
/// and must not be counted as a failed network attempt.
enum NetworkHealthProbeOutcome: Equatable {
    /// Reference target reached. Any HTTP response proves reachability; the
    /// status code does not represent NetBar health.
    case success(dnsDurationMS: Double, responseLatencyMS: Double)
    /// DNS resolution failed or timed out.
    case dnsFailure
    /// The request exceeded its timeout budget.
    case timeout
    /// The transport connected but the request failed for other reasons.
    case transportFailure
    /// The attempt was cancelled (sleep, lock, disable, shutdown).
    case cancelled
}

/// A timestamped probe sample stored in the coordinator's rolling window.
struct NetworkHealthProbeSample: Equatable {
    let outcome: NetworkHealthProbeOutcome
    let timestamp: Date

    var isFailure: Bool {
        switch outcome {
        case .success:
            return false
        case .dnsFailure, .timeout, .transportFailure:
            return true
        case .cancelled:
            return false
        }
    }
}

/// Injectable protocol for one active diagnostic attempt. Tests replace this
/// with a mock that replays canned outcomes.
protocol NetworkHealthProbing: AnyObject {
    func performProbe(now: Date) async -> NetworkHealthProbeSample
}

/// System implementation. Reuses the GitHub origin NetBar already contacts for
/// update metadata — no new third-party diagnostics provider is introduced.
///
/// Each attempt:
/// 1. Times a system DNS resolution for the reference host.
/// 2. Issues an ephemeral HTTPS HEAD request with a short timeout.
/// 3. Times until a valid HTTP response is received.
///
/// The ephemeral session persists no cookies, credentials, or URL cache. The
/// request includes no NetBar-collected traffic or application data.
final class LiveNetworkHealthProbe: NetworkHealthProbing {
    private let referenceHost: String
    private let referenceURL: URL
    private let session: URLSession
    private let dnsResolver: (String) async -> TimeInterval?

    /// Total request budget. Generous enough for a real round trip, short
    /// enough that a hung connection surfaces as `.timeout` promptly.
    private let timeoutInterval: TimeInterval = 8

    init(bundle: Bundle = .main) {
        let repository = bundle.object(forInfoDictionaryKey: "NBUpdateRepository") as? String ?? "sunnyhot/NetBar"
        // The repository string is "owner/repo"; the reference host is github.com.
        let host: String
        if let firstSlash = repository.firstIndex(of: "/") {
            let owner = String(repository[repository.startIndex..<firstSlash])
            host = "github.com"
            _ = owner // owner currently unused; reserved for future per-repo probes
        } else {
            host = "github.com"
        }
        referenceHost = host
        referenceURL = URL(string: "https://\(host)/") ?? URL(string: "https://github.com/")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
        dnsResolver = { await Self.measureDNS(host: $0) }
    }

    func performProbe(now: Date) async -> NetworkHealthProbeSample {
        let dnsStart = Date()
        let dnsDuration = await dnsResolver(referenceHost)
        let dnsElapsed = Date().timeIntervalSince(dnsStart) * 1000

        // DNS resolution never produced an address.
        guard let dnsDuration else {
            return await timedFailure(now: now, dnsDurationMS: dnsElapsed)
        }

        return await performRequest(dnsDurationMS: dnsDuration, now: now)
    }

    private func performRequest(dnsDurationMS: Double, now: Date) async -> NetworkHealthProbeSample {
        var request = URLRequest(url: referenceURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutInterval)
        request.httpMethod = "HEAD"
        // Match AppUpdater's user agent so the reference host sees a consistent client.
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        request.setValue("NetBar \(version)", forHTTPHeaderField: "User-Agent")

        do {
            let requestStart = Date()
            let (_, response) = try await session.data(for: request)
            let latency = Date().timeIntervalSince(requestStart) * 1000
            // Any HTTP response proves reference reachability; status code is not health.
            guard response is HTTPURLResponse else {
                return NetworkHealthProbeSample(outcome: .transportFailure, timestamp: now)
            }
            return NetworkHealthProbeSample(outcome: .success(dnsDurationMS: dnsDurationMS, responseLatencyMS: latency), timestamp: now)
        } catch is CancellationError {
            return NetworkHealthProbeSample(outcome: .cancelled, timestamp: now)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                return NetworkHealthProbeSample(outcome: .timeout, timestamp: now)
            case .cancelled:
                return NetworkHealthProbeSample(outcome: .cancelled, timestamp: now)
            case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost:
                // Expected DNS/connection failures with a satisfied local path produce
                // fluctuating/poor; they never produce offline on their own.
                if urlError.code == .cannotFindHost || urlError.code == .dnsLookupFailed {
                    return NetworkHealthProbeSample(outcome: .dnsFailure, timestamp: now)
                }
                return NetworkHealthProbeSample(outcome: .transportFailure, timestamp: now)
            default:
                return NetworkHealthProbeSample(outcome: .transportFailure, timestamp: now)
            }
        } catch {
            return NetworkHealthProbeSample(outcome: .transportFailure, timestamp: now)
        }
    }

    private func timedFailure(now: Date, dnsDurationMS: Double) async -> NetworkHealthProbeSample {
        // DNS resolution failed outright; classify as dnsFailure regardless of elapsed time.
        _ = dnsDurationMS
        return NetworkHealthProbeSample(outcome: .dnsFailure, timestamp: now)
    }

    /// Measures system DNS resolution for a host using getaddrinfo (the system
    /// resolver, same path normal connections use). Returns the elapsed time in
    /// seconds, or nil if resolution produced no addresses.
    static func measureDNS(host: String) async -> TimeInterval? {
        await Task.detached(priority: .utility) {
            let start = Date()
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(host, nil, &hints, &result)
            defer {
                if let result {
                    freeaddrinfo(result)
                }
            }
            guard status == 0, result != nil else {
                return nil
            }
            return Date().timeIntervalSince(start)
        }.value
    }
}
