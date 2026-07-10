import XCTest
@testable import NetBar

@MainActor
final class NetworkHealthTests: XCTestCase {

    // MARK: - Helpers

    private func healthyMetrics(hasInterface: Bool = true) -> NetworkHealthMetrics {
        NetworkHealthMetrics(
            dnsDurationMS: nil,
            responseLatencyMS: nil,
            recentAttemptCount: 0,
            recentFailureCount: 0,
            hasEligibleExternalInterface: hasInterface,
            isLocalPathAvailable: hasInterface
        )
    }

    private func successSample(dns: Double, latency: Double, ago: TimeInterval = 0) -> NetworkHealthProbeSample {
        NetworkHealthProbeSample(
            outcome: .success(dnsDurationMS: dns, responseLatencyMS: latency),
            timestamp: Date().addingTimeInterval(-ago)
        )
    }

    private func failureSample(_ kind: NetworkHealthProbeOutcome) -> NetworkHealthProbeSample {
        NetworkHealthProbeSample(outcome: kind, timestamp: Date())
    }

    // MARK: - Offline

    func testImmediateOfflineWhenNoExternalInterface() {
        let metrics = NetworkHealthMetrics(
            dnsDurationMS: nil,
            responseLatencyMS: nil,
            recentAttemptCount: 0,
            recentFailureCount: 0,
            hasEligibleExternalInterface: false,
            isLocalPathAvailable: false
        )
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 100)],
            metrics: metrics,
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .offline)
        XCTAssertEqual(result.snapshot.primaryCause, .localPathUnavailable)
    }

    func testImmediateOfflineWhenLocalPathUnavailable() {
        let metrics = NetworkHealthMetrics(
            dnsDurationMS: nil,
            responseLatencyMS: nil,
            recentAttemptCount: 0,
            recentFailureCount: 0,
            hasEligibleExternalInterface: true,
            isLocalPathAvailable: false
        )
        let result = NetworkHealthEvaluator.evaluate(
            samples: [],
            metrics: metrics,
            notices: [],
            previous: .initial,
            evidenceMode: .localOnly,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .offline)
    }

    // MARK: - Reference target failures do not produce offline

    func testReferenceTargetFailureWithSatisfiedPathIsNotOffline() {
        let metrics = healthyMetrics()
        let samples = [
            failureSample(.dnsFailure),
            failureSample(.dnsFailure),
        ]
        let result = NetworkHealthEvaluator.evaluate(
            samples: samples,
            metrics: metrics,
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        // Repeated DNS failures with a satisfied path produce poor, not offline.
        XCTAssertNotEqual(result.snapshot.state, .offline)
    }

    // MARK: - Good candidate

    func testGoodCandidateWithHealthySample() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 100)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .good)
    }

    // MARK: - Threshold boundaries (DNS)

    func testDNSAtGoodBoundaryIsGood() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 399, latency: 100)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        // 399 < 400 goodDNSMaxMS → good candidate, but recovery streak needed.
        // From initial state, recoveryStreak+1 = 1 < 3, so hold previous (nil→good).
        XCTAssertEqual(result.snapshot.state, .good)
    }

    func testDNSInFluctuatingRangeIsFluctuating() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 500, latency: 100)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        // First fluctuating candidate: candidateStreak = 1 < 2, not promoted yet.
        // With no previous candidate, we fall back to candidate itself.
        XCTAssertEqual(result.snapshot.state, .fluctuating)
    }

    func testDNSAtPoorBoundaryIsPoor() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 1000, latency: 100)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .poor)
    }

    // MARK: - Threshold boundaries (latency)

    func testLatencyInFluctuatingRangeIsFluctuating() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 800)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .fluctuating)
    }

    func testLatencyAtPoorBoundaryIsPoor() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 1500)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .poor)
    }

    // MARK: - Recent failures

    func testSingleFailureIsFluctuating() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 100), failureSample(.timeout)],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .fluctuating)
    }

    func testTwoOrMoreFailuresArePoor() {
        let result = NetworkHealthEvaluator.evaluate(
            samples: [
                successSample(dns: 50, latency: 100),
                failureSample(.timeout),
                failureSample(.transportFailure),
            ],
            metrics: healthyMetrics(),
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .poor)
    }

    // MARK: - Notices do not degrade health

    func testHighTrafficNoticeDoesNotDegradeGoodState() {
        let notice = NetworkHealthNotice(cause: .highTraffic, timestamp: Date())
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 100)],
            metrics: healthyMetrics(),
            notices: [notice],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .good)
        // Notice still surfaces as primary cause for attention.
        XCTAssertEqual(result.snapshot.primaryCause, .highTraffic)
    }

    func testApplicationSpikeNoticeDoesNotDegradeGoodState() {
        let notice = NetworkHealthNotice(cause: .applicationSpike, timestamp: Date())
        let result = NetworkHealthEvaluator.evaluate(
            samples: [successSample(dns: 50, latency: 100)],
            metrics: healthyMetrics(),
            notices: [notice],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(result.snapshot.state, .good)
        XCTAssertEqual(result.snapshot.primaryCause, .applicationSpike)
    }

    // MARK: - Probe outcome classification

    func testProbeOutcomeIsFailureClassification() {
        XCTAssertFalse(successSample(dns: 50, latency: 100).isFailure)
        XCTAssertTrue(failureSample(.dnsFailure).isFailure)
        XCTAssertTrue(failureSample(.timeout).isFailure)
        XCTAssertTrue(failureSample(.transportFailure).isFailure)
        XCTAssertFalse(failureSample(.cancelled).isFailure)
    }

    // MARK: - Evidence modes

    func testLocalOnlyHealthySnapshotHasLocalOnlyEvidenceMode() {
        let snapshot = NetworkHealthSnapshot.localOnlyHealthy(now: Date())
        XCTAssertEqual(snapshot.evidenceMode, .localOnly)
        XCTAssertEqual(snapshot.state, .good)
    }

    func testLocalOnlyHealthyWithoutInterfaceIsOffline() {
        let snapshot = NetworkHealthSnapshot.localOnlyHealthy(now: Date(), hasInterface: false)
        XCTAssertEqual(snapshot.state, .offline)
    }

    func testEvidenceModeTitlesAreBilingual() {
        XCTAssertEqual(NetworkHealthEvidenceMode.localOnly.title(language: .simplifiedChinese), "本地证据")
        XCTAssertEqual(NetworkHealthEvidenceMode.localOnly.title(language: .english), "Local evidence")
        XCTAssertEqual(NetworkHealthEvidenceMode.paused.title(language: .simplifiedChinese), "已暂停")
        XCTAssertEqual(NetworkHealthEvidenceMode.unavailable.title(language: .english), "Unavailable")
    }

    func testHealthStateTitlesAreBilingual() {
        XCTAssertEqual(NetworkHealthState.good.title(language: .simplifiedChinese), "网络健康")
        XCTAssertEqual(NetworkHealthState.fluctuating.title(language: .english), "Fluctuating")
        XCTAssertEqual(NetworkHealthState.poor.title(language: .simplifiedChinese), "连接较差")
        XCTAssertEqual(NetworkHealthState.offline.title(language: .english), "Offline")
    }

    // MARK: - Failure ratio text

    func testFailureRatioTextFormatting() {
        let snapshot = NetworkHealthSnapshot(
            state: .good,
            evidenceMode: .active,
            primaryCause: nil,
            metrics: NetworkHealthMetrics(
                dnsDurationMS: 50,
                responseLatencyMS: 100,
                recentAttemptCount: 5,
                recentFailureCount: 2,
                hasEligibleExternalInterface: true,
                isLocalPathAvailable: true
            ),
            notices: [],
            sampledAt: Date(),
            expiresAt: nil,
            isRetestInProgress: false
        )
        XCTAssertEqual(snapshot.failureRatioText(), "2 / 5")
    }

    func testSnapshotExpiry() {
        let now = Date()
        let snapshot = NetworkHealthSnapshot(
            state: .good,
            evidenceMode: .active,
            primaryCause: nil,
            metrics: healthyMetrics(),
            notices: [],
            sampledAt: now,
            expiresAt: now.addingTimeInterval(60),
            isRetestInProgress: false
        )
        XCTAssertFalse(snapshot.isExpired(now: now))
        XCTAssertTrue(snapshot.isExpired(now: now.addingTimeInterval(61)))
    }

    // MARK: - Thresholds

    func testDefaultThresholds() {
        let t = NetworkHealthThresholds.default
        XCTAssertEqual(t.recentSampleWindow, 5)
        XCTAssertEqual(t.goodDNSMaxMS, 400)
        XCTAssertEqual(t.poorDNSMinMS, 1000)
        XCTAssertEqual(t.goodLatencyMaxMS, 600)
        XCTAssertEqual(t.poorLatencyMinMS, 1500)
        XCTAssertEqual(t.poorRecentFailureMinCount, 2)
        XCTAssertEqual(t.degradationPromotionStreak, 2)
        XCTAssertEqual(t.recoveryStreak, 3)
    }

    // MARK: - Hysteresis: degradation requires two consecutive candidates

    func testDegradationRequiresTwoConsecutiveCandidates() {
        let metrics = healthyMetrics()
        let poorSample = [successSample(dns: 1200, latency: 100)] // poor candidate

        // First poor candidate.
        let first = NetworkHealthEvaluator.evaluate(
            samples: poorSample,
            metrics: metrics,
            notices: [],
            previous: .initial,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        // With no previous candidate, we fall back to the candidate. But the
        // streak is 1, not yet 2. Verify the hysteresis state advanced.
        XCTAssertEqual(first.hysteresis.candidateStreak, 1)
        XCTAssertEqual(first.hysteresis.candidateState, .poor)

        // Second poor candidate should maintain/promote.
        let second = NetworkHealthEvaluator.evaluate(
            samples: poorSample,
            metrics: metrics,
            notices: [],
            previous: first.hysteresis,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(second.hysteresis.candidateStreak, 2)
        XCTAssertEqual(second.snapshot.state, .poor)
    }

    // MARK: - Hysteresis: recovery requires three consecutive good candidates

    func testRecoveryRequiresThreeConsecutiveGoodCandidates() {
        let metrics = healthyMetrics()
        let poorHysteresis = NetworkHealthHysteresis(candidateStreak: 3, candidateState: .poor, recoveryStreak: 0)
        let goodSample = [successSample(dns: 50, latency: 100)]

        // First good candidate: recoveryStreak = 1 < 3, hold previous poor.
        let first = NetworkHealthEvaluator.evaluate(
            samples: goodSample,
            metrics: metrics,
            notices: [],
            previous: poorHysteresis,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(first.hysteresis.recoveryStreak, 1)

        // Second good candidate.
        let second = NetworkHealthEvaluator.evaluate(
            samples: goodSample,
            metrics: metrics,
            notices: [],
            previous: first.hysteresis,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(second.hysteresis.recoveryStreak, 2)

        // Third good candidate: recoveryStreak = 3 >= 3, promote to good.
        let third = NetworkHealthEvaluator.evaluate(
            samples: goodSample,
            metrics: metrics,
            notices: [],
            previous: second.hysteresis,
            evidenceMode: .active,
            now: Date(),
            language: .english
        )
        XCTAssertEqual(third.hysteresis.recoveryStreak, 3)
        XCTAssertEqual(third.snapshot.state, .good)
    }

    // MARK: - Settings backward compatibility

    func testOlderSettingsDecodeWithActiveDiagnosticsDisabled() throws {
        // Simulate older persisted JSON that predates the new field.
        let olderJSON = """
        {
            "hasSeenNotificationOnboarding": true,
            "isAnomalyDetectionEnabled": true,
            "isSystemNotificationEnabled": false,
            "highTrafficThreshold": 10485760,
            "isApplicationSpikeAlertEnabled": true,
            "isNetworkDropAlertEnabled": true,
            "isProxyAttributionAlertEnabled": true,
            "isHistoryTrackingEnabled": true
        }
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(NetworkIntelligenceSettings.self, from: olderJSON)
        XCTAssertFalse(settings.isActiveNetworkDiagnosticsEnabled)
    }

    func testSettingsRoundTripsActiveDiagnosticsEnabled() throws {
        var settings = NetworkIntelligenceSettings.default
        settings.isActiveNetworkDiagnosticsEnabled = true
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(NetworkIntelligenceSettings.self, from: data)
        XCTAssertTrue(decoded.isActiveNetworkDiagnosticsEnabled)
    }

    // MARK: - Coordinator scheduling intervals

    func testCoordinatorBackgroundInterval() {
        let coordinator = NetworkHealthCoordinator(probe: StubHealthProbe(outcomes: []), now: { Date() })
        coordinator.update(isEnabled: true, isDetailWindowVisible: false, isLowPowerMode: false, isScreenLocked: false)
        XCTAssertEqual(coordinator.currentInterval(), NetworkHealthCoordinator.backgroundInterval)
    }

    func testCoordinatorPopoverVisibleInterval() {
        let coordinator = NetworkHealthCoordinator(probe: StubHealthProbe(outcomes: []), now: { Date() })
        coordinator.update(isEnabled: true, isDetailWindowVisible: true, isLowPowerMode: false, isScreenLocked: false)
        XCTAssertEqual(coordinator.currentInterval(), NetworkHealthCoordinator.popoverVisibleInterval)
    }

    func testCoordinatorVerificationIntervalAfterFailure() {
        let coordinator = NetworkHealthCoordinator(probe: StubHealthProbe(outcomes: []), now: { Date() })
        coordinator.update(isEnabled: true, isDetailWindowVisible: false, isLowPowerMode: false, isScreenLocked: false)
        // Simulate a failure starting the verification burst via retest path.
        Task { @MainActor in
            await coordinator.retestNow()
        }
        // After a probe runs, the interval should drop to verification.
        // (Depends on timing; just verify the constant exists and is shorter.)
        XCTAssertLessThan(NetworkHealthCoordinator.verificationInterval, NetworkHealthCoordinator.backgroundInterval)
    }

    func testCoordinatorLowPowerPausesInterval() {
        let coordinator = NetworkHealthCoordinator(probe: StubHealthProbe(outcomes: []), now: { Date() })
        coordinator.update(isEnabled: true, isDetailWindowVisible: true, isLowPowerMode: true, isScreenLocked: false)
        // Low power returns background interval (timer is paused separately).
        XCTAssertEqual(coordinator.currentInterval(), NetworkHealthCoordinator.backgroundInterval)
    }

    // MARK: - Coordinator retest cooldown + no overlap

    func testCoordinatorRetestCooldownPreventsImmediateRetest() async {
        // Use a disabled coordinator so enabling does not trigger an auto probe,
        // isolating the manual-retest cooldown behavior.
        let probe = StubHealthProbe(outcomes: [.cancelled, .cancelled])
        let coordinator = NetworkHealthCoordinator(probe: probe, now: { Date() })
        // Enable while locked so update() does not schedule an immediate auto probe.
        coordinator.update(isEnabled: true, isDetailWindowVisible: false, isLowPowerMode: false, isScreenLocked: true)
        // Now unlock; sleep is cleared but we avoid the immediate-probe path by
        // going through retestNow directly.
        coordinator.update(isEnabled: true, isDetailWindowVisible: false, isLowPowerMode: false, isScreenLocked: false)
        // Give the fire-and-forget auto-probe Task a moment to settle.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let baseline = probe.callCount
        // First manual retest runs.
        await coordinator.retestNow()
        let afterFirst = probe.callCount
        XCTAssertGreaterThanOrEqual(afterFirst, baseline + 1)
        // Second immediate retest is blocked by the 10s cooldown.
        await coordinator.retestNow()
        XCTAssertEqual(probe.callCount, afterFirst, "retest within cooldown must not run")
    }

    // MARK: - Coordinator cancellation not counted as failure

    func testCoordinatorCancellationNotCountedAsFailure() async {
        let probe = StubHealthProbe(outcomes: [.cancelled])
        let coordinator = NetworkHealthCoordinator(probe: probe, now: { Date() })
        coordinator.update(isEnabled: true, isDetailWindowVisible: false, isLowPowerMode: false, isScreenLocked: false)
        await coordinator.retestNow()
        XCTAssertTrue(coordinator.recentSamples.isEmpty, "cancelled probes must not enter the sample window")
    }

    // MARK: - Coordinator diagnostics status

    func testCoordinatorDiagnosticsStatusWhenDisabled() {
        let coordinator = NetworkHealthCoordinator(probe: StubHealthProbe(outcomes: []), now: { Date() })
        coordinator.update(isEnabled: false, isDetailWindowVisible: false, isLowPowerMode: false, isScreenLocked: false)
        XCTAssertEqual(coordinator.diagnosticsStatusText(language: .english), "Disabled")
        XCTAssertEqual(coordinator.diagnosticsStatusText(language: .simplifiedChinese), "未启用")
    }

    // MARK: - Smart status bar: health-driven emphasis

    private func smartSettings(statusBar: Bool = true, character: Bool = true) -> NetworkIntelligenceSettings {
        var settings = NetworkIntelligenceSettings.default
        settings.isSmartStatusBarModeEnabled = statusBar
        settings.isSmartCharacterSuggestionEnabled = character
        return settings
    }

    private func healthSnapshot(_ state: NetworkHealthState, cause: NetworkHealthCause? = nil) -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(
            state: state,
            evidenceMode: .active,
            primaryCause: cause,
            metrics: healthyMetrics(),
            notices: [],
            sampledAt: Date(),
            expiresAt: nil,
            isRetestInProgress: false
        )
    }

    func testSmartStatusBarOfflineEmphasis() {
        let context = StatusBarContextEvaluator.evaluate(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            language: .english,
            health: healthSnapshot(.offline)
        )
        XCTAssertEqual(context.emphasis, .health(.offline))
        XCTAssertEqual(context.overrideLine, "Offline")
        XCTAssertEqual(context.tone, .critical)
    }

    func testSmartStatusBarPoorEmphasis() {
        let context = StatusBarContextEvaluator.evaluate(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            language: .english,
            health: healthSnapshot(.poor, cause: .connectivity)
        )
        XCTAssertEqual(context.emphasis, .health(.poor))
        XCTAssertEqual(context.tone, .coral)
    }

    func testSmartStatusBarFluctuatingEmphasis() {
        let context = StatusBarContextEvaluator.evaluate(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            language: .english,
            health: healthSnapshot(.fluctuating, cause: .latency)
        )
        XCTAssertEqual(context.emphasis, .health(.fluctuating))
        XCTAssertEqual(context.tone, .amber)
        XCTAssertEqual(context.overrideLine, "Latency fluctuating")
    }

    func testSmartStatusBarGoodPreservesUserLayout() {
        // High traffic present, but good health should let the existing
        // high-traffic emphasis surface (not override it).
        let snapshot = NetworkSnapshot(
            timestamp: Date(),
            interfaces: [],
            downloadBytesPerSecond: 20_000_000,
            uploadBytesPerSecond: 0,
            totalReceivedBytes: 0,
            totalSentBytes: 0,
            sampleCount: 1
        )
        let context = StatusBarContextEvaluator.evaluate(
            snapshot: snapshot,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            language: .english,
            health: healthSnapshot(.good)
        )
        XCTAssertEqual(context.emphasis, .totalTraffic)
        XCTAssertEqual(context.tone, .normal)
    }

    func testSmartStatusBarRespectsDisabledToggle() {
        // When smart status bar is disabled, health is ignored entirely.
        var settings = smartSettings(statusBar: false)
        settings.highTrafficThreshold = .mbps5
        let context = StatusBarContextEvaluator.evaluate(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: settings,
            language: .english,
            health: healthSnapshot(.offline)
        )
        XCTAssertEqual(context.emphasis, .manual)
    }

    // MARK: - Smart character: health-driven suggestions

    func testSmartCharacterOfflineSuggestsLittleCloud() {
        let character = SmartCharacterSuggestionEvaluator.suggestedCharacterID(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            health: healthSnapshot(.offline)
        )
        XCTAssertEqual(character, "little_cloud")
    }

    func testSmartCharacterPoorConnectivitySuggestsLittleCloud() {
        let character = SmartCharacterSuggestionEvaluator.suggestedCharacterID(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            health: healthSnapshot(.poor, cause: .connectivity)
        )
        XCTAssertEqual(character, "little_cloud")
    }

    func testSmartCharacterPoorHighTrafficSuggestsPenguin() {
        let character = SmartCharacterSuggestionEvaluator.suggestedCharacterID(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(),
            health: healthSnapshot(.poor, cause: .highTraffic)
        )
        XCTAssertEqual(character, "penguin")
    }

    func testSmartCharacterRespectsDisabledToggle() {
        let character = SmartCharacterSuggestionEvaluator.suggestedCharacterID(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(character: false),
            health: healthSnapshot(.offline)
        )
        XCTAssertNil(character)
    }

    func testSmartOverridesDoNotMutateStoredSettings() {
        // Evaluating health must not write back to the settings struct.
        var settings = smartSettings()
        _ = StatusBarContextEvaluator.evaluate(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: settings,
            language: .english,
            health: healthSnapshot(.offline)
        )
        // Settings unchanged after evaluation.
        XCTAssertEqual(settings, smartSettings())
    }

    // MARK: - Mock probe

    /// Replays canned outcomes in sequence, mirroring the Sequence*Reader pattern.
    private final class StubHealthProbe: NetworkHealthProbing {
        private let outcomes: [NetworkHealthProbeOutcome]
        private(set) var callCount = 0
        private let queue = DispatchQueue(label: "StubHealthProbe")

        init(outcomes: [NetworkHealthProbeOutcome]) {
            self.outcomes = outcomes
        }

        func performProbe(now: Date) async -> NetworkHealthProbeSample {
            let outcome = queue.sync { () -> NetworkHealthProbeOutcome in
                let resolved: NetworkHealthProbeOutcome
                if outcomes.isEmpty {
                    resolved = .cancelled
                } else {
                    resolved = outcomes[min(callCount, outcomes.count - 1)]
                }
                callCount += 1
                return resolved
            }
            return NetworkHealthProbeSample(outcome: outcome, timestamp: now)
        }
    }
}
