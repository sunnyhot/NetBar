import XCTest
@testable import NetBar

@MainActor
final class NetworkHealthTests: XCTestCase {
    private func healthSnapshot(_ state: NetworkHealthState) -> NetworkHealthSnapshot {
        NetworkHealthSnapshot(state: state)
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
        let snapshot = NetworkHealthSnapshot.localInterface(isAvailable: true)

        XCTAssertEqual(snapshot.state, .good)
    }

    func testMissingExternalInterfaceProducesOfflineState() {
        let snapshot = NetworkHealthSnapshot.localInterface(isAvailable: false)

        XCTAssertEqual(snapshot.state, .offline)
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
