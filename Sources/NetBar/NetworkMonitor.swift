import Foundation
import SwiftUI

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var snapshot = NetworkSnapshot.empty
    @Published private(set) var appTraffic = ApplicationTrafficState.empty
    @Published private(set) var systemResources = SystemResourceSnapshot.empty
    @Published private(set) var isRunning = false

    /// Controls whether the nettop process is active. Set to true when the
    /// traffic detail window is visible; false to stop nettop and save CPU.
    var isApplicationTrafficVisible: Bool = false {
        didSet {
            guard oldValue != isApplicationTrafficVisible else { return }
            if isApplicationTrafficVisible {
                resumeApplicationTrafficSampling()
            } else {
                pauseApplicationTrafficSampling()
            }
        }
    }

    private let reader: NetworkStatsReading
    private let appTrafficReader: ApplicationTrafficReading
    private let streamingReader: StreamingNettopReader?
    private let systemResourceReader: SystemResourceReading
    private let now: () -> Date
    private var previousStats: [String: InterfaceStats] = [:]
    private var previousSampleDate: Date?
    private var previousApplicationStats: [String: ApplicationTrafficStats] = [:]
    private var previousApplicationSampleDate: Date?
    private var previousCPUTickSample: CPUTickSample?
    private var isReadingApplicationTraffic = false
    private var isRefreshing = false
    private var shouldSampleApplicationTraffic = false
    private var timer: Timer?
    private var applicationTimer: Timer?
    private var systemResourceTimer: Timer?
    private var isRefreshingSystemResources = false
    private var powerSaveMode = false
    private var historyBuffer: [RatePoint] = []
    private var historyWriteIndex = 0
    private let historyCapacity = 90
    private var activityLevel: NetworkActivityLevel = .idle

    var recentHistory: [RatePoint] {
        guard !historyBuffer.isEmpty else { return [] }
        if historyBuffer.count < historyCapacity {
            return historyBuffer
        }
        let start = historyWriteIndex % historyCapacity
        return Array(historyBuffer[start...]) + Array(historyBuffer[..<start])
    }

    init(
        reader: NetworkStatsReading = SystemNetworkStatsReader(),
        appTrafficReader: ApplicationTrafficReading? = nil,
        systemResourceReader: SystemResourceReading = LiveSystemResourceReader(),
        now: @escaping () -> Date = Date.init
    ) {
        self.reader = reader
        self.systemResourceReader = systemResourceReader
        self.now = now
        if let appTrafficReader {
            self.appTrafficReader = appTrafficReader
            self.streamingReader = nil
        } else {
            let streaming = StreamingNettopReader()
            self.appTrafficReader = streaming
            self.streamingReader = streaming
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()
        refreshApplicationTraffic()
        refreshSystemResources()
        scheduleNextSample()
        applicationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshApplicationTraffic()
            }
        }
        let resourceInterval: TimeInterval = powerSaveMode ? 10.0 : 5.0
        systemResourceTimer = Timer.scheduledTimer(withTimeInterval: resourceInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSystemResources()
            }
        }
    }

    func resumeApplicationTrafficSampling() {
        guard !shouldSampleApplicationTraffic else { return }
        shouldSampleApplicationTraffic = true
        streamingReader?.start()
        refreshApplicationTraffic()
        applicationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshApplicationTraffic()
            }
        }
    }

    func pauseApplicationTrafficSampling() {
        shouldSampleApplicationTraffic = false
        applicationTimer?.invalidate()
        applicationTimer = nil
        streamingReader?.stop()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        systemResourceTimer?.invalidate()
        systemResourceTimer = nil
        pauseApplicationTrafficSampling()
        isRunning = false
    }

    func setPowerSaveMode(_ enabled: Bool) {
        powerSaveMode = enabled
        rescheduleTimers()
    }

    private func rescheduleTimers() {
        guard isRunning else { return }
        let interval: TimeInterval = powerSaveMode ? 2.0 : 1.0
        let appInterval: TimeInterval = powerSaveMode ? 10.0 : 5.0
        let resourceInterval: TimeInterval = powerSaveMode ? 10.0 : 5.0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        applicationTimer?.invalidate()
        applicationTimer = Timer.scheduledTimer(withTimeInterval: appInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshApplicationTraffic()
            }
        }

        systemResourceTimer?.invalidate()
        systemResourceTimer = Timer.scheduledTimer(withTimeInterval: resourceInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSystemResources()
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        let now = now()
        let capturedPreviousStats = previousStats
        let capturedPreviousSampleDate = previousSampleDate
        let reader = self.reader

        Task { [weak self] in
            let stats = await Task.detached(priority: .utility) { [reader] in
                reader.readInterfaces()
            }.value

            guard let self else { return }
            self.applyRefresh(
                stats,
                now: now,
                previousStats: capturedPreviousStats,
                previousSampleDate: capturedPreviousSampleDate
            )
            self.isRefreshing = false
        }
    }

    private func applyRefresh(
        _ stats: [InterfaceStats],
        now: Date,
        previousStats capturedPreviousStats: [String: InterfaceStats],
        previousSampleDate capturedPreviousSampleDate: Date?
    ) {
        let currentByName = Dictionary(stats.map { ($0.name, $0) }, uniquingKeysWith: { $1 })

        guard let previousDate = capturedPreviousSampleDate else {
            previousStats = currentByName
            previousSampleDate = now
            let externalStats = Self.externalTrafficStats(from: stats)
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
                totalReceivedBytes: externalStats.reduce(0) { $0 + $1.receivedBytes },
                totalSentBytes: externalStats.reduce(0) { $0 + $1.sentBytes },
                sampleCount: 1
            )
            return
        }

        let interval = max(now.timeIntervalSince(previousDate), 0.2)
        let rates = stats.map { current -> InterfaceRate in
            let previous = capturedPreviousStats[current.name]
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

        let externalRates = Self.externalTrafficRates(from: rates)
        let externalStats = Self.externalTrafficStats(from: stats)
        let totalDownload = externalRates.reduce(0) { $0 + $1.downloadBytesPerSecond }
        let totalUpload = externalRates.reduce(0) { $0 + $1.uploadBytesPerSecond }

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
            totalReceivedBytes: externalStats.reduce(0) { $0 + $1.receivedBytes },
            totalSentBytes: externalStats.reduce(0) { $0 + $1.sentBytes },
            sampleCount: snapshot.sampleCount + 1
        )

        let point = RatePoint(
            timestamp: now,
            downloadBytesPerSecond: totalDownload,
            uploadBytesPerSecond: totalUpload
        )
        if historyBuffer.count < historyCapacity {
            historyBuffer.append(point)
        } else {
            historyBuffer[historyWriteIndex % historyCapacity] = point
        }
        historyWriteIndex += 1

        updateActivityLevel(totalBytesPerSecond: totalDownload + totalUpload)

        previousStats = currentByName
        previousSampleDate = now
    }

    func refreshApplicationTraffic() {
        guard !isReadingApplicationTraffic else { return }
        guard shouldSampleApplicationTraffic else { return }

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

        let currentByID = Dictionary(result.stats.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
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

    func refreshSystemResources() {
        guard !isRefreshingSystemResources else { return }
        isRefreshingSystemResources = true

        let reader = systemResourceReader
        let capturedPreviousCPU = previousCPUTickSample

        Task { [weak self] in
            let (memory, cpuSample, thermal) = await Task.detached(priority: .utility) { [reader] in
                let memory = reader.readMemoryUsage()
                let cpuSample = reader.readCPUTicks()
                let thermal = reader.readThermalState()
                return (memory, cpuSample, thermal)
            }.value

            guard let self else { return }
            self.applySystemResources(
                memory: memory,
                cpuSample: cpuSample,
                thermal: thermal,
                previousCPU: capturedPreviousCPU
            )
            self.isRefreshingSystemResources = false
        }
    }

    private func applySystemResources(
        memory: MemoryUsage,
        cpuSample: CPUTickSample,
        thermal: ThermalInfo,
        previousCPU: CPUTickSample?
    ) {
        // Compute CPU usage from delta between current and previous tick samples
        let cpu: CPUUsage
        if let previous = previousCPU {
            let totalDelta = cpuSample.total > previous.total ? cpuSample.total - previous.total : 0
            let userDelta = cpuSample.user > previous.user ? cpuSample.user - previous.user : 0
            let systemDelta = cpuSample.system > previous.system ? cpuSample.system - previous.system : 0
            let idleDelta = cpuSample.idle > previous.idle ? cpuSample.idle - previous.idle : 0
            cpu = CPUUsage(
                totalTicks: totalDelta,
                userTicks: userDelta,
                systemTicks: systemDelta,
                idleTicks: idleDelta
            )
        } else {
            // First sample: we have no delta, report zero usage
            cpu = CPUUsage(
                totalTicks: cpuSample.total,
                userTicks: cpuSample.user,
                systemTicks: cpuSample.system,
                idleTicks: cpuSample.idle
            )
        }

        systemResources = SystemResourceSnapshot(
            memory: memory,
            cpu: cpu,
            thermal: thermal
        )

        previousCPUTickSample = cpuSample
    }

    private static func positiveDelta(_ current: UInt64, _ previous: UInt64?) -> UInt64 {
        guard let previous else { return 0 }
        return current >= previous ? current - previous : 0
    }

    private func scheduleNextSample() {
        timer?.invalidate()
        let interval: TimeInterval = {
            let base = activityLevel.baseInterval
            return ProcessInfo.processInfo.isLowPowerModeEnabled ? base * 2 : base
        }()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.scheduleNextSample()
            }
        }
    }

    private func updateActivityLevel(totalBytesPerSecond: Double) {
        let kbPerSecond = totalBytesPerSecond / 1024
        let mbPerSecond = kbPerSecond / 1024

        let newLevel: NetworkActivityLevel
        if mbPerSecond > 1.0 {
            newLevel = .high
        } else if kbPerSecond > 100.0 {
            newLevel = .moderate
        } else {
            // Hysteresis between idle and low
            let thresholdUp: Double = 10.0    // KB/s for idle→low
            let thresholdDown: Double = 5.0   // KB/s for low→idle
            switch activityLevel {
            case .idle:
                newLevel = kbPerSecond > thresholdUp ? .low : .idle
            case .low:
                newLevel = kbPerSecond < thresholdDown ? .idle : .low
            case .moderate, .high:
                newLevel = kbPerSecond > thresholdUp ? .low : .idle
            }
        }
        activityLevel = newLevel
    }

    private static func externalTrafficStats(from stats: [InterfaceStats]) -> [InterfaceStats] {
        stats.filter { NetworkInterfaceClassifier.countsTowardExternalTrafficTotals($0.name) }
    }

    private static func externalTrafficRates(from rates: [InterfaceRate]) -> [InterfaceRate] {
        rates.filter { NetworkInterfaceClassifier.countsTowardExternalTrafficTotals($0.name) }
    }
}

struct RatePoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

enum NetworkActivityLevel {
    case idle      // 0 B/s
    case low       // < 100 KB/s
    case moderate  // 100 KB/s - 1 MB/s
    case high      // > 1 MB/s

    var baseInterval: TimeInterval {
        switch self {
        case .idle: return 3.0
        case .low: return 2.0
        case .moderate, .high: return 1.0
        }
    }
}
