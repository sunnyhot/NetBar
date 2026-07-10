import Foundation

/// Hysteresis counters persisted across evaluations by the coordinator. The
/// evaluator itself is stateless; it returns updated counters for the caller to
/// hold and pass back next round.
struct NetworkHealthHysteresis: Equatable {
    var candidateStreak: Int
    var candidateState: NetworkHealthState?
    var recoveryStreak: Int

    static let initial = NetworkHealthHysteresis(candidateStreak: 0, candidateState: nil, recoveryStreak: 0)
}

/// Result of a single evaluation pass: the snapshot to publish plus the
/// hysteresis counters to carry forward.
struct NetworkHealthEvaluationResult: Equatable {
    let snapshot: NetworkHealthSnapshot
    let hysteresis: NetworkHealthHysteresis
}

/// Pure rule evaluation with presentation-independent hysteresis. The evaluator
/// receives values; it does not start work, read preferences, or mutate UI
/// state. All thresholds live in the injected `NetworkHealthThresholds`.
enum NetworkHealthEvaluator {
    /// Evaluate a health conclusion from active samples + passive evidence.
    ///
    /// - Parameters:
    ///   - samples: The rolling recent probe samples (already trimmed to the
    ///     window and filtered to exclude cancellations). May be empty when
    ///     only local evidence is available.
    ///   - metrics: Passive evidence (local path / external interface).
    ///   - notices: Non-quality context (high traffic, app spikes, etc.).
    ///   - previous: The previously published hysteresis state.
    ///   - evidenceMode: How this conclusion was reached.
    ///   - thresholds: Boundary values (injectable for tests).
    ///   - now: The current time.
    ///   - language: For localized cause/recommendation text.
    static func evaluate(
        samples: [NetworkHealthProbeSample],
        metrics: NetworkHealthMetrics,
        notices: [NetworkHealthNotice],
        previous: NetworkHealthHysteresis,
        evidenceMode: NetworkHealthEvidenceMode,
        thresholds: NetworkHealthThresholds = .default,
        now: Date,
        language: AppLanguage
    ) -> NetworkHealthEvaluationResult {
        // 1. Immediate offline: macOS reports an unsatisfied path or there is
        //    no eligible external interface. This bypasses hysteresis entirely.
        if !metrics.hasEligibleExternalInterface || !metrics.isLocalPathAvailable {
            return offline(metrics: metrics, notices: notices, now: now, language: language)
        }

        // 2. Compute the candidate state from available evidence.
        let candidate = candidateState(
            samples: samples,
            metrics: metrics,
            thresholds: thresholds,
            language: language
        )

        // 3. Apply hysteresis to decide the published state.
        let publishedState = applyHysteresis(
            candidate: candidate,
            previous: previous,
            thresholds: thresholds
        )
        let nextHysteresis = nextHysteresisState(
            candidate: candidate,
            published: publishedState,
            previous: previous,
            thresholds: thresholds
        )

        // 4. Build the cause and snapshot.
        let cause = causeFor(
            state: publishedState,
            candidate: candidate,
            metrics: metrics,
            samples: samples,
            notices: notices,
            language: language
        )

        let snapshot = NetworkHealthSnapshot(
            state: publishedState,
            evidenceMode: evidenceMode,
            primaryCause: cause,
            metrics: mergedMetrics(metrics: metrics, samples: samples, thresholds: thresholds),
            notices: notices,
            sampledAt: now,
            expiresAt: nil, // coordinator attaches expiry based on schedule
            isRetestInProgress: false
        )

        return NetworkHealthEvaluationResult(snapshot: snapshot, hysteresis: nextHysteresis)
    }

    // MARK: - Immediate offline

    private static func offline(
        metrics: NetworkHealthMetrics,
        notices: [NetworkHealthNotice],
        now: Date,
        language: AppLanguage
    ) -> NetworkHealthEvaluationResult {
        let snapshot = NetworkHealthSnapshot(
            state: .offline,
            evidenceMode: .localOnly,
            primaryCause: .localPathUnavailable,
            metrics: metrics,
            notices: notices,
            sampledAt: now,
            expiresAt: nil,
            isRetestInProgress: false
        )
        return NetworkHealthEvaluationResult(
            snapshot: snapshot,
            hysteresis: .initial
        )
    }

    // MARK: - Candidate state (no hysteresis)

    /// Compute the "instantaneous" candidate state from the latest evidence.
    private static func candidateState(
        samples: [NetworkHealthProbeSample],
        metrics: NetworkHealthMetrics,
        thresholds: NetworkHealthThresholds,
        language: AppLanguage
    ) -> NetworkHealthState {
        // No active evidence at all: base the candidate on local path only.
        guard let latest = samples.last else {
            return .good
        }

        switch latest.outcome {
        case .success(let dns, let latency):
            return candidateFromSuccess(
                dns: dns,
                latency: latency,
                recentFailures: recentFailureCount(samples: samples, thresholds: thresholds),
                thresholds: thresholds
            )
        case .dnsFailure:
            // A single DNS failure is treated as fluctuating at minimum.
            let failures = recentFailureCount(samples: samples, thresholds: thresholds)
            return failures >= thresholds.poorRecentFailureMinCount ? .poor : .fluctuating
        case .timeout, .transportFailure:
            let failures = recentFailureCount(samples: samples, thresholds: thresholds)
            return failures >= thresholds.poorRecentFailureMinCount ? .poor : .fluctuating
        case .cancelled:
            // Should not reach evaluation (coordinator filters cancellations),
            // but if it does, keep the prior-leaning neutral candidate.
            return .good
        }
    }

    private static func candidateFromSuccess(
        dns: Double,
        latency: Double,
        recentFailures: Int,
        thresholds: NetworkHealthThresholds
    ) -> NetworkHealthState {
        // Poor signals dominate.
        if dns >= thresholds.poorDNSMinMS || latency >= thresholds.poorLatencyMinMS {
            return .poor
        }
        if recentFailures >= thresholds.poorRecentFailureMinCount {
            return .poor
        }
        // Fluctuating signals.
        if dns >= thresholds.goodDNSMaxMS || latency >= thresholds.goodLatencyMaxMS {
            return .fluctuating
        }
        if recentFailures >= thresholds.fluctuatingRecentFailureCount {
            return .fluctuating
        }
        return .good
    }

    private static func recentFailureCount(
        samples: [NetworkHealthProbeSample],
        thresholds: NetworkHealthThresholds
    ) -> Int {
        let window = samples.suffix(thresholds.recentSampleWindow)
        return window.filter { $0.isFailure }.count
    }

    // MARK: - Hysteresis

    /// Apply hysteresis so the menu bar does not flap.
    ///
    /// - Immediate offline is handled earlier and bypasses hysteresis.
    /// - Recovering to `good` requires `recoveryStreak` consecutive good candidates.
    /// - A degradation requires `degradationPromotionStreak` consecutive
    ///   candidates before it is promoted.
    private static func applyHysteresis(
        candidate: NetworkHealthState,
        previous: NetworkHealthHysteresis,
        thresholds: NetworkHealthThresholds
    ) -> NetworkHealthState {
        // Good candidates promote only after the recovery streak is satisfied.
        if candidate == .good {
            if previous.recoveryStreak + 1 >= thresholds.recoveryStreak {
                return .good
            }
            // Not enough consecutive good samples yet; hold the last published
            // non-good state if we have one, otherwise allow good.
            return previous.candidateState ?? .good
        }

        // Degradation: requires consecutive candidates before promotion.
        if candidate == previous.candidateState {
            if previous.candidateStreak + 1 >= thresholds.degradationPromotionStreak {
                return candidate
            }
            return previous.candidateState ?? candidate
        }

        // Candidate changed direction but is not good; reset toward the new
        // candidate without promoting yet.
        return previous.candidateState ?? candidate
    }

    /// Compute the next hysteresis state to carry forward.
    private static func nextHysteresisState(
        candidate: NetworkHealthState,
        published: NetworkHealthState,
        previous: NetworkHealthHysteresis,
        thresholds: NetworkHealthThresholds
    ) -> NetworkHealthHysteresis {
        if candidate == .good {
            let streak = (previous.candidateState == .good ? previous.recoveryStreak : 0) + 1
            return NetworkHealthHysteresis(
                candidateStreak: 0,
                candidateState: .good,
                recoveryStreak: streak
            )
        }

        if candidate == previous.candidateState {
            let streak = previous.candidateStreak + 1
            return NetworkHealthHysteresis(
                candidateStreak: streak,
                candidateState: candidate,
                recoveryStreak: 0
            )
        }

        return NetworkHealthHysteresis(
            candidateStreak: 1,
            candidateState: candidate,
            recoveryStreak: 0
        )
    }

    // MARK: - Cause

    private static func causeFor(
        state: NetworkHealthState,
        candidate: NetworkHealthState,
        metrics: NetworkHealthMetrics,
        samples: [NetworkHealthProbeSample],
        notices: [NetworkHealthNotice],
        language: AppLanguage
    ) -> NetworkHealthCause? {
        switch state {
        case .offline:
            return .localPathUnavailable
        case .poor:
            // Prefer an active-evidence cause, then fall back to a notice.
            if let dns = metrics.dnsDurationMS, dns >= 1000 {
                return .dns
            }
            if let latency = metrics.responseLatencyMS, latency >= 1500 {
                return .latency
            }
            if let noticeCause = notices.first?.cause {
                return noticeCause
            }
            return .connectivity
        case .fluctuating:
            if let dns = metrics.dnsDurationMS, dns >= 400 {
                return .dns
            }
            if let latency = metrics.responseLatencyMS, latency >= 600 {
                return .latency
            }
            if let noticeCause = notices.first?.cause {
                return noticeCause
            }
            return .latency
        case .good:
            // Good state has no primary cause unless a notice wants attention.
            return notices.first?.cause
        }
    }

    // MARK: - Metrics merging

    /// Fold the latest active measurements into the passive metrics so the
    /// published snapshot reflects both sources.
    private static func mergedMetrics(
        metrics: NetworkHealthMetrics,
        samples: [NetworkHealthProbeSample],
        thresholds: NetworkHealthThresholds
    ) -> NetworkHealthMetrics {
        var merged = metrics
        let window = samples.suffix(thresholds.recentSampleWindow)
        merged.recentAttemptCount = window.count
        merged.recentFailureCount = window.filter { $0.isFailure }.count
        if let latest = samples.last, case let .success(dns, latency) = latest.outcome {
            merged.dnsDurationMS = dns
            merged.responseLatencyMS = latency
        }
        return merged
    }
}
