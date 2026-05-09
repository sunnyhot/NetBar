import XCTest
@testable import NetBar

@MainActor
final class PreferencesAndPresentationTests: XCTestCase {
    func testStatusBarUsesNativeTitleByDefault() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsBackground = false

        let presentation = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 42_000, upload: 9_500),
            settings: settings
        )

        XCTAssertEqual(presentation.kind, .nativeTitle)
        XCTAssertEqual(presentation.lines.count, 2)
        XCTAssertGreaterThanOrEqual(
            presentation.width,
            StatusBarDisplayRenderer.stableMinimumWidth(settings: settings)
        )
    }

    func testStatusBarFallsBackToRetinaImageOnlyForBackgrounds() {
        let settings = StatusBarSettings(defaults: isolatedDefaults())
        settings.showsBackground = true
        settings.backgroundOpacity = 0.7

        let presentation = StatusBarDisplayRenderer.presentation(
            snapshot: sampleSnapshot(download: 1_500_000, upload: 750_000),
            settings: settings
        )

        XCTAssertEqual(presentation.kind, .retinaImage)
    }

    func testApplicationListSearchSortAndHideSystemProcesses() {
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: FakeLoginItemManager()
        )
        preferences.hidesSystemProcesses = true
        preferences.applicationSort = .name

        let state = ApplicationTrafficState(
            timestamp: Date(timeIntervalSince1970: 10),
            applications: [
                app("networkd", processNames: ["networkd"], download: 9_000, upload: 1_000, total: 10_000),
                app("Xcode", processNames: ["Xcode"], download: 5_000, upload: 2_000, total: 7_000),
                app("Arc", processNames: ["Arc"], download: 2_000, upload: 4_000, total: 6_000)
            ],
            sampleCount: 3,
            isRefreshing: false,
            errorMessage: nil
        )

        let visible = ApplicationTrafficPresentation.visibleApplications(
            from: state,
            preferences: preferences,
            searchText: "c"
        )

        XCTAssertEqual(visible.map(\.displayName), ["Arc", "Xcode"])
    }

    func testLoginItemFailureRestoresObservedState() async {
        let manager = FakeLoginItemManager()
        let preferences = AppPreferences(
            defaults: isolatedDefaults(),
            loginItemManager: manager
        )

        await preferences.setLaunchesAtLogin(true)
        XCTAssertTrue(preferences.launchesAtLogin)
        XCTAssertNil(preferences.loginItemErrorMessage)

        manager.nextError = FakeLoginItemError()
        await preferences.setLaunchesAtLogin(false)

        XCTAssertTrue(preferences.launchesAtLogin)
        XCTAssertNotNil(preferences.loginItemErrorMessage)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "NetBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func sampleSnapshot(download: Double, upload: Double) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: Date(timeIntervalSince1970: 20),
            interfaces: [],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: UInt64(download),
            totalSentBytes: UInt64(upload),
            sampleCount: 2
        )
    }

    private func app(
        _ displayName: String,
        processNames: [String],
        download: Double,
        upload: Double,
        total: UInt64
    ) -> ApplicationTrafficRate {
        ApplicationTrafficRate(
            id: displayName,
            displayName: displayName,
            processNames: processNames,
            pids: [123],
            downloadBytesPerSecond: download,
            uploadBytesPerSecond: upload,
            totalReceivedBytes: total / 2,
            totalSentBytes: total / 2
        )
    }
}

private final class FakeLoginItemManager: LoginItemManaging {
    var isEnabled = false
    var nextError: Error?

    func refreshStatus() -> Bool {
        isEnabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if let nextError {
            self.nextError = nil
            throw nextError
        }
        self.isEnabled = isEnabled
    }
}

private struct FakeLoginItemError: LocalizedError {
    var errorDescription: String? {
        "Login item update failed"
    }
}
