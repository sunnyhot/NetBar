import Foundation

/// Adaptive scheduling, cancellation, recent-sample window, manual retest
/// cooldown, and lifecycle reactions for active network diagnostics.
///
/// The coordinator schedules work; it does not decide colors, characters, or
/// copy. It owns a rolling window of recent samples and the hysteresis state
/// carried across evaluations.
@MainActor
final class NetworkHealthCoordinator {
    /// Normal background interval between automatic checks.
    static let backgroundInterval: TimeInterval = 60
    /// Faster interval while the details popover is visible.
    static let popoverVisibleInterval: TimeInterval = 15
    /// Verification burst interval after a degraded state.
    static let verificationInterval: TimeInterval = 10
    /// Maximum duration the verification burst stays active.
    static let verificationMaxDuration: TimeInterval = 120
    /// Cooldown for user-initiated retests.
    static let retestCooldown: TimeInterval = 10

    private let probe: NetworkHealthProbing
    private let thresholds: NetworkHealthThresholds
    private let now: () -> Date

    /// Rolling window of recent samples (excludes cancellations).
    private(set) var recentSamples: [NetworkHealthProbeSample] = []
    /// Hysteresis state carried across evaluations.
    private var hysteresis = NetworkHealthHysteresis.initial

    private var timer: Timer?
    private var inFlightTask: Task<Void, Never>?

    /// Scheduling inputs, updated via `update(...)`.
    private var isEnabled = false
    private var isDetailWindowVisible = false
    private var isLowPowerMode = false
    private var isScreenLocked = false

    /// Verification burst tracking.
    private var verificationStartedAt: Date?

    /// Manual retest tracking.
    private(set) var isRetestInProgress = false
    private var lastRetestAt: Date?

    /// Passive evidence most recently pushed by the monitor.
    private var passiveMetrics = NetworkHealthMetrics.unknown
    private var passiveNotices: [NetworkHealthNotice] = []

    /// The latest published snapshot. Always reflects either fresh active
    /// evidence (with expiry) or a local-only conclusion.
    private(set) var currentSnapshot: NetworkHealthSnapshot

    /// Called whenever `currentSnapshot` changes so the owning monitor can
    /// republish it on its `@Published` property.
    var onSnapshotChange: ((NetworkHealthSnapshot) -> Void)?

    init(
        probe: NetworkHealthProbing = LiveNetworkHealthProbe(),
        thresholds: NetworkHealthThresholds = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.probe = probe
        self.thresholds = thresholds
        self.now = now
        // Do NOT call now() here: doing so consumes a tick from the injected
        // clock during the owning monitor's init, which desamples timed tests.
        // The snapshot is initialized lazily on first use / wiring.
        currentSnapshot = .localOnlyHealthy(now: Date(timeIntervalSince1970: 0))
    }

    // MARK: - Scheduling input

    /// Update scheduling inputs and reschedule as needed. Called by the monitor
    /// whenever visibility, power, lock, or the enabled setting changes.
    func update(
        isEnabled: Bool,
        isDetailWindowVisible: Bool,
        isLowPowerMode: Bool,
        isScreenLocked: Bool
    ) {
        let wasEnabled = self.isEnabled
        let wasLocked = self.isScreenLocked

        self.isEnabled = isEnabled
        self.isDetailWindowVisible = isDetailWindowVisible
        self.isLowPowerMode = isLowPowerMode
        self.isScreenLocked = isScreenLocked

        // Disabling the setting cancels in-flight work and stops the timer.
        if !isEnabled {
            cancelInFlight(reason: .disabled)
            stopTimer()
            currentSnapshot = currentSnapshotWith(evidenceMode: .localOnly)
            onSnapshotChange?(currentSnapshot)
            return
        }

        // Lock/sleep: cancel in-flight work and pause the timer. Outstanding
        // cancellations are not counted as failures.
        if isScreenLocked {
            cancelInFlight(reason: .sleep)
            stopTimer()
            currentSnapshot = currentSnapshotWith(evidenceMode: .paused)
            onSnapshotChange?(currentSnapshot)
            return
        }

        // Wake/unlock: run an immediate check if the previous evidence expired.
        if wasLocked, !isScreenLocked {
            reschedule(immediate: true)
            return
        }

        // Low power: pause automatic checks but allow manual retests.
        if isLowPowerMode {
            stopTimer()
            currentSnapshot = currentSnapshotWith(evidenceMode: .paused)
            onSnapshotChange?(currentSnapshot)
            return
        }

        // Newly enabled: run an immediate check.
        if !wasEnabled, isEnabled {
            reschedule(immediate: true)
            return
        }

        reschedule()
    }

    // MARK: - Passive evidence

    /// Push the latest passive evidence from the monitor. Triggers a re-evaluation
    /// using existing active samples + new passive evidence (does not start a probe).
    func pushPassiveEvidence(
        metrics: NetworkHealthMetrics,
        notices: [NetworkHealthNotice],
        now: Date? = nil
    ) {
        passiveMetrics = metrics
        passiveNotices = notices
        reevaluate(evidenceMode: currentEvidenceMode(), now: now ?? self.now())
    }

    // MARK: - Manual retest

    /// User-initiated retest. Allowed while awake, including Low Power Mode.
    /// Has a `retestCooldown` second cooldown and cannot overlap an in-flight attempt.
    func retestNow() async {
        let instant = now()
        guard !isRetestInProgress else { return }
        if let last = lastRetestAt, instant.timeIntervalSince(last) < Self.retestCooldown {
            return
        }

        await runProbe(isManual: true, now: instant)
    }

    // MARK: - Diagnostics

    /// Human-readable diagnostics string for the diagnostics center and preferences.
    func diagnosticsStatusText(language: AppLanguage) -> String {
        if !isEnabled {
            return language.text("未启用", "Disabled")
        }
        if isScreenLocked {
            return language.text("睡眠中已暂停", "Paused (sleep)")
        }
        if isLowPowerMode {
            return language.text("低电量已暂停", "Paused (low power)")
        }
        if isRetestInProgress {
            return language.text("复测中", "Checking")
        }
        switch currentSnapshot.evidenceMode {
        case .active:
            return language.text("检测中", "Active")
        case .localOnly:
            return language.text("等待检测", "Waiting")
        case .paused:
            return language.text("已暂停", "Paused")
        case .unavailable:
            return language.text("暂不可用", "Unavailable")
        }
    }

    // MARK: - Scheduling internals

    private func reschedule(immediate: Bool = false) {
        stopTimer()

        guard isEnabled, !isScreenLocked, !isLowPowerMode else { return }

        let interval = currentInterval()
        if immediate {
            performScheduledProbe()
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performScheduledProbe()
            }
        }
    }

    private func performScheduledProbe() {
        Task { @MainActor in
            await self.runProbe(isManual: false, now: self.now())
        }
    }

    private func runProbe(isManual: Bool, now: Date) async {
        let instant = now
        isRetestInProgress = true
        publishRetestState(at: instant)

        // Run the probe off the main actor.
        let sample = await Task.detached(priority: .utility) { [probe] in
            await probe.performProbe(now: instant)
        }.value

        isRetestInProgress = false
        if isManual {
            lastRetestAt = instant
        }

        // Cancellations are not counted as failures and do not enter the window.
        if sample.outcome != .cancelled {
            appendSample(sample, now: instant)
        }

        // A fresh failure may start the verification burst.
        if sample.isFailure {
            if verificationStartedAt == nil {
                verificationStartedAt = instant
            }
        }

        reevaluate(evidenceMode: .active, now: instant)
        reschedule()
    }

    private func appendSample(_ sample: NetworkHealthProbeSample, now: Date) {
        recentSamples.append(sample)
        if recentSamples.count > thresholds.recentSampleWindow {
            recentSamples.removeFirst(recentSamples.count - thresholds.recentSampleWindow)
        }
    }

    private func reevaluate(evidenceMode: NetworkHealthEvidenceMode, now: Date) {
        let result = NetworkHealthEvaluator.evaluate(
            samples: recentSamples,
            metrics: passiveMetrics,
            notices: passiveNotices,
            previous: hysteresis,
            evidenceMode: evidenceMode,
            thresholds: thresholds,
            now: now,
            language: .english // evaluator causes are pre-localized; language not used for state
        )
        hysteresis = result.hysteresis
        var snapshot = result.snapshot
        snapshot.expiresAt = expiryDate(for: evidenceMode, now: now)
        snapshot.isRetestInProgress = isRetestInProgress
        currentSnapshot = snapshot
        onSnapshotChange?(currentSnapshot)
    }

    // MARK: - Interval computation

    /// Current automatic interval per the design's scheduling rules.
    func currentInterval() -> TimeInterval {
        if isScreenLocked || isLowPowerMode || !isEnabled {
            return Self.backgroundInterval
        }
        // Verification burst: 10s for at most 2 minutes after a degraded state.
        if let started = verificationStartedAt {
            if now().timeIntervalSince(started) < Self.verificationMaxDuration {
                return Self.verificationInterval
            }
            verificationStartedAt = nil
        }
        if isDetailWindowVisible {
            return Self.popoverVisibleInterval
        }
        return Self.backgroundInterval
    }

    private func currentEvidenceMode() -> NetworkHealthEvidenceMode {
        if !isEnabled { return .localOnly }
        if isScreenLocked || isLowPowerMode { return .paused }
        if recentSamples.isEmpty { return .localOnly }
        // Active evidence that has expired is treated as unavailable.
        if let expiresAt = currentSnapshot.expiresAt, now() >= expiresAt {
            return .unavailable
        }
        return .active
    }

    private func expiryDate(for evidenceMode: NetworkHealthEvidenceMode, now: Date) -> Date? {
        switch evidenceMode {
        case .active:
            // Evidence is fresh for one interval; the verifier keeps it current.
            return now.addingTimeInterval(currentInterval())
        case .localOnly, .paused, .unavailable:
            return nil
        }
    }

    // MARK: - Cancellation

    private enum CancellationReason {
        case disabled
        case sleep
    }

    private func cancelInFlight(reason: CancellationReason) {
        inFlightTask?.cancel()
        inFlightTask = nil
        isRetestInProgress = false
        _ = reason
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Snapshot helpers

    private func currentSnapshotWith(evidenceMode: NetworkHealthEvidenceMode) -> NetworkHealthSnapshot {
        var snapshot = currentSnapshot
        snapshot.evidenceMode = evidenceMode
        snapshot.isRetestInProgress = false
        return snapshot
    }

    private func publishRetestState(at now: Date) {
        var snapshot = currentSnapshot
        snapshot.isRetestInProgress = true
        snapshot.sampledAt = now
        currentSnapshot = snapshot
        onSnapshotChange?(currentSnapshot)
    }
}
