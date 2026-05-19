import AppKit
import Foundation
import IOKit.ps

@MainActor
final class PowerStateManager: ObservableObject {
    @Published private(set) var isLowPowerMode = false
    @Published private(set) var isScreenLocked = false
    @Published private(set) var isOnBattery = false

    private var powerSourceTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        updatePowerSource()
        setupObservers()
        schedulePowerSourcePolling()
    }

    deinit {
        powerSourceTimer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver(_:))
    }

    private func setupObservers() {
        let nc = NotificationCenter.default

        observers.append(nc.addObserver(forName: NSNotification.Name("NSProcessInfoPowerStateDidChangeNotification"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        })

        observers.append(nc.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = true
            }
        })

        observers.append(nc.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = false
            }
        })
    }

    private func updatePowerSource() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            isOnBattery = false
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeRetainedValue() as? [String: Any]
            else { continue }
            if let type = desc[kIOPSTypeKey as String] as? String, type == "InternalBattery" {
                isOnBattery = (desc[kIOPSPowerSourceStateKey as String] as? String) != "AC Power"
                break
            }
        }
    }

    private func schedulePowerSourcePolling() {
        powerSourceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePowerSource()
            }
        }
    }

    var effectiveInterfaceInterval: TimeInterval {
        if isScreenLocked { return 5.0 }
        let base: TimeInterval = 1.0
        if isLowPowerMode { return base * 2 }
        if isOnBattery { return base * 1.5 }
        return base
    }

    var effectiveAppTrafficInterval: TimeInterval {
        if isScreenLocked { return 5.0 }
        let base: TimeInterval = 5.0
        if isLowPowerMode { return base * 2 }
        if isOnBattery { return base * 1.5 }
        return base
    }

    var shouldPauseAnimation: Bool {
        isScreenLocked
    }

    var animationSpeedFactor: Double {
        if isLowPowerMode { return 0.5 }
        if isOnBattery { return 0.7 }
        return 1.0
    }
}
