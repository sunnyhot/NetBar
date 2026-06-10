import Foundation

struct NetworkAnomalyDetector {
    private var highTrafficStartedAt: Date?
    private var appSpikeApplicationID: String?
    private var appSpikeStartedAt: Date?
    private var lowTrafficStartedAt: Date?
    private var recoveryStartedAt: Date?
    private var droppedState = false
    private var recentActiveSamples: [(Date, Double)] = []
    private var lastEmittedAtByCooldownKey: [String: Date] = [:]

    mutating func detect(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        settings: NetworkIntelligenceSettings,
        now: Date,
        language: AppLanguage = .simplifiedChinese
    ) -> [NetworkAnomalyEvent] {
        guard settings.isAnomalyDetectionEnabled else {
            resetSustainedTracking()
            return []
        }

        let totalSpeed = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
        if settings.isNetworkDropAlertEnabled {
            recordActiveSampleForDropDetection(totalSpeed: totalSpeed, now: now)
        }

        var events: [NetworkAnomalyEvent] = []
        if let event = highTrafficEvent(totalSpeed: totalSpeed, appTraffic: appTraffic, settings: settings, now: now, language: language) {
            events.append(event)
        }
        if settings.isApplicationSpikeAlertEnabled {
            if let event = appSpikeEvent(appTraffic: appTraffic, now: now, language: language) {
                events.append(event)
            }
        } else {
            resetAppSpikeTracking()
        }
        if settings.isNetworkDropAlertEnabled {
            if let event = dropOrRecoveryEvent(totalSpeed: totalSpeed, now: now, language: language) {
                events.append(event)
            }
        } else {
            resetDropTracking()
        }
        if settings.isProxyAttributionAlertEnabled, let event = proxyGapEvent(snapshot: snapshot, appTraffic: appTraffic, now: now, language: language) {
            events.append(event)
        }
        return events
    }

    private mutating func resetSustainedTracking() {
        highTrafficStartedAt = nil
        resetAppSpikeTracking()
        resetDropTracking()
    }

    private mutating func recordActiveSampleForDropDetection(totalSpeed: Double, now: Date) {
        if totalSpeed > 102_400 {
            recentActiveSamples.append((now, totalSpeed))
        }
        recentActiveSamples = recentActiveSamples.filter { now.timeIntervalSince($0.0) <= 30 }
    }

    private mutating func highTrafficEvent(
        totalSpeed: Double,
        appTraffic: ApplicationTrafficState,
        settings: NetworkIntelligenceSettings,
        now: Date,
        language: AppLanguage
    ) -> NetworkAnomalyEvent? {
        guard totalSpeed >= settings.highTrafficThreshold.rawValue else {
            highTrafficStartedAt = nil
            return nil
        }
        if highTrafficStartedAt == nil {
            highTrafficStartedAt = now
        }
        guard let startedAt = highTrafficStartedAt, now.timeIntervalSince(startedAt) >= 10 else { return nil }

        let key = "highTraffic"
        guard canEmit(cooldownKey: key, now: now, cooldown: 10 * 60) else { return nil }

        let top = ApplicationTrafficPresentation.sorted(
            ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity),
            by: .activity
        ).first
        markEmitted(cooldownKey: key, now: now)
        let message = top.map {
            language.text(
                "\($0.displayName) 当前较活跃，总速率约 \(ByteFormat.speed(totalSpeed))。",
                "\($0.displayName) is active; total speed is about \(ByteFormat.speed(totalSpeed))."
            )
        } ?? language.text(
            "当前总速率约 \(ByteFormat.speed(totalSpeed))。",
            "Current total speed is about \(ByteFormat.speed(totalSpeed))."
        )

        return NetworkAnomalyEvent(
            kind: .highTraffic,
            severity: .warning,
            title: NetworkAnomalyKind.highTraffic.title(language: language),
            message: message,
            timestamp: now,
            applicationName: top?.displayName,
            bytesPerSecond: totalSpeed,
            cooldownKey: key
        )
    }

    private mutating func appSpikeEvent(
        appTraffic: ApplicationTrafficState,
        now: Date,
        language: AppLanguage
    ) -> NetworkAnomalyEvent? {
        let apps = ApplicationTrafficPresentation.displayApplications(appTraffic.applications, mode: .activity)
        let appTotal = apps.reduce(0) { $0 + $1.downloadBytesPerSecond + $1.uploadBytesPerSecond }
        guard appTotal > 0,
              let top = ApplicationTrafficPresentation.sorted(apps, by: .activity).first else {
            resetAppSpikeTracking()
            return nil
        }

        let topSpeed = top.downloadBytesPerSecond + top.uploadBytesPerSecond
        let share = topSpeed / appTotal
        guard topSpeed >= 5_242_880, share >= 0.60 else {
            resetAppSpikeTracking()
            return nil
        }
        if appSpikeApplicationID != top.id {
            appSpikeApplicationID = top.id
            appSpikeStartedAt = now
        } else if appSpikeStartedAt == nil {
            appSpikeStartedAt = now
        }
        guard let startedAt = appSpikeStartedAt, now.timeIntervalSince(startedAt) >= 5 else { return nil }

        let key = "applicationSpike.\(top.id)"
        guard canEmit(cooldownKey: key, now: now, cooldown: 10 * 60) else { return nil }
        markEmitted(cooldownKey: key, now: now)
        let roundedShare = Int((share * 100).rounded())

        return NetworkAnomalyEvent(
            kind: .applicationSpike,
            severity: .warning,
            title: NetworkAnomalyKind.applicationSpike.title(language: language),
            message: language.text(
                "\(top.displayName) 占应用流量约 \(roundedShare)%，当前 \(ByteFormat.speed(topSpeed))。",
                "\(top.displayName) is using about \(roundedShare)% of app traffic, currently \(ByteFormat.speed(topSpeed))."
            ),
            timestamp: now,
            applicationName: top.displayName,
            bytesPerSecond: topSpeed,
            cooldownKey: key
        )
    }

    private mutating func resetAppSpikeTracking() {
        appSpikeApplicationID = nil
        appSpikeStartedAt = nil
    }

    private mutating func dropOrRecoveryEvent(
        totalSpeed: Double,
        now: Date,
        language: AppLanguage
    ) -> NetworkAnomalyEvent? {
        if droppedState {
            guard totalSpeed > 20_480 else {
                recoveryStartedAt = nil
                return nil
            }
            if recoveryStartedAt == nil {
                recoveryStartedAt = now
            }
            guard let recoveryStartedAt, now.timeIntervalSince(recoveryStartedAt) >= 3 else { return nil }

            let key = "networkRecovered"
            guard canEmit(cooldownKey: key, now: now, cooldown: 3 * 60) else { return nil }

            droppedState = false
            lowTrafficStartedAt = nil
            self.recoveryStartedAt = nil
            markEmitted(cooldownKey: key, now: now)

            return NetworkAnomalyEvent(
                kind: .networkRecovered,
                severity: .info,
                title: NetworkAnomalyKind.networkRecovered.title(language: language),
                message: language.text("网络活动已恢复。", "Network activity has recovered."),
                timestamp: now,
                bytesPerSecond: totalSpeed,
                cooldownKey: key
            )
        }

        guard totalSpeed < 1_024 else {
            lowTrafficStartedAt = nil
            return nil
        }
        guard !recentActiveSamples.isEmpty || lowTrafficStartedAt != nil else { return nil }

        if lowTrafficStartedAt == nil {
            lowTrafficStartedAt = now
        }
        guard let startedAt = lowTrafficStartedAt, now.timeIntervalSince(startedAt) >= 8 else { return nil }

        let key = "networkDrop"
        guard canEmit(cooldownKey: key, now: now, cooldown: 3 * 60) else { return nil }

        droppedState = true
        recoveryStartedAt = nil
        markEmitted(cooldownKey: key, now: now)

        return NetworkAnomalyEvent(
            kind: .networkDrop,
            severity: .critical,
            title: NetworkAnomalyKind.networkDrop.title(language: language),
            message: language.text(
                "网络活动从活跃状态降至接近空闲。",
                "Network activity dropped from active to nearly idle."
            ),
            timestamp: now,
            bytesPerSecond: totalSpeed,
            cooldownKey: key
        )
    }

    private mutating func resetDropTracking() {
        lowTrafficStartedAt = nil
        recoveryStartedAt = nil
        droppedState = false
        recentActiveSamples.removeAll()
    }

    private mutating func proxyGapEvent(
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState,
        now: Date,
        language: AppLanguage
    ) -> NetworkAnomalyEvent? {
        let summary = ApplicationTrafficPresentation.attributionSummary(
            snapshot: snapshot,
            applications: appTraffic.applications
        )
        guard summary.interfaceBytesPerSecond >= 1_048_576 else {
            return nil
        }

        let rawCoverage = summary.applicationBytesPerSecond / summary.interfaceBytesPerSecond
        guard rawCoverage < 0.40,
              let proxy = summary.proxyCandidateNames.first else {
            return nil
        }

        let key = "proxyAttributionGap"
        guard canEmit(cooldownKey: key, now: now, cooldown: 15 * 60) else { return nil }
        markEmitted(cooldownKey: key, now: now)

        return NetworkAnomalyEvent(
            kind: .proxyAttributionGap,
            severity: .warning,
            title: NetworkAnomalyKind.proxyAttributionGap.title(language: language),
            message: language.text(
                "流量可能集中在代理/VPN 进程 \(proxy)。",
                "Traffic may be concentrated in proxy/VPN process \(proxy)."
            ),
            timestamp: now,
            applicationName: proxy,
            bytesPerSecond: summary.interfaceBytesPerSecond,
            cooldownKey: key
        )
    }

    private func canEmit(cooldownKey: String, now: Date, cooldown: TimeInterval) -> Bool {
        guard let last = lastEmittedAtByCooldownKey[cooldownKey] else { return true }
        return now.timeIntervalSince(last) >= cooldown
    }

    private mutating func markEmitted(cooldownKey: String, now: Date) {
        lastEmittedAtByCooldownKey[cooldownKey] = now
    }
}
