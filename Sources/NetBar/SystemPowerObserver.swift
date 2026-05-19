import Combine
import Foundation
import AppKit

@MainActor
final class SystemPowerObserver: ObservableObject {
    @Published private(set) var isLowPowerMode = false
    @Published private(set) var isScreenLocked = false

    private var distributedObserver: Any?
    private var wakeObserver: Any?

    init() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }

        distributedObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenLocked = true
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenLocked = false
        }
    }

    deinit {
        if let observer = distributedObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
