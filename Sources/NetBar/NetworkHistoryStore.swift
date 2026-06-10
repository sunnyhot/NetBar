import Combine
import Foundation

@MainActor
final class NetworkHistoryStore: ObservableObject {
    @Published private(set) var summary: NetworkIntelligenceSummary

    private let fileURL: URL
    private let calendar: Calendar
    private let now: () -> Date
    private var state: PersistedNetworkHistory
    private var lastSnapshot: NetworkSnapshot?
    private var lastApplicationTotals: [String: TrafficCounterTotals] = [:]
    private var encoder = JSONEncoder()
    private var decoder = JSONDecoder()

    init(
        rootDirectory: URL? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.now = now
        let root = rootDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NetBar", isDirectory: true)
        self.fileURL = root.appendingPathComponent("NetworkHistory.json")
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let currentDateKey = Self.dateKey(for: now(), calendar: calendar)
        let shouldSaveLoadedState: Bool
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(PersistedNetworkHistory.self, from: data) {
            self.state = Self.normalizedState(decoded, todayKey: currentDateKey)
            shouldSaveLoadedState = true
        } else {
            self.state = PersistedNetworkHistory(today: .empty(dateKey: currentDateKey), recentDays: [])
            shouldSaveLoadedState = false
        }
        self.summary = NetworkIntelligenceSummary(
            latestEvent: nil,
            today: state.today,
            recentDays: state.recentDays,
            realtimeTopApplications: [],
            todayTopApplications: Array(state.today.topApplications.prefix(5))
        )
        if shouldSaveLoadedState {
            save()
        }
    }

    func record(snapshot: NetworkSnapshot) {
        rolloverIfNeeded(for: snapshot.timestamp)
        defer { lastSnapshot = snapshot }

        guard let previous = lastSnapshot else {
            state.today.peakDownloadBytesPerSecond = max(state.today.peakDownloadBytesPerSecond, snapshot.downloadBytesPerSecond)
            state.today.peakUploadBytesPerSecond = max(state.today.peakUploadBytesPerSecond, snapshot.uploadBytesPerSecond)
            state.today.sampleCount += 1
            publishAndSave(realtimeTopApplications: summary.realtimeTopApplications)
            return
        }

        let deltas = Self.interfaceDeltas(from: previous.interfaces, to: snapshot.interfaces)
        let interval = max(snapshot.timestamp.timeIntervalSince(previous.timestamp), 0)

        state.today.downloadBytes += deltas.receivedBytes
        state.today.uploadBytes += deltas.sentBytes
        state.today.peakDownloadBytesPerSecond = max(state.today.peakDownloadBytesPerSecond, snapshot.downloadBytesPerSecond)
        state.today.peakUploadBytesPerSecond = max(state.today.peakUploadBytesPerSecond, snapshot.uploadBytesPerSecond)
        state.today.sampleCount += 1
        if snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond > 1_024 {
            state.today.activeSeconds += interval
        }

        publishAndSave(realtimeTopApplications: summary.realtimeTopApplications)
    }

    func record(appTraffic: ApplicationTrafficState, interval: TimeInterval) {
        guard let timestamp = appTraffic.timestamp else { return }
        rolloverIfNeeded(for: timestamp)
        var usageByID: [String: ApplicationDailyUsage] = [:]
        for usage in state.today.topApplications {
            usageByID[usage.applicationID] = usage
        }
        var updatedApplicationTotals: [String: TrafficCounterTotals] = [:]

        for application in appTraffic.applications {
            let role = ApplicationTrafficPresentation.attributionRole(for: application)
            let currentTotals = TrafficCounterTotals(
                receivedBytes: application.totalReceivedBytes,
                sentBytes: application.totalSentBytes
            )
            let usageDeltas = Self.applicationDeltas(
                current: currentTotals,
                previous: lastApplicationTotals[application.id],
                application: application,
                interval: interval
            )
            var usage = usageByID[application.id] ?? ApplicationDailyUsage(
                applicationID: application.id,
                displayName: application.displayName,
                processNames: application.processNames,
                downloadBytes: 0,
                uploadBytes: 0,
                lastSeenAt: timestamp,
                role: role
            )
            usage.displayName = application.displayName
            usage.processNames = application.processNames
            usage.downloadBytes += usageDeltas.receivedBytes
            usage.uploadBytes += usageDeltas.sentBytes
            usage.lastSeenAt = timestamp
            usage.role = role
            usageByID[application.id] = usage
            updatedApplicationTotals[application.id] = currentTotals
        }
        lastApplicationTotals = updatedApplicationTotals

        state.today.topApplications = Self.sortedTopApplications(Array(usageByID.values), limit: 20)

        let realtimeTop = ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        )
        publishAndSave(realtimeTopApplications: Array(realtimeTop.prefix(5)))
    }

    func recordAnimationPlayback(count: UInt64, characterID: String, at date: Date) {
        guard count > 0 else { return }
        rolloverIfNeeded(for: date)
        state.today.animationPlaybackCount += count
        state.today.animationPlaybackCountsByCharacter[characterID, default: 0] += count
        publishAndSave(realtimeTopApplications: summary.realtimeTopApplications)
    }

    func clear() {
        state = PersistedNetworkHistory(today: .empty(dateKey: Self.dateKey(for: now(), calendar: calendar)), recentDays: [])
        lastSnapshot = nil
        lastApplicationTotals = [:]
        publishAndSave(realtimeTopApplications: [])
    }

    private func rolloverIfNeeded(for date: Date) {
        let key = Self.dateKey(for: date, calendar: calendar)
        guard state.today.dateKey != key else { return }
        state.recentDays.append(state.today)
        state.recentDays = Array(state.recentDays.suffix(7))
        state.today = .empty(dateKey: key)
        lastSnapshot = nil
        lastApplicationTotals = [:]
    }

    private func publishAndSave(realtimeTopApplications: [ApplicationTrafficRate]) {
        summary = NetworkIntelligenceSummary(
            latestEvent: summary.latestEvent,
            today: state.today,
            recentDays: state.recentDays,
            realtimeTopApplications: realtimeTopApplications,
            todayTopApplications: Array(state.today.topApplications.prefix(5))
        )
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal: in-memory summaries continue for this session.
        }
    }

    private static func positiveDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    private static func interfaceDeltas(
        from previousInterfaces: [InterfaceRate],
        to currentInterfaces: [InterfaceRate]
    ) -> TrafficCounterTotals {
        var previousByKey: [String: InterfaceRate] = [:]
        for interface in previousInterfaces {
            previousByKey[interfaceKey(for: interface)] = interface
        }

        return currentInterfaces.reduce(TrafficCounterTotals(receivedBytes: 0, sentBytes: 0)) { result, interface in
            guard NetworkInterfaceClassifier.countsTowardExternalTrafficTotals(interface.name) else { return result }
            guard let previous = previousByKey[interfaceKey(for: interface)] else { return result }
            return TrafficCounterTotals(
                receivedBytes: result.receivedBytes + positiveDelta(interface.totalReceivedBytes, previous.totalReceivedBytes),
                sentBytes: result.sentBytes + positiveDelta(interface.totalSentBytes, previous.totalSentBytes)
            )
        }
    }

    private static func applicationDeltas(
        current: TrafficCounterTotals,
        previous: TrafficCounterTotals?,
        application: ApplicationTrafficRate,
        interval: TimeInterval
    ) -> TrafficCounterTotals {
        guard let previous else {
            return TrafficCounterTotals(
                receivedBytes: estimatedBytes(rate: application.downloadBytesPerSecond, interval: interval),
                sentBytes: estimatedBytes(rate: application.uploadBytesPerSecond, interval: interval)
            )
        }

        return TrafficCounterTotals(
            receivedBytes: positiveDelta(current.receivedBytes, previous.receivedBytes),
            sentBytes: positiveDelta(current.sentBytes, previous.sentBytes)
        )
    }

    private static func estimatedBytes(rate: Double, interval: TimeInterval) -> UInt64 {
        UInt64(max(rate * interval, 0).rounded())
    }

    private static func interfaceKey(for interface: InterfaceRate) -> String {
        interface.id.isEmpty ? interface.name : interface.id
    }

    private static func normalizedState(
        _ state: PersistedNetworkHistory,
        todayKey: String
    ) -> PersistedNetworkHistory {
        var today = normalizedDay(state.today)
        var recentDays = state.recentDays.map(normalizedDay)

        if today.dateKey != todayKey {
            recentDays.append(today)
            today = .empty(dateKey: todayKey)
        }

        return PersistedNetworkHistory(
            today: today,
            recentDays: Array(recentDays.suffix(7))
        )
    }

    private static func normalizedDay(_ day: NetworkDailySummary) -> NetworkDailySummary {
        var day = day
        day.topApplications = sortedTopApplications(day.topApplications, limit: 20)
        return day
    }

    private static func sortedTopApplications(
        _ applications: [ApplicationDailyUsage],
        limit: Int
    ) -> [ApplicationDailyUsage] {
        Array(applications
            .sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes { return lhs.totalBytes > rhs.totalBytes }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            .prefix(limit))
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }
}

private struct TrafficCounterTotals: Equatable {
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

private struct PersistedNetworkHistory: Codable, Equatable {
    var today: NetworkDailySummary
    var recentDays: [NetworkDailySummary]
}
