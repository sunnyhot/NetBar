import XCTest
@testable import NetBar

@MainActor
final class NetworkHealthTests: XCTestCase {
    private func metrics(
        hasInterface: Bool = true,
        hasLocalPath: Bool = true
    ) -> NetworkHealthMetrics {
        NetworkHealthMetrics(
            hasEligibleExternalInterface: hasInterface,
            isLocalPathAvailable: hasLocalPath
        )
    }

    private func healthSnapshot(_ state: NetworkHealthState) -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(
            state: state,
            primaryCause: nil,
            metrics: metrics(),
            notices: [],
            sampledAt: Date()
        )
    }

    private func smartSettings(
        statusBar: Bool = true,
        character: Bool = true
    ) -> NetworkIntelligenceSettings {
        var settings = NetworkIntelligenceSettings.default
        settings.isSmartStatusBarModeEnabled = statusBar
        settings.isSmartCharacterSuggestionEnabled = character
        return settings
    }

    func testLocalInterfaceAvailabilityProducesGoodState() {
        let snapshot = NetworkHealthSnapshot.localOnly(
            metrics: metrics(),
            notices: [],
            now: Date()
        )

        XCTAssertEqual(snapshot.state, .good)
        XCTAssertNil(snapshot.primaryCause)
    }

    func testMissingExternalInterfaceProducesOfflineState() {
        let snapshot = NetworkHealthSnapshot.localOnly(
            metrics: metrics(hasInterface: false, hasLocalPath: false),
            notices: [],
            now: Date()
        )

        XCTAssertEqual(snapshot.state, .offline)
        XCTAssertEqual(snapshot.primaryCause, .localPathUnavailable)
    }

    func testUnavailableLocalPathProducesOfflineState() {
        let snapshot = NetworkHealthSnapshot.localOnly(
            metrics: metrics(hasInterface: true, hasLocalPath: false),
            notices: [],
            now: Date()
        )

        XCTAssertEqual(snapshot.state, .offline)
        XCTAssertEqual(snapshot.primaryCause, .localPathUnavailable)
    }

    func testNoticeDoesNotDegradeAvailableLocalState() {
        let notice = NetworkHealthNotice(cause: .highTraffic, timestamp: Date())
        let snapshot = NetworkHealthSnapshot.localOnly(
            metrics: metrics(),
            notices: [notice],
            now: Date()
        )

        XCTAssertEqual(snapshot.state, .good)
        XCTAssertEqual(snapshot.primaryCause, .highTraffic)
        XCTAssertEqual(snapshot.notices, [notice])
    }

    func testHealthStateTitlesAreBilingual() {
        XCTAssertEqual(NetworkHealthState.good.title(language: .simplifiedChinese), "网络可用")
        XCTAssertEqual(NetworkHealthState.good.title(language: .english), "Network available")
        XCTAssertEqual(NetworkHealthState.offline.title(language: .english), "Offline")
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

    func testSmartStatusBarGoodPreservesTrafficPresentation() {
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
        let context = StatusBarContextEvaluator.evaluate(
            snapshot: .empty,
            appTraffic: .empty,
            intelligenceSummary: .empty,
            settings: smartSettings(statusBar: false),
            language: .english,
            health: healthSnapshot(.offline)
        )

        XCTAssertEqual(context.emphasis, .manual)
    }

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
}
