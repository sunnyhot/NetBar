import Foundation

// MARK: - Animation Speed Mapper

/// Maps a system metric value to an `ActivityLevel` for animation speed control.
/// Each source has its own thresholds tuned for a good user experience.
enum AnimationSpeedMapper {
    /// Maps a 0...1 metric value to an ActivityLevel.
    static func activityLevel(from metricValue: Double) -> ActivityLevel {
        if metricValue < 0.15 {
            return .idle
        } else if metricValue < 0.45 {
            return .low
        } else if metricValue < 0.75 {
            return .moderate
        } else {
            return .high
        }
    }

    /// Maps thermal state (0-3) to an ActivityLevel.
    static func activityLevel(fromThermalState state: Int) -> ActivityLevel {
        switch state {
        case 0: return .idle
        case 1: return .low
        case 2: return .moderate
        default: return .high
        }
    }

    /// Computes an auto-composite ActivityLevel by averaging normalized values from all sources.
    static func autoCompositeActivityLevel(
        cpuUsage: Double,
        memoryUsage: Double,
        thermalState: Int,
        networkActivityLevel: ActivityLevel
    ) -> ActivityLevel {
        let thermalNormalized = Double(thermalState) / 3.0
        let networkNormalized: Double = {
            switch networkActivityLevel {
            case .idle: return 0.0
            case .low: return 0.25
            case .moderate: return 0.6
            case .high: return 1.0
            }
        }()

        let composite = (cpuUsage + memoryUsage + thermalNormalized + networkNormalized) / 4.0
        return activityLevel(from: composite)
    }
}

extension AnimationSpeedMapper {
    static func activityLevel(
        fromSystemResources snapshot: SystemResourceSnapshot,
        source: AnimationSpeedSource,
        networkActivityLevel: ActivityLevel = .idle
    ) -> ActivityLevel {
        switch source {
        case .networkSpeed:
            return networkActivityLevel
        case .memoryUsage:
            return activityLevel(from: snapshot.memory.usedFraction)
        case .cpuUsage:
            return activityLevel(from: snapshot.cpu.usageFraction)
        case .thermalState:
            return activityLevel(fromThermalState: snapshot.thermal.state.animationSpeedValue)
        case .autoComposite:
            return autoCompositeActivityLevel(
                cpuUsage: snapshot.cpu.usageFraction,
                memoryUsage: snapshot.memory.usedFraction,
                thermalState: snapshot.thermal.state.animationSpeedValue,
                networkActivityLevel: networkActivityLevel
            )
        }
    }
}

private extension ThermalPressureState {
    var animationSpeedValue: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }
}
