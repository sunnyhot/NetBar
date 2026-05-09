import Foundation

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

        return Array(sorted(filtered, by: preferences.applicationSort).prefix(limit))
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
            case .name:
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    static func isLikelySystemProcess(_ application: ApplicationTrafficRate) -> Bool {
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
