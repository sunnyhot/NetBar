import Foundation

enum ApplicationTrafficMetricKind: Equatable {
    case download
    case upload
    case memory
    case cpu
}

struct ApplicationTrafficMetric: Equatable, Identifiable {
    let kind: ApplicationTrafficMetricKind
    let value: String

    var id: String { "\(kind)-\(value)" }
}

enum ApplicationAttributionStatus: Equatable {
    case idle
    case covered
    case partial
}

struct ApplicationAttributionSummary: Equatable {
    let interfaceBytesPerSecond: Double
    let applicationBytesPerSecond: Double
    let coveragePercentage: Int?
    let proxyCandidateNames: [String]
    let helperCandidateNames: [String]
    let status: ApplicationAttributionStatus
}

enum ApplicationAttributionRole: String, Codable, Equatable {
    case application
    case proxyOrVPN
    case helper
    case systemService

    func title(language: AppLanguage) -> String {
        switch self {
        case .application:
            return language.text("应用", "App")
        case .proxyOrVPN:
            return language.text("代理", "Proxy")
        case .helper:
            return language.text("子进程", "Helper")
        case .systemService:
            return language.text("系统", "System")
        }
    }
}

enum TrafficHistoryWindow: String, CaseIterable, Identifiable {
    case seconds90
    case minutes5
    case minutes15

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .seconds90: return 90
        case .minutes5: return 5 * 60
        case .minutes15: return 15 * 60
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .seconds90:
            return language.text("90 秒", "90s")
        case .minutes5:
            return language.text("5 分钟", "5m")
        case .minutes15:
            return language.text("15 分钟", "15m")
        }
    }

    func points(from points: [RatePoint]) -> [RatePoint] {
        guard let latest = points.last?.timestamp else { return [] }
        let threshold = latest.addingTimeInterval(-duration)
        return points.filter { $0.timestamp >= threshold }
    }
}

enum ApplicationTrafficPresentation {
    @MainActor
    static func visibleApplications(
        from state: ApplicationTrafficState,
        preferences: AppPreferences,
        searchText: String,
        limit: Int = 18
    ) -> [ApplicationTrafficRate] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = state.applications.filter { application in
            if preferences.hidesSystemProcesses, isLikelySystemProcess(application) {
                return false
            }

            guard !normalizedSearch.isEmpty else { return true }
            let searchableText = ([application.displayName] + application.processNames)
                .joined(separator: " ")
                .lowercased()
            return searchableText.localizedStandardContains(normalizedSearch)
        }

        let displayFiltered = displayApplications(filtered, mode: preferences.applicationSort)
        return Array(sorted(displayFiltered, by: preferences.applicationSort).prefix(limit))
    }

    static func displayApplications(
        _ applications: [ApplicationTrafficRate],
        mode: ApplicationSortMode
    ) -> [ApplicationTrafficRate] {
        switch mode.displayModeFallback {
        case .activity:
            return applications.filter(hasVisibleRealtimeTraffic)
        case .memory, .cpu:
            return applications
        case .download, .upload, .total, .name:
            return displayApplications(applications, mode: .activity)
        }
    }

    static func sorted(
        _ applications: [ApplicationTrafficRate],
        by sortMode: ApplicationSortMode
    ) -> [ApplicationTrafficRate] {
        applications.sorted { lhs, rhs in
            switch sortMode {
            case .activity:
                let lhsActivity = lhs.downloadBytesPerSecond + lhs.uploadBytesPerSecond
                let rhsActivity = rhs.downloadBytesPerSecond + rhs.uploadBytesPerSecond
                return orderedDescending(lhsActivity, rhsActivity, lhs.displayName, rhs.displayName)
            case .download:
                return orderedDescending(lhs.downloadBytesPerSecond, rhs.downloadBytesPerSecond, lhs.displayName, rhs.displayName)
            case .upload:
                return orderedDescending(lhs.uploadBytesPerSecond, rhs.uploadBytesPerSecond, lhs.displayName, rhs.displayName)
            case .total:
                let lhsTotal = lhs.totalReceivedBytes + lhs.totalSentBytes
                let rhsTotal = rhs.totalReceivedBytes + rhs.totalSentBytes
                if lhsTotal != rhsTotal {
                    return lhsTotal > rhsTotal
                }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case .memory:
                let lhsMem = lhs.residentMemory ?? 0
                let rhsMem = rhs.residentMemory ?? 0
                return orderedDescending(Double(lhsMem), Double(rhsMem), lhs.displayName, rhs.displayName)
            case .cpu:
                let lhsCPU = lhs.cpuPercentage ?? -1
                let rhsCPU = rhs.cpuPercentage ?? -1
                return orderedDescending(lhsCPU, rhsCPU, lhs.displayName, rhs.displayName)
            case .name:
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    static func attributionSummary(
        snapshot: NetworkSnapshot,
        applications: [ApplicationTrafficRate]
    ) -> ApplicationAttributionSummary {
        let interfaceBytes = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
        let trafficApplications = displayApplications(applications, mode: .activity)
        let applicationBytes = trafficApplications.reduce(0) {
            $0 + $1.downloadBytesPerSecond + $1.uploadBytesPerSecond
        }
        let coverage: Int? = interfaceBytes > 0
            ? min(100, Int((applicationBytes / interfaceBytes * 100).rounded()))
            : nil
        let status: ApplicationAttributionStatus = {
            guard interfaceBytes >= 1 || applicationBytes >= 1 else { return .idle }
            guard let coverage else { return .partial }
            return coverage >= 80 ? .covered : .partial
        }()

        return ApplicationAttributionSummary(
            interfaceBytesPerSecond: interfaceBytes,
            applicationBytesPerSecond: applicationBytes,
            coveragePercentage: coverage,
            proxyCandidateNames: candidateNames(from: trafficApplications, role: .proxyOrVPN),
            helperCandidateNames: candidateNames(from: trafficApplications, role: .helper),
            status: status
        )
    }

    static func attributionRole(for application: ApplicationTrafficRate) -> ApplicationAttributionRole {
        if matches(application, keywords: proxyProcessKeywords) {
            return .proxyOrVPN
        }
        if matches(application, keywords: helperProcessKeywords) {
            return .helper
        }
        if isLikelySystemProcess(application) {
            return .systemService
        }
        return .application
    }

    static func summaryMetrics(
        for applications: [ApplicationTrafficRate],
        displayMode: ApplicationSortMode
    ) -> [ApplicationTrafficMetric] {
        switch displayMode.displayModeFallback {
        case .activity:
            let totalDown = applications.reduce(0) { $0 + $1.downloadBytesPerSecond }
            let totalUp = applications.reduce(0) { $0 + $1.uploadBytesPerSecond }
            return [
                ApplicationTrafficMetric(kind: .download, value: ByteFormat.speed(totalDown)),
                ApplicationTrafficMetric(kind: .upload, value: ByteFormat.speed(totalUp))
            ]
        case .memory:
            let totalMemory = applications.reduce(UInt64(0)) { $0 + ($1.residentMemory ?? 0) }
            return [ApplicationTrafficMetric(kind: .memory, value: ByteFormat.bytes(totalMemory))]
        case .cpu:
            let totalCPU = applications.reduce(0) { $0 + ($1.cpuPercentage ?? 0) }
            return [ApplicationTrafficMetric(kind: .cpu, value: String(format: "%.1f%%", totalCPU))]
        case .download, .upload, .total, .name:
            return summaryMetrics(for: applications, displayMode: .activity)
        }
    }

    static func rowMetrics(
        for application: ApplicationTrafficRate,
        displayMode: ApplicationSortMode
    ) -> [ApplicationTrafficMetric] {
        switch displayMode.displayModeFallback {
        case .activity:
            return [
                ApplicationTrafficMetric(kind: .download, value: ByteFormat.speed(application.downloadBytesPerSecond)),
                ApplicationTrafficMetric(kind: .upload, value: ByteFormat.speed(application.uploadBytesPerSecond))
            ]
        case .memory:
            return [ApplicationTrafficMetric(kind: .memory, value: ByteFormat.bytes(application.residentMemory ?? 0))]
        case .cpu:
            return [ApplicationTrafficMetric(kind: .cpu, value: String(format: "%.1f%%", application.cpuPercentage ?? 0))]
        case .download, .upload, .total, .name:
            return rowMetrics(for: application, displayMode: .activity)
        }
    }

    private static let systemProcessCache = NSCache<NSString, NSNumber>()

    static func isLikelySystemProcess(_ application: ApplicationTrafficRate) -> Bool {
        let cacheKey = application.id as NSString
        if let cached = systemProcessCache.object(forKey: cacheKey) {
            return cached.boolValue
        }

        let result = _isLikelySystemProcess(application)
        systemProcessCache.setObject(NSNumber(value: result), forKey: cacheKey)
        return result
    }

    private static func _isLikelySystemProcess(_ application: ApplicationTrafficRate) -> Bool {
        let names = ([application.displayName] + application.processNames)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !names.isEmpty else { return false }
        if names.contains(where: { knownSystemProcessNames.contains($0) }) {
            return true
        }

        let displayName = application.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard displayName == displayName.lowercased() else { return false }

        return names.allSatisfy { name in
            name.hasSuffix("d") || name.hasPrefix("com.apple.") || name.hasPrefix("kernel")
        }
    }

    private static func orderedDescending(
        _ lhsValue: Double,
        _ rhsValue: Double,
        _ lhsName: String,
        _ rhsName: String
    ) -> Bool {
        if lhsValue != rhsValue {
            return lhsValue > rhsValue
        }
        return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
    }

    private static func hasVisibleRealtimeTraffic(_ application: ApplicationTrafficRate) -> Bool {
        application.downloadBytesPerSecond >= 1 || application.uploadBytesPerSecond >= 1
    }

    private static func candidateNames(
        from applications: [ApplicationTrafficRate],
        role: ApplicationAttributionRole
    ) -> [String] {
        applications
            .filter { attributionRole(for: $0) == role }
            .sorted {
                let lhs = $0.downloadBytesPerSecond + $0.uploadBytesPerSecond
                let rhs = $1.downloadBytesPerSecond + $1.uploadBytesPerSecond
                if lhs != rhs { return lhs > rhs }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            .map(\.displayName)
            .uniqued()
    }

    private static func matches(_ application: ApplicationTrafficRate, keywords: Set<String>) -> Bool {
        let names = ([application.displayName] + application.processNames)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return names.contains { name in
            keywords.contains { keyword in name.localizedStandardContains(keyword) }
        }
    }

    private static let proxyProcessKeywords: Set<String> = [
        "adguard",
        "clash",
        "corplink",
        "eagleyun",
        "hionetwork",
        "mihomo",
        "openvpn",
        "proxy",
        "shadow",
        "sing-box",
        "surge",
        "tailscale",
        "v2ray",
        "vpn",
        "wireguard",
        "xray",
        "zerotier"
    ]

    private static let helperProcessKeywords: Set<String> = [
        "electron",
        "helper",
        "node",
        "renderer"
    ]

    private static let knownSystemProcessNames: Set<String> = [
        "airportd",
        "apsd",
        "bluetoothd",
        "cfnetworkagent",
        "cloudd",
        "configd",
        "containermanagerd",
        "coreservicesd",
        "distnoted",
        "identityservicesd",
        "kernel_task",
        "launchservicesd",
        "locationd",
        "mDNSResponder".lowercased(),
        "networkd",
        "nsurlsessiond",
        "rapportd",
        "runningboardd",
        "sharingd",
        "syncdefaultsd",
        "trustd",
        "usernoted"
    ]
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
