import Foundation

struct PerformanceSamplingState: Equatable {
    let isRunning: Bool
    let isDetailWindowVisible: Bool
    let isScreenLocked: Bool
    let isLowPowerModeEnabled: Bool
    let activityLevel: NetworkActivityLevel
    let showsStatusAnimation: Bool
    let animationSpeedSource: AnimationSpeedSource
}

struct PerformanceSamplingPolicy: Equatable {
    let interfaceInterval: TimeInterval
    let isApplicationTrafficEnabled: Bool
    let applicationTrafficInterval: TimeInterval
    let systemResourceInterval: TimeInterval
    let isAnimationMetricSamplingEnabled: Bool

    static let stopped = PerformanceSamplingPolicy(
        interfaceInterval: 0,
        isApplicationTrafficEnabled: false,
        applicationTrafficInterval: 0,
        systemResourceInterval: 0,
        isAnimationMetricSamplingEnabled: false
    )
}

enum PerformanceSamplingCoordinator {
    static func policy(for state: PerformanceSamplingState) -> PerformanceSamplingPolicy {
        guard state.isRunning, !state.isScreenLocked else { return .stopped }

        let interfaceInterval = state.activityLevel.baseInterval * (state.isLowPowerModeEnabled ? 2 : 1)
        let applicationInterval: TimeInterval = state.isLowPowerModeEnabled ? 5.0 : 1.0
        let systemInterval: TimeInterval = state.isLowPowerModeEnabled ? 10.0 : 5.0
        let needsAnimationMetrics = state.showsStatusAnimation && state.animationSpeedSource != .networkSpeed

        return PerformanceSamplingPolicy(
            interfaceInterval: interfaceInterval,
            isApplicationTrafficEnabled: state.isDetailWindowVisible,
            applicationTrafficInterval: state.isDetailWindowVisible ? applicationInterval : 0,
            systemResourceInterval: systemInterval,
            isAnimationMetricSamplingEnabled: needsAnimationMetrics
        )
    }
}
