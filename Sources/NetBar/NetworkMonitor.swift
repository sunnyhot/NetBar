import Foundation
import SwiftUI

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var snapshot = NetworkSnapshot.empty
    @Published private(set) var appTraffic = ApplicationTrafficState.empty
    @Published private(set) var isRunning = false

    private let reader: NetworkStatsReading
    private let appTrafficReader: ApplicationTrafficReading
    private var previousStats: [String: InterfaceStats] = [:]
    private var previousSampleDate: Date?
    private var previousApplicationStats: [String: ApplicationTrafficStats] = [:]
    private var previousApplicationSampleDate: Date?
    private var isReadingApplicationTraffic = false
    private var timer: Timer?
    private var applicationTimer: Timer?
    private var history: [RatePoint] = []

    var recentHistory: [RatePoint] {
        history
    }

    init(
        reader: NetworkStatsReading = SystemNetworkStatsReader(),
        appTrafficReader: ApplicationTrafficReading = NettopApplicationTrafficReader()
    ) {
        self.reader = reader
        self.appTrafficReader = appTrafficReader
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()
        refreshApplicationTraffic()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        applicationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshApplicationTraffic()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        applicationTimer?.invalidate()
        applicationTimer = nil
        isRunning = false
    }

    func refresh() {
        let now = Date()
        let stats = reader.readInterfaces()
        let currentByName = Dictionary(uniqueKeysWithValues: stats.map { ($0.name, $0) })

        guard let previousDate = previousSampleDate else {
            previousStats = currentByName
            previousSampleDate = now
            snapshot = NetworkSnapshot(
                timestamp: now,
                interfaces: stats.map {
                    InterfaceRate(
                        id: $0.id,
                        name: $0.name,
                        displayName: $0.displayName,
                        downloadBytesPerSecond: 0,
                        uploadBytesPerSecond: 0,
                        totalReceivedBytes: $0.receivedBytes,
                        totalSentBytes: $0.sentBytes,
                        receivedPackets: $0.receivedPackets,
                        sentPackets: $0.sentPackets,
                        isPrimary: $0.isPrimary
                    )
                },
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0,
                totalReceivedBytes: stats.reduce(0) { $0 + $1.receivedBytes },
                totalSentBytes: stats.reduce(0) { $0 + $1.sentBytes },
                sampleCount: 1
            )
            return
        }

        let interval = max(now.timeIntervalSince(previousDate), 0.2)
        let rates = stats.map { current -> InterfaceRate in
            let previous = previousStats[current.name]
            let receivedDelta = Self.positiveDelta(current.receivedBytes, previous?.receivedBytes)
            let sentDelta = Self.positiveDelta(current.sentBytes, previous?.sentBytes)

            return InterfaceRate(
                id: current.id,
                name: current.name,
                displayName: current.displayName,
                downloadBytesPerSecond: Double(receivedDelta) / interval,
                uploadBytesPerSecond: Double(sentDelta) / interval,
                totalReceivedBytes: current.receivedBytes,
                totalSentBytes: current.sentBytes,
                receivedPackets: current.receivedPackets,
                sentPackets: current.sentPackets,
                isPrimary: current.isPrimary
            )
        }

        let totalDownload = rates.reduce(0) { $0 + $1.downloadBytesPerSecond }
        let totalUpload = rates.reduce(0) { $0 + $1.uploadBytesPerSecond }

        snapshot = NetworkSnapshot(
            timestamp: now,
            interfaces: rates.sorted { lhs, rhs in
                if lhs.isPrimary != rhs.isPrimary {
                    return lhs.isPrimary && !rhs.isPrimary
                }
                let lhsTraffic = lhs.downloadBytesPerSecond + lhs.uploadBytesPerSecond
                let rhsTraffic = rhs.downloadBytesPerSecond + rhs.uploadBytesPerSecond
                if lhsTraffic != rhsTraffic {
                    return lhsTraffic > rhsTraffic
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            },
            downloadBytesPerSecond: totalDownload,
            uploadBytesPerSecond: totalUpload,
            totalReceivedBytes: stats.reduce(0) { $0 + $1.receivedBytes },
            totalSentBytes: stats.reduce(0) { $0 + $1.sentBytes },
            sampleCount: snapshot.sampleCount + 1
        )

        history.append(RatePoint(
            timestamp: now,
            downloadBytesPerSecond: totalDownload,
            uploadBytesPerSecond: totalUpload
        ))
        if history.count > 90 {
            history.removeFirst(history.count - 90)
        }

        previousStats = currentByName
        previousSampleDate = now
    }

    func refreshApplicationTraffic() {
        guard !isReadingApplicationTraffic else { return }

        isReadingApplicationTraffic = true
        appTraffic.isRefreshing = true

        let reader = appTrafficReader
        Task { [weak self, reader] in
            let (result, sampledAt) = await Task.detached(priority: .utility) { [reader] in
                (reader.readApplications(), Date())
            }.value

            self?.applyApplicationTraffic(result, sampledAt: sampledAt)
        }
    }

    private func applyApplicationTraffic(_ result: ApplicationTrafficReadResult, sampledAt: Date) {
        defer { isReadingApplicationTraffic = false }

        guard result.errorMessage == nil else {
            appTraffic = ApplicationTrafficState(
                timestamp: previousApplicationSampleDate,
                applications: appTraffic.applications,
                sampleCount: appTraffic.sampleCount,
                isRefreshing: false,
                errorMessage: result.errorMessage
            )
            return
        }

        let currentByID = Dictionary(uniqueKeysWithValues: result.stats.map { ($0.id, $0) })
        guard let previousDate = previousApplicationSampleDate else {
            previousApplicationStats = currentByID
            previousApplicationSampleDate = sampledAt
            appTraffic = ApplicationTrafficState(
                timestamp: sampledAt,
                applications: groupApplications(result.stats.map { stat in
                    ApplicationTrafficRate(
                        id: stat.displayName,
                        displayName: stat.displayName,
                        processNames: [stat.processName],
                        pids: stat.pid.map { [$0] } ?? [],
                        downloadBytesPerSecond: 0,
                        uploadBytesPerSecond: 0,
                        totalReceivedBytes: stat.receivedBytes,
                        totalSentBytes: stat.sentBytes
                    )
                }),
                sampleCount: 1,
                isRefreshing: false,
                errorMessage: nil
            )
            return
        }

        let interval = max(sampledAt.timeIntervalSince(previousDate), 0.2)
        let processRates = result.stats.map { current -> ApplicationTrafficRate in
            let previous = previousApplicationStats[current.id]
            let receivedDelta = Self.positiveDelta(current.receivedBytes, previous?.receivedBytes)
            let sentDelta = Self.positiveDelta(current.sentBytes, previous?.sentBytes)

            return ApplicationTrafficRate(
                id: current.id,
                displayName: current.displayName,
                processNames: [current.processName],
                pids: current.pid.map { [$0] } ?? [],
                downloadBytesPerSecond: Double(receivedDelta) / interval,
                uploadBytesPerSecond: Double(sentDelta) / interval,
                totalReceivedBytes: current.receivedBytes,
                totalSentBytes: current.sentBytes
            )
        }

        previousApplicationStats = currentByID
        previousApplicationSampleDate = sampledAt
        appTraffic = ApplicationTrafficState(
            timestamp: sampledAt,
            applications: groupApplications(processRates),
            sampleCount: appTraffic.sampleCount + 1,
            isRefreshing: false,
            errorMessage: nil
        )
    }

    private func groupApplications(_ processRates: [ApplicationTrafficRate]) -> [ApplicationTrafficRate] {
        let grouped = Dictionary(grouping: processRates) { $0.displayName }

        return grouped.map { displayName, rates in
            let processNames = Array(Set(rates.flatMap(\.processNames))).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
            let pids = rates.flatMap(\.pids).sorted()
            let totalReceived = rates.reduce(0) { $0 + $1.totalReceivedBytes }
            let totalSent = rates.reduce(0) { $0 + $1.totalSentBytes }
            let download = rates.reduce(0) { $0 + $1.downloadBytesPerSecond }
            let upload = rates.reduce(0) { $0 + $1.uploadBytesPerSecond }

            return ApplicationTrafficRate(
                id: displayName,
                displayName: displayName,
                processNames: processNames,
                pids: pids,
                downloadBytesPerSecond: download,
                uploadBytesPerSecond: upload,
                totalReceivedBytes: totalReceived,
                totalSentBytes: totalSent
            )
        }
        .filter { $0.totalReceivedBytes > 0 || $0.totalSentBytes > 0 }
        .sorted { lhs, rhs in
            let lhsTraffic = lhs.downloadBytesPerSecond + lhs.uploadBytesPerSecond
            let rhsTraffic = rhs.downloadBytesPerSecond + rhs.uploadBytesPerSecond
            if lhsTraffic != rhsTraffic {
                return lhsTraffic > rhsTraffic
            }

            let lhsTotal = lhs.totalReceivedBytes + lhs.totalSentBytes
            let rhsTotal = rhs.totalReceivedBytes + rhs.totalSentBytes
            if lhsTotal != rhsTotal {
                return lhsTotal > rhsTotal
            }

            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private static func positiveDelta(_ current: UInt64, _ previous: UInt64?) -> UInt64 {
        guard let previous else { return 0 }
        return current >= previous ? current - previous : 0
    }
}

struct RatePoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}
