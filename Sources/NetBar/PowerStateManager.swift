import AppKit
import Combine
import Foundation
import IOKit.ps

@MainActor
final class PowerStateManager: ObservableObject {
    @Published private(set) var isLowPowerMode = false
    @Published private(set) var isScreenLocked = false
    @Published private(set) var isOnBattery = false

    static let powerModeChanged = Notification.Name("powerModeChanged")
    static let screenLockChanged = Notification.Name("screenLockChanged")
    static let powerSourceChanged = Notification.Name("powerSourceChanged")

    init() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        isOnBattery = checkBatteryStatus()

        let nc = NotificationCenter.default

        nc.addObserver(forName: Notification.Name("NSProcessInfoPowerStateDidChange"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateLowPowerMode()
            }
        }

        nc.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateScreenLocked(true)
            }
        }
        nc.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateScreenLocked(false)
            }
        }

        // IOKit power source notification via CFRunLoop
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let runLoopSource = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context else { return }
                let manager = Unmanaged<PowerStateManager>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in
                    manager.updatePowerSource()
                }
            },
            context
        )
        if let source = runLoopSource?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    var shouldThrottle: Bool {
        isLowPowerMode || isScreenLocked
    }

    // NetworkMonitor: base 1s → locked 5s, low power ×2
    func adjustedNetworkInterval(_ base: TimeInterval) -> TimeInterval {
        var interval = base
        if isScreenLocked {
            interval = 5.0
        }
        if isLowPowerMode {
            interval *= 2.0
        }
        return interval
    }

    // App traffic: base 5s → locked 10s, low power ×2
    func adjustedAppTrafficInterval(_ base: TimeInterval) -> TimeInterval {
        var interval = base
        if isScreenLocked {
            interval = 10.0
        }
        if isLowPowerMode {
            interval *= 2.0
        }
        return interval
    }

    // RunCatAnimation: max FPS cap
    func animationFPSMultiplier() -> Double {
        if isScreenLocked { return 0.0 }
        if isLowPowerMode { return 0.5 }
        if isOnBattery { return 0.75 }
        return 1.0
    }

    private func updateLowPowerMode() {
        let newValue = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard newValue != isLowPowerMode else { return }
        isLowPowerMode = newValue
        NotificationCenter.default.post(name: Self.powerModeChanged, object: self)
    }

    private func updateScreenLocked(_ locked: Bool) {
        guard locked != isScreenLocked else { return }
        isScreenLocked = locked
        NotificationCenter.default.post(name: Self.screenLockChanged, object: self)
    }

    private func updatePowerSource() {
        let newValue = checkBatteryStatus()
        guard newValue != isOnBattery else { return }
        isOnBattery = newValue
        NotificationCenter.default.post(name: Self.powerSourceChanged, object: self)
    }

    private func checkBatteryStatus() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] {
                let type = desc[kIOPSTypeKey] as? String
                if type == kIOPSInternalBatteryType {
                    let state = desc[kIOPSPowerSourceStateKey] as? String
                    return state != kIOPSACPowerValue
                }
            }
        }
        return false
    }
}
