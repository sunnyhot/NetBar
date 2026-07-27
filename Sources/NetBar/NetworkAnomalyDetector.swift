import Foundation

struct NetworkAnomalyDetector {
    private var highTrafficStartedAt: Date?
    private var lastEmittedAtByCooldownKey: [String: Date] = [:]

    mutating func detect(
        snapshot: NetworkSnapshot,
        settings: NetworkIntelligenceSettings,
        now: Date,
        language: AppLanguage = .simplifiedChinese
    ) -> [NetworkAnomalyEvent] {
        guard settings.isAnomalyDetectionEnabled else {
            resetSustainedTracking()
            return []
        }

        let totalSpeed = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
        return highTrafficEvent(
            totalSpeed: totalSpeed,
            settings: settings,
            now: now,
            language: language
        ).map { [$0] } ?? []
    }

    private mutating func resetSustainedTracking() {
        highTrafficStartedAt = nil
    }

    private mutating func highTrafficEvent(
        totalSpeed: Double,
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

        markEmitted(cooldownKey: key, now: now)
        let message = language.text(
            "当前总速率约 \(ByteFormat.speed(totalSpeed))。",
            "Current total speed is about \(ByteFormat.speed(totalSpeed))."
        )

        return NetworkAnomalyEvent(
            kind: .highTraffic,
            title: NetworkAnomalyKind.highTraffic.title(language: language),
            message: message,
            timestamp: now
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
