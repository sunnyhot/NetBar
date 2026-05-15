# Pet System MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first usable NetBar pet system: pet state, interactions, reminders, three skills, a compact pet panel, and preference controls.

**Architecture:** Add a new `PetController` as an observable state machine beside the existing network monitor and status bar controller. Keep pet logic in focused files and feed it network snapshots from `StatusBarController`, while keeping `NetworkMonitor` unaware of pets. Add a separate pet panel window so the existing traffic details window remains available.

**Tech Stack:** Swift 5 mode, AppKit, SwiftUI, Combine, UserDefaults, XCTest.

---

## Working Tree Note

The current workspace has unrelated dirty changes from the previous character animation work:

- `Sources/NetBar/CustomCharacter.swift`
- `Sources/NetBar/CustomCharacterImageProcessor.swift`
- `Sources/NetBar/PreferencesWindowController.swift`
- `Sources/NetBar/RunCatAnimation.swift`
- `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

Do not revert them. When executing this plan, read these files before editing and preserve those changes. If committing task-by-task, stage only files touched by the current task.

## File Structure

- Create `Sources/NetBar/PetState.swift`
  - Pet enums, persisted settings, runtime state, cue model.
- Create `Sources/NetBar/PetSkill.swift`
  - Skill identifiers, skill metadata, skill result helpers.
- Create `Sources/NetBar/PetController.swift`
  - Observable pet state machine, persistence, reminders, interaction handling, skill execution.
- Create `Sources/NetBar/PetPanelWindowController.swift`
  - AppKit floating panel for pet UI.
- Create `Sources/NetBar/PetPanelView.swift`
  - SwiftUI pet panel with status, actions, skills, and latest cue.
- Modify `Sources/NetBar/AppDelegate.swift`
  - Own one `PetController` and pass it into status bar and preferences controllers.
- Modify `Sources/NetBar/StatusBarController.swift`
  - Feed snapshots to pet controller, route click/double-click, add pet menu commands, and show the pet panel.
- Modify `Sources/NetBar/PreferencesWindowController.swift`
  - Add a Pet tab and bind controls to `PetController.settings`.
- Modify `Tests/NetBarTests/PreferencesAndPresentationTests.swift`
  - Add unit coverage for state defaults, persistence, reminders, interactions, and skills.

---

### Task 1: Pet State And Persistence

**Files:**
- Create: `Sources/NetBar/PetState.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests for defaults and persistence**

Add these tests inside `PreferencesAndPresentationTests` before the existing helper methods:

```swift
func testPetStateDefaultsAreCalmAndEnabledRemindersAreConservative() {
    let settings = PetSettings.default
    let state = PetState.default(now: Date(timeIntervalSince1970: 10))

    XCTAssertFalse(settings.isEnabled)
    XCTAssertFalse(settings.isQuietModeEnabled)
    XCTAssertEqual(settings.personality, .healing)
    XCTAssertTrue(settings.enabledReminderIDs.contains(PetReminderKind.drinkWater.rawValue))
    XCTAssertTrue(settings.enabledSkillIDs.contains(PetSkillID.networkScout.rawValue))
    XCTAssertEqual(state.mood, .happy)
    XCTAssertEqual(state.energy, 80)
    XCTAssertEqual(state.affection, 0)
}

func testPetReminderRecordUsesStringKeysForUserDefaultsEncoding() {
    var state = PetState.default(now: Date(timeIntervalSince1970: 10))
    state.recordReminder(.highTraffic, at: Date(timeIntervalSince1970: 20))

    XCTAssertEqual(state.lastReminderAtByKind[PetReminderKind.highTraffic.rawValue], Date(timeIntervalSince1970: 20))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetStateDefaultsAreCalmAndEnabledRemindersAreConservative --filter PreferencesAndPresentationTests/testPetReminderRecordUsesStringKeysForUserDefaultsEncoding
```

Expected: compile failure because `PetSettings`, `PetState`, `PetReminderKind`, and `PetSkillID` are not defined.

- [ ] **Step 3: Add `PetState.swift`**

Create `Sources/NetBar/PetState.swift` with:

```swift
import Foundation

enum PetMood: String, Codable, CaseIterable, Identifiable {
    case happy
    case sleepy
    case excited
    case worried
    case focused
    case annoyed

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .happy:
            return language.text("开心", "Happy")
        case .sleepy:
            return language.text("困倦", "Sleepy")
        case .excited:
            return language.text("兴奋", "Excited")
        case .worried:
            return language.text("担心", "Worried")
        case .focused:
            return language.text("专注", "Focused")
        case .annoyed:
            return language.text("闹别扭", "Annoyed")
        }
    }
}

enum PetPersonality: String, Codable, CaseIterable, Identifiable {
    case healing
    case playful
    case professional

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .healing:
            return language.text("治愈", "Healing")
        case .playful:
            return language.text("活泼", "Playful")
        case .professional:
            return language.text("专业", "Professional")
        }
    }
}

enum PetInteraction: String, Codable, CaseIterable, Identifiable {
    case pet
    case feed
    case encourage
    case focus
    case play

    var id: String { rawValue }
}

enum PetReminderKind: String, Codable, CaseIterable, Identifiable {
    case drinkWater
    case restEyes
    case highTraffic

    var id: String { rawValue }

    static let defaultEnabled: Set<String> = [
        PetReminderKind.drinkWater.rawValue,
        PetReminderKind.restEyes.rawValue,
        PetReminderKind.highTraffic.rawValue
    ]

    func title(language: AppLanguage) -> String {
        switch self {
        case .drinkWater:
            return language.text("喝水", "Drink Water")
        case .restEyes:
            return language.text("休息眼睛", "Rest Eyes")
        case .highTraffic:
            return language.text("流量过高", "High Traffic")
        }
    }
}

enum PetCueKind: String, Codable, Equatable {
    case interaction
    case reminder
    case skill
    case status
}

enum PetAnimationHint: String, Codable, Equatable {
    case none
    case happyHop
    case sparkle
    case focused
    case worried
}

struct PetCue: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: PetCueKind
    let title: String
    let message: String
    let createdAt: Date
    let animationHint: PetAnimationHint

    init(
        id: UUID = UUID(),
        kind: PetCueKind,
        title: String,
        message: String,
        createdAt: Date,
        animationHint: PetAnimationHint
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.animationHint = animationHint
    }
}

struct PetSettings: Codable, Equatable {
    var isEnabled: Bool
    var isQuietModeEnabled: Bool
    var personality: PetPersonality
    var enabledReminderIDs: Set<String>
    var enabledSkillIDs: Set<String>
    var highTrafficThresholdBytesPerSecond: Double

    static let `default` = PetSettings(
        isEnabled: false,
        isQuietModeEnabled: false,
        personality: .healing,
        enabledReminderIDs: PetReminderKind.defaultEnabled,
        enabledSkillIDs: PetSkillID.defaultEnabled,
        highTrafficThresholdBytesPerSecond: 10_000_000
    )

    func isReminderEnabled(_ kind: PetReminderKind) -> Bool {
        enabledReminderIDs.contains(kind.rawValue)
    }

    func isSkillEnabled(_ skillID: PetSkillID) -> Bool {
        enabledSkillIDs.contains(skillID.rawValue)
    }
}

struct PetState: Codable, Equatable {
    var mood: PetMood
    var energy: Int
    var affection: Int
    var activeSkillID: String?
    var lastInteractionAt: Date?
    var lastReminderAtByKind: [String: Date]

    static func `default`(now: Date = Date()) -> PetState {
        PetState(
            mood: .happy,
            energy: 80,
            affection: 0,
            activeSkillID: nil,
            lastInteractionAt: nil,
            lastReminderAtByKind: [:]
        )
    }

    mutating func recordReminder(_ kind: PetReminderKind, at date: Date) {
        lastReminderAtByKind[kind.rawValue] = date
    }

    func lastReminderDate(for kind: PetReminderKind) -> Date? {
        lastReminderAtByKind[kind.rawValue]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same command from Step 2.

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/PetState.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet state model"
```

---

### Task 2: Pet Skills

**Files:**
- Create: `Sources/NetBar/PetSkill.swift`
- Modify: `Sources/NetBar/PetState.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests for built-in skill metadata**

Add:

```swift
func testPetSkillMetadataIsLocalizedAndEnabledByDefault() {
    let scout = PetSkill.builtIn(.networkScout)
    let focus = PetSkill.builtIn(.focusGuard)
    let flash = PetSkill.builtIn(.luckyFlash)

    XCTAssertEqual(scout.title(language: .simplifiedChinese), "网络侦察")
    XCTAssertEqual(focus.title(language: .english), "Focus Guard")
    XCTAssertEqual(flash.animationHint, .sparkle)
    XCTAssertTrue(PetSkillID.defaultEnabled.contains(PetSkillID.networkScout.rawValue))
    XCTAssertTrue(PetSkillID.defaultEnabled.contains(PetSkillID.focusGuard.rawValue))
    XCTAssertTrue(PetSkillID.defaultEnabled.contains(PetSkillID.luckyFlash.rawValue))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetSkillMetadataIsLocalizedAndEnabledByDefault
```

Expected: compile failure because `PetSkill` and `PetSkillID` are not defined.

- [ ] **Step 3: Add `PetSkill.swift`**

Create `Sources/NetBar/PetSkill.swift` with:

```swift
import Foundation

enum PetSkillID: String, Codable, CaseIterable, Identifiable {
    case networkScout
    case focusGuard
    case luckyFlash

    var id: String { rawValue }

    static let defaultEnabled: Set<String> = [
        PetSkillID.networkScout.rawValue,
        PetSkillID.focusGuard.rawValue,
        PetSkillID.luckyFlash.rawValue
    ]
}

struct PetSkill: Equatable, Identifiable {
    let id: PetSkillID
    let titleZh: String
    let titleEn: String
    let descriptionZh: String
    let descriptionEn: String
    let cooldownSeconds: TimeInterval
    let animationHint: PetAnimationHint

    func title(language: AppLanguage) -> String {
        language.text(titleZh, titleEn)
    }

    func description(language: AppLanguage) -> String {
        language.text(descriptionZh, descriptionEn)
    }

    static func builtIn(_ id: PetSkillID) -> PetSkill {
        switch id {
        case .networkScout:
            return PetSkill(
                id: id,
                titleZh: "网络侦察",
                titleEn: "Network Scout",
                descriptionZh: "找出当前最耗流量的应用。",
                descriptionEn: "Find the app currently using the most traffic.",
                cooldownSeconds: 10,
                animationHint: .focused
            )
        case .focusGuard:
            return PetSkill(
                id: id,
                titleZh: "专注守护",
                titleEn: "Focus Guard",
                descriptionZh: "进入 25 分钟专注陪伴。",
                descriptionEn: "Start a 25-minute focus companion session.",
                cooldownSeconds: 60,
                animationHint: .focused
            )
        case .luckyFlash:
            return PetSkill(
                id: id,
                titleZh: "幸运闪光",
                titleEn: "Lucky Flash",
                descriptionZh: "触发一次短暂的开心闪光。",
                descriptionEn: "Trigger a short happy sparkle.",
                cooldownSeconds: 5,
                animationHint: .sparkle
            )
        }
    }

    static let allBuiltIns = PetSkillID.allCases.map(PetSkill.builtIn)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command from Step 2.

Expected: test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/PetSkill.swift Sources/NetBar/PetState.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet skill metadata"
```

---

### Task 3: Pet Controller State Machine

**Files:**
- Create: `Sources/NetBar/PetController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests for controller behavior**

Add:

```swift
func testPetControllerPersistsSettingsAndInteractionState() {
    let defaults = isolatedDefaults()
    let now = Date(timeIntervalSince1970: 100)
    let controller = PetController(defaults: defaults, now: { now })

    controller.updateSettings { settings in
        settings.isEnabled = true
        settings.personality = .playful
    }
    controller.interact(.pet)

    let reloaded = PetController(defaults: defaults, now: { now })
    XCTAssertTrue(reloaded.settings.isEnabled)
    XCTAssertEqual(reloaded.settings.personality, .playful)
    XCTAssertEqual(reloaded.state.affection, 1)
    XCTAssertEqual(reloaded.state.mood, .happy)
}

func testPetControllerMapsNetworkSpeedToMoodAndHighTrafficReminder() {
    let defaults = isolatedDefaults()
    var currentDate = Date(timeIntervalSince1970: 100)
    let controller = PetController(defaults: defaults, now: { currentDate })
    controller.updateSettings { settings in
        settings.isEnabled = true
        settings.highTrafficThresholdBytesPerSecond = 1_000
    }

    controller.observe(snapshot: sampleSnapshot(download: 2_000, upload: 500), appTraffic: .empty)

    XCTAssertEqual(controller.state.mood, .excited)
    XCTAssertEqual(controller.latestCue?.kind, .reminder)
    XCTAssertTrue(controller.latestCue?.message.contains("2.5 KB/s") == true)

    currentDate = currentDate.addingTimeInterval(60)
    controller.observe(snapshot: sampleSnapshot(download: 2_500, upload: 500), appTraffic: .empty)

    XCTAssertEqual(controller.state.lastReminderAtByKind.count, 1)
}

func testPetControllerQuietModeSuppressesReminderCue() {
    let defaults = isolatedDefaults()
    let controller = PetController(defaults: defaults, now: { Date(timeIntervalSince1970: 100) })
    controller.updateSettings { settings in
        settings.isEnabled = true
        settings.isQuietModeEnabled = true
        settings.highTrafficThresholdBytesPerSecond = 1_000
    }

    controller.observe(snapshot: sampleSnapshot(download: 3_000, upload: 0), appTraffic: .empty)

    XCTAssertNil(controller.latestCue)
    XCTAssertEqual(controller.state.mood, .excited)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetControllerPersistsSettingsAndInteractionState --filter PreferencesAndPresentationTests/testPetControllerMapsNetworkSpeedToMoodAndHighTrafficReminder --filter PreferencesAndPresentationTests/testPetControllerQuietModeSuppressesReminderCue
```

Expected: compile failure because `PetController` is not defined.

- [ ] **Step 3: Add `PetController.swift`**

Create `Sources/NetBar/PetController.swift` with:

```swift
import Combine
import Foundation

@MainActor
final class PetController: ObservableObject {
    @Published private(set) var state: PetState
    @Published private(set) var latestCue: PetCue?
    @Published var settings: PetSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let reminderCooldown: TimeInterval = 15 * 60
    private let settingsKey = "pet.settings"
    private let stateKey = "pet.state"

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
        settings = Self.decode(PetSettings.self, key: settingsKey, defaults: defaults) ?? .default
        state = Self.decode(PetState.self, key: stateKey, defaults: defaults) ?? .default(now: now())
    }

    func updateSettings(_ update: (inout PetSettings) -> Void) {
        var copy = settings
        update(&copy)
        settings = copy
    }

    func observe(snapshot: NetworkSnapshot, appTraffic: ApplicationTrafficState) {
        guard settings.isEnabled else { return }
        let totalBytesPerSecond = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond

        if totalBytesPerSecond >= settings.highTrafficThresholdBytesPerSecond {
            state.mood = .excited
            emitReminder(
                .highTraffic,
                title: text("流量跑起来了", "Traffic is running"),
                message: text(
                    "当前合计 \(ByteFormat.speed(totalBytesPerSecond))。",
                    "Current total is \(ByteFormat.speed(totalBytesPerSecond))."
                ),
                animationHint: .happyHop
            )
        } else if totalBytesPerSecond < 100 {
            state.mood = .sleepy
        } else {
            state.mood = .happy
        }
        save()
    }

    func tick() {
        guard settings.isEnabled else { return }
        emitReminder(
            .drinkWater,
            title: text("喝口水", "Hydration break"),
            message: text("我陪你歇一下，先喝口水吧。", "I will keep watch. Take a water break."),
            animationHint: .happyHop
        )
    }

    func interact(_ interaction: PetInteraction) {
        guard settings.isEnabled else { return }
        state.lastInteractionAt = now()
        switch interaction {
        case .pet:
            state.affection = min(state.affection + 1, 999)
            state.energy = min(state.energy + 3, 100)
            state.mood = .happy
            emitCue(
                kind: .interaction,
                title: text("摸摸成功", "Pet received"),
                message: text("它看起来开心了一点。", "Your pet looks a little happier."),
                animationHint: .happyHop
            )
        case .feed:
            state.energy = min(state.energy + 10, 100)
            state.mood = .happy
            emitCue(kind: .interaction, title: text("补充能量", "Energy up"), message: text("活力恢复了。", "Energy restored."), animationHint: .happyHop)
        case .encourage:
            state.mood = .excited
            emitCue(kind: .interaction, title: text("打起精神", "Encouraged"), message: text("它准备继续陪你。", "Your pet is ready to keep going."), animationHint: .sparkle)
        case .focus:
            state.mood = .focused
            state.activeSkillID = PetSkillID.focusGuard.rawValue
            emitCue(kind: .skill, title: text("专注开始", "Focus started"), message: text("接下来 25 分钟减少打扰。", "Distractions are reduced for 25 minutes."), animationHint: .focused)
        case .play:
            state.energy = max(state.energy - 5, 0)
            state.affection = min(state.affection + 2, 999)
            state.mood = .excited
            emitCue(kind: .interaction, title: text("玩了一会儿", "Play time"), message: text("亲密度提升了。", "Affection increased."), animationHint: .sparkle)
        }
        save()
    }

    @discardableResult
    func triggerSkill(
        _ skillID: PetSkillID,
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState
    ) -> PetCue? {
        guard settings.isEnabled, settings.isSkillEnabled(skillID) else { return nil }
        switch skillID {
        case .networkScout:
            let top = appTraffic.applications.max { lhs, rhs in
                (lhs.downloadBytesPerSecond + lhs.uploadBytesPerSecond) < (rhs.downloadBytesPerSecond + rhs.uploadBytesPerSecond)
            }
            let message: String
            if let top {
                let total = top.downloadBytesPerSecond + top.uploadBytesPerSecond
                message = text(
                    "\(top.displayName) 当前最活跃，约 \(ByteFormat.speed(total))。",
                    "\(top.displayName) is most active at about \(ByteFormat.speed(total))."
                )
            } else {
                message = text("现在没有明显占流量的应用。", "No app is using notable traffic right now.")
            }
            emitCue(kind: .skill, title: text("网络侦察", "Network Scout"), message: message, animationHint: .focused)
        case .focusGuard:
            interact(.focus)
        case .luckyFlash:
            state.mood = .happy
            emitCue(kind: .skill, title: text("幸运闪光", "Lucky Flash"), message: text("今天也会顺利的。", "A little luck for the day."), animationHint: .sparkle)
        }
        save()
        return latestCue
    }

    private func emitReminder(
        _ kind: PetReminderKind,
        title: String,
        message: String,
        animationHint: PetAnimationHint
    ) {
        guard settings.isReminderEnabled(kind), !settings.isQuietModeEnabled else { return }
        let date = now()
        if let last = state.lastReminderDate(for: kind), date.timeIntervalSince(last) < reminderCooldown {
            return
        }
        state.recordReminder(kind, at: date)
        emitCue(kind: .reminder, title: title, message: message, animationHint: animationHint)
    }

    private func emitCue(
        kind: PetCueKind,
        title: String,
        message: String,
        animationHint: PetAnimationHint
    ) {
        latestCue = PetCue(
            kind: kind,
            title: title,
            message: message,
            createdAt: now(),
            animationHint: animationHint
        )
    }

    private func text(_ simplifiedChinese: String, _ english: String) -> String {
        switch settings.personality {
        case .healing, .playful:
            return simplifiedChinese
        case .professional:
            return english
        }
    }

    private func save() {
        Self.encode(settings, key: settingsKey, defaults: defaults)
        Self.encode(state, key: stateKey, defaults: defaults)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same command from Step 2.

Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/PetController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet controller"
```

---

### Task 4: Pet Panel UI

**Files:**
- Create: `Sources/NetBar/PetPanelView.swift`
- Create: `Sources/NetBar/PetPanelWindowController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing presentation tests for panel-friendly text**

Add:

```swift
func testPetMoodAndSkillsProvidePanelCopy() {
    XCTAssertEqual(PetMood.focused.title(language: .simplifiedChinese), "专注")
    XCTAssertEqual(PetPersonality.playful.title(language: .english), "Playful")
    XCTAssertEqual(PetReminderKind.restEyes.title(language: .simplifiedChinese), "休息眼睛")
    XCTAssertEqual(PetSkill.allBuiltIns.count, 3)
}
```

- [ ] **Step 2: Run test to verify it passes before UI work**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetMoodAndSkillsProvidePanelCopy
```

Expected: passes because earlier tasks added the copy. This locks the text contract before adding views.

- [ ] **Step 3: Add `PetPanelView.swift`**

Create `Sources/NetBar/PetPanelView.swift` with:

```swift
import SwiftUI

struct PetPanelView: View {
    @ObservedObject var petController: PetController
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appPreferences.text("NetBar 宠物", "NetBar Pet"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(petController.state.mood.title(language: appPreferences.resolvedLanguage))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NetBarBadge(
                    text: appPreferences.text("亲密 \(petController.state.affection)", "Bond \(petController.state.affection)"),
                    tone: .success
                )
            }

            if let cue = petController.latestCue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cue.title)
                        .font(.system(size: 13, weight: .bold))
                    Text(cue.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10)))
            }

            HStack(spacing: 8) {
                Button {
                    petController.interact(.pet)
                } label: {
                    Label(appPreferences.text("摸摸", "Pet"), systemImage: "hand.tap")
                }

                Button {
                    petController.interact(.feed)
                } label: {
                    Label(appPreferences.text("喂食", "Feed"), systemImage: "bolt.heart")
                }

                Button {
                    petController.interact(.encourage)
                } label: {
                    Label(appPreferences.text("鼓励", "Cheer"), systemImage: "sparkles")
                }
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 8) {
                Text(appPreferences.text("技能", "Skills"))
                    .font(.system(size: 12, weight: .bold))

                ForEach(PetSkill.allBuiltIns) { skill in
                    Button {
                        _ = petController.triggerSkill(
                            skill.id,
                            snapshot: monitor.snapshot,
                            appTraffic: monitor.appTraffic
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.title(language: appPreferences.resolvedLanguage))
                                    .font(.system(size: 12, weight: .semibold))
                                Text(skill.description(language: appPreferences.resolvedLanguage))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!petController.settings.isSkillEnabled(skill.id))
                }
            }

            Divider().opacity(0.5)

            HStack {
                Text(appPreferences.text("当前流量", "Current traffic"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(ByteFormat.speed(monitor.snapshot.downloadBytesPerSecond + monitor.snapshot.uploadBytesPerSecond))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
        .padding(16)
        .frame(width: 360)
        .netBarPanelBackground()
    }
}
```

- [ ] **Step 4: Add `PetPanelWindowController.swift`**

Create `Sources/NetBar/PetPanelWindowController.swift` with:

```swift
import AppKit
import SwiftUI

@MainActor
final class PetPanelWindowController: NSObject, NSWindowDelegate {
    private let petController: PetController
    private let monitor: NetworkMonitor
    private let appPreferences: AppPreferences
    private var panel: NSPanel?
    private let windowSize = NSSize(width: 360, height: 380)

    init(
        petController: PetController,
        monitor: NetworkMonitor,
        appPreferences: AppPreferences
    ) {
        self.petController = petController
        self.monitor = monitor
        self.appPreferences = appPreferences
    }

    func toggle(anchor: NSStatusBarButton?) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show(anchor: anchor)
    }

    func show(anchor: NSStatusBarButton?) {
        let panel = makePanelIfNeeded()
        position(panel, near: anchor)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "NetBar Pet"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.delegate = self

        let hostingController = NSHostingController(
            rootView: PetPanelView(
                petController: petController,
                monitor: monitor,
                appPreferences: appPreferences
            )
        )
        panel.contentViewController = hostingController
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 16
        hostingController.view.layer?.masksToBounds = true

        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, near anchor: NSStatusBarButton?) {
        guard
            let anchor,
            let screen = anchor.window?.screen ?? NSScreen.main
        else {
            panel.center()
            return
        }

        let anchorFrame = anchor.window?.convertToScreen(anchor.frame) ?? .zero
        let visibleFrame = screen.visibleFrame
        let x = min(max(anchorFrame.midX - windowSize.width / 2, visibleFrame.minX + 10), visibleFrame.maxX - windowSize.width - 10)
        let y = max(anchorFrame.minY - windowSize.height - 8, visibleFrame.minY + 10)
        panel.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true)
    }
}
```

- [ ] **Step 5: Build to verify SwiftUI/AppKit compile**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/NetBar/PetPanelView.swift Sources/NetBar/PetPanelWindowController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet panel"
```

---

### Task 5: Status Bar Integration

**Files:**
- Modify: `Sources/NetBar/AppDelegate.swift`
- Modify: `Sources/NetBar/StatusBarController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write controller-level tests for click routing helpers**

Add this pure helper to the test first by writing tests that reference `StatusBarPetClickAction`:

```swift
func testStatusBarPetClickActionKeepsRightClickMenuAndUsesPetWhenEnabled() {
    XCTAssertEqual(StatusBarPetClickAction.action(isRightClick: true, clickCount: 1, petEnabled: true), .showMenu)
    XCTAssertEqual(StatusBarPetClickAction.action(isRightClick: false, clickCount: 2, petEnabled: true), .petInteraction)
    XCTAssertEqual(StatusBarPetClickAction.action(isRightClick: false, clickCount: 1, petEnabled: true), .petPanel)
    XCTAssertEqual(StatusBarPetClickAction.action(isRightClick: false, clickCount: 1, petEnabled: false), .trafficPanel)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarPetClickActionKeepsRightClickMenuAndUsesPetWhenEnabled
```

Expected: compile failure because `StatusBarPetClickAction` is not defined.

- [ ] **Step 3: Add click routing helper to `StatusBarController.swift`**

Near the top of `Sources/NetBar/StatusBarController.swift`, after `GooglyEyesClickMonitor`, add:

```swift
enum StatusBarPetClickAction: Equatable {
    case showMenu
    case petInteraction
    case petPanel
    case trafficPanel

    static func action(isRightClick: Bool, clickCount: Int, petEnabled: Bool) -> StatusBarPetClickAction {
        if isRightClick { return .showMenu }
        if petEnabled, clickCount >= 2 { return .petInteraction }
        if petEnabled { return .petPanel }
        return .trafficPanel
    }
}
```

- [ ] **Step 4: Modify `StatusBarController` to own pet panel**

Change stored properties:

```swift
private let petController: PetController
private let petPanelWindowController: PetPanelWindowController
private var petTimer: Timer?
```

Change `init` signature:

```swift
init(
    monitor: NetworkMonitor,
    settings: StatusBarSettings,
    appPreferences: AppPreferences,
    customCharacterStore: CustomCharacterStore,
    petController: PetController,
    openPreferences: @escaping () -> Void,
    showAbout: @escaping () -> Void
)
```

Inside `init`, assign and create the pet panel:

```swift
self.petController = petController
self.petPanelWindowController = PetPanelWindowController(
    petController: petController,
    monitor: monitor,
    appPreferences: appPreferences
)
```

In `deinit`, invalidate the timer:

```swift
petTimer?.invalidate()
```

In `configureObservers()`, change the monitor sink:

```swift
monitor.$snapshot.sink { [weak self] _ in
    guard let self else { return }
    self.petController.observe(snapshot: self.monitor.snapshot, appTraffic: self.monitor.appTraffic)
    self.updateStatusItem()
}
.store(in: &cancellables)
```

Add a pet observer:

```swift
petController.objectWillChange.sink { [weak self] _ in
    DispatchQueue.main.async {
        self?.updateStatusItem()
    }
}
.store(in: &cancellables)
```

At the end of `configureObservers()`, schedule reminders:

```swift
petTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    Task { @MainActor in
        self?.petController.tick()
    }
}
```

- [ ] **Step 5: Modify click handling**

Replace the body of `toggleDetailsWindow(_:)` with:

```swift
triggerGooglyEyesBlink()
let event = NSApplication.shared.currentEvent
let clickAction = StatusBarPetClickAction.action(
    isRightClick: event?.type == .rightMouseUp,
    clickCount: event?.clickCount ?? 1,
    petEnabled: petController.settings.isEnabled
)

switch clickAction {
case .showMenu:
    showStatusMenu()
case .petInteraction:
    petController.interact(.pet)
case .petPanel:
    petPanelWindowController.toggle(anchor: statusItem.button)
case .trafficPanel:
    detailsWindowController.toggle(anchor: statusItem.button)
}
```

In `updateStatusItem()`, after setting `button.image`, update the tooltip:

```swift
if let cue = petController.latestCue, petController.settings.isEnabled {
    button.toolTip = "\(cue.title): \(cue.message)"
} else {
    button.toolTip = text("NetBar 网络流量，点击查看明细", "NetBar network traffic. Click for details.")
}
```

- [ ] **Step 6: Add pet commands to right-click menu**

In `showStatusMenu()`, before the separator above Quit, add:

```swift
menu.addItem(.separator())
let petPanelItem = NSMenuItem(
    title: text("宠物面板", "Pet Panel"),
    action: #selector(openPetPanelFromMenu(_:)),
    keyEquivalent: ""
)
petPanelItem.target = self
menu.addItem(petPanelItem)

let scoutItem = NSMenuItem(
    title: text("网络侦察", "Network Scout"),
    action: #selector(runNetworkScoutFromMenu(_:)),
    keyEquivalent: ""
)
scoutItem.target = self
scoutItem.isEnabled = petController.settings.isEnabled
menu.addItem(scoutItem)

let focusItem = NSMenuItem(
    title: text("专注守护", "Focus Guard"),
    action: #selector(runFocusGuardFromMenu(_:)),
    keyEquivalent: ""
)
focusItem.target = self
focusItem.isEnabled = petController.settings.isEnabled
menu.addItem(focusItem)

let quietItem = NSMenuItem(
    title: text("宠物静默模式", "Pet Quiet Mode"),
    action: #selector(togglePetQuietModeFromMenu(_:)),
    keyEquivalent: ""
)
quietItem.target = self
quietItem.state = petController.settings.isQuietModeEnabled ? .on : .off
menu.addItem(quietItem)
```

Add selectors:

```swift
@objc private func openPetPanelFromMenu(_ sender: AnyObject?) {
    petPanelWindowController.show(anchor: statusItem.button)
}

@objc private func runNetworkScoutFromMenu(_ sender: AnyObject?) {
    _ = petController.triggerSkill(.networkScout, snapshot: monitor.snapshot, appTraffic: monitor.appTraffic)
    petPanelWindowController.show(anchor: statusItem.button)
}

@objc private func runFocusGuardFromMenu(_ sender: AnyObject?) {
    _ = petController.triggerSkill(.focusGuard, snapshot: monitor.snapshot, appTraffic: monitor.appTraffic)
    petPanelWindowController.show(anchor: statusItem.button)
}

@objc private func togglePetQuietModeFromMenu(_ sender: AnyObject?) {
    petController.updateSettings { settings in
        settings.isQuietModeEnabled.toggle()
    }
}
```

- [ ] **Step 7: Modify `AppDelegate.swift`**

Add stored property:

```swift
private let petController = PetController()
```

Pass it into `StatusBarController`:

```swift
petController: petController,
```

This is placed between `customCharacterStore: customCharacterStore,` and `openPreferences:`.

- [ ] **Step 8: Run tests and build**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testStatusBarPetClickActionKeepsRightClickMenuAndUsesPetWhenEnabled
swift build
```

Expected: test passes and build succeeds.

- [ ] **Step 9: Commit**

```bash
git add Sources/NetBar/AppDelegate.swift Sources/NetBar/StatusBarController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: integrate pet with status bar"
```

---

### Task 6: Pet Preferences UI

**Files:**
- Modify: `Sources/NetBar/AppDelegate.swift`
- Modify: `Sources/NetBar/PreferencesWindowController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing test for reminder and skill toggles**

Add:

```swift
func testPetSettingsCanToggleReminderAndSkillIDs() {
    var settings = PetSettings.default
    settings.enabledReminderIDs.remove(PetReminderKind.drinkWater.rawValue)
    settings.enabledSkillIDs.remove(PetSkillID.luckyFlash.rawValue)

    XCTAssertFalse(settings.isReminderEnabled(.drinkWater))
    XCTAssertFalse(settings.isSkillEnabled(.luckyFlash))

    settings.enabledReminderIDs.insert(PetReminderKind.drinkWater.rawValue)
    settings.enabledSkillIDs.insert(PetSkillID.luckyFlash.rawValue)

    XCTAssertTrue(settings.isReminderEnabled(.drinkWater))
    XCTAssertTrue(settings.isSkillEnabled(.luckyFlash))
}
```

- [ ] **Step 2: Run test**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetSettingsCanToggleReminderAndSkillIDs
```

Expected: passes if Task 1 and Task 2 are implemented correctly. This protects preference bindings.

- [ ] **Step 3: Update `PreferencesWindowController` initializer chain**

Add `petController` to `PreferencesWindowController` stored properties and initializer:

```swift
private let petController: PetController
```

```swift
init(
    settings: StatusBarSettings,
    appPreferences: AppPreferences,
    customCharacterStore: CustomCharacterStore,
    petController: PetController,
    updater: AppUpdater
) {
    self.settings = settings
    self.appPreferences = appPreferences
    self.customCharacterStore = customCharacterStore
    self.petController = petController
    self.updater = updater
}
```

Pass it to `PreferencesView`:

```swift
petController: petController,
```

Add to `PreferencesView`:

```swift
@ObservedObject var petController: PetController
```

Add a tab after Menu Bar:

```swift
PetPreferencesView(
    petController: petController,
    appPreferences: appPreferences
)
.tabItem {
    Label(appPreferences.text("宠物", "Pet"), systemImage: "pawprint")
}
```

- [ ] **Step 4: Add `PetPreferencesView`**

In `Sources/NetBar/PreferencesWindowController.swift`, after `MenuBarPreferencesView`, add:

```swift
private struct PetPreferencesView: View {
    @ObservedObject var petController: PetController
    @ObservedObject var appPreferences: AppPreferences

    private func reminderBinding(_ kind: PetReminderKind) -> Binding<Bool> {
        Binding(
            get: { petController.settings.isReminderEnabled(kind) },
            set: { isEnabled in
                petController.updateSettings { settings in
                    if isEnabled {
                        settings.enabledReminderIDs.insert(kind.rawValue)
                    } else {
                        settings.enabledReminderIDs.remove(kind.rawValue)
                    }
                }
            }
        )
    }

    private func skillBinding(_ skillID: PetSkillID) -> Binding<Bool> {
        Binding(
            get: { petController.settings.isSkillEnabled(skillID) },
            set: { isEnabled in
                petController.updateSettings { settings in
                    if isEnabled {
                        settings.enabledSkillIDs.insert(skillID.rawValue)
                    } else {
                        settings.enabledSkillIDs.remove(skillID.rawValue)
                    }
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PreferenceSection(title: appPreferences.text("宠物系统", "Pet System")) {
                    Toggle(appPreferences.text("启用宠物", "Enable Pet"), isOn: Binding(
                        get: { petController.settings.isEnabled },
                        set: { enabled in
                            petController.updateSettings { $0.isEnabled = enabled }
                        }
                    ))

                    Toggle(appPreferences.text("静默模式", "Quiet Mode"), isOn: Binding(
                        get: { petController.settings.isQuietModeEnabled },
                        set: { enabled in
                            petController.updateSettings { $0.isQuietModeEnabled = enabled }
                        }
                    ))

                    Picker(appPreferences.text("性格", "Personality"), selection: Binding(
                        get: { petController.settings.personality },
                        set: { personality in
                            petController.updateSettings { $0.personality = personality }
                        }
                    )) {
                        ForEach(PetPersonality.allCases) { personality in
                            Text(personality.title(language: appPreferences.resolvedLanguage)).tag(personality)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                PreferenceSection(title: appPreferences.text("提醒", "Reminders")) {
                    ForEach(PetReminderKind.allCases) { reminder in
                        Toggle(reminder.title(language: appPreferences.resolvedLanguage), isOn: reminderBinding(reminder))
                    }
                }

                PreferenceSection(title: appPreferences.text("技能", "Skills")) {
                    ForEach(PetSkill.allBuiltIns) { skill in
                        Toggle(skill.title(language: appPreferences.resolvedLanguage), isOn: skillBinding(skill.id))
                    }
                }
            }
            .padding(.trailing, 2)
        }
    }
}
```

- [ ] **Step 5: Update `AppDelegate.swift`**

Pass `petController` into the lazy preferences controller:

```swift
private lazy var preferencesWindowController = PreferencesWindowController(
    settings: settings,
    appPreferences: appPreferences,
    customCharacterStore: customCharacterStore,
    petController: petController,
    updater: updater
)
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetSettingsCanToggleReminderAndSkillIDs
swift build
```

Expected: test passes and build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Sources/NetBar/AppDelegate.swift Sources/NetBar/PreferencesWindowController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: add pet preferences"
```

---

### Task 7: Skill Details And Reminder Coverage

**Files:**
- Modify: `Sources/NetBar/PetController.swift`
- Test: `Tests/NetBarTests/PreferencesAndPresentationTests.swift`

- [ ] **Step 1: Write failing tests for network scout and focus guard**

Add:

```swift
func testPetNetworkScoutSkillReportsTopTrafficApplication() {
    let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 10) })
    controller.updateSettings { $0.isEnabled = true }
    let appTraffic = ApplicationTrafficState(
        timestamp: Date(timeIntervalSince1970: 10),
        applications: [
            app("Quiet", processNames: ["Quiet"], download: 100, upload: 100, total: 200),
            app("Arc", processNames: ["Arc"], download: 4_000, upload: 1_000, total: 5_000)
        ],
        sampleCount: 2,
        isRefreshing: false,
        errorMessage: nil
    )

    let cue = controller.triggerSkill(.networkScout, snapshot: sampleSnapshot(download: 4_000, upload: 1_000), appTraffic: appTraffic)

    XCTAssertEqual(cue?.kind, .skill)
    XCTAssertTrue(cue?.message.contains("Arc") == true)
}

func testPetFocusGuardSetsFocusedMoodAndActiveSkill() {
    let controller = PetController(defaults: isolatedDefaults(), now: { Date(timeIntervalSince1970: 10) })
    controller.updateSettings { $0.isEnabled = true }

    _ = controller.triggerSkill(.focusGuard, snapshot: sampleSnapshot(download: 0, upload: 0), appTraffic: .empty)

    XCTAssertEqual(controller.state.mood, .focused)
    XCTAssertEqual(controller.state.activeSkillID, PetSkillID.focusGuard.rawValue)
}
```

- [ ] **Step 2: Run tests**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPetNetworkScoutSkillReportsTopTrafficApplication --filter PreferencesAndPresentationTests/testPetFocusGuardSetsFocusedMoodAndActiveSkill
```

Expected: pass if Task 3 implementation matches the plan. If either fails, adjust only `PetController.triggerSkill`.

- [ ] **Step 3: Add rest-eyes reminder to `tick()`**

In `PetController`, add a property:

```swift
private var tickCount = 0
```

Replace `tick()` with:

```swift
func tick() {
    guard settings.isEnabled else { return }
    tickCount += 1
    if tickCount % 20 == 0 {
        emitReminder(
            .restEyes,
            title: text("看看远处", "Rest your eyes"),
            message: text("盯屏幕久了，眺望一下会舒服些。", "Look away from the screen for a moment."),
            animationHint: .happyHop
        )
    } else {
        emitReminder(
            .drinkWater,
            title: text("喝口水", "Hydration break"),
            message: text("我陪你歇一下，先喝口水吧。", "I will keep watch. Take a water break."),
            animationHint: .happyHop
        )
    }
}
```

- [ ] **Step 4: Run full pet test subset**

Run:

```bash
swift test --filter PreferencesAndPresentationTests/testPet
```

Expected: all pet tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/NetBar/PetController.swift Tests/NetBarTests/PreferencesAndPresentationTests.swift
git commit -m "feat: complete pet skill behavior"
```

---

### Task 8: Full Verification

**Files:**
- All touched files

- [ ] **Step 1: Run full test suite**

Run:

```bash
swift test
```

Expected: all tests pass with 0 failures.

- [ ] **Step 2: Build release app**

Run:

```bash
Scripts/build-app.sh
```

Expected: release build succeeds and prints `build/NetBar.app`.

- [ ] **Step 3: Manual smoke test**

Run the built app:

```bash
open build/NetBar.app
```

Manual checks:

- Preferences contains a Pet tab.
- Enabling Pet changes left click from traffic details to pet panel.
- Double-clicking the status item increases affection in the pet panel.
- Right-click menu includes Pet Panel, Network Scout, Focus Guard, and Quiet Mode.
- Network Scout opens the pet panel and reports either a top app or no notable app traffic.
- Disabling Pet restores left click to the existing traffic panel.

- [ ] **Step 4: Commit verification cleanup**

If verification required small fixes, commit them:

```bash
git add Sources/NetBar Tests/NetBarTests
git commit -m "fix: polish pet mvp integration"
```

If no fixes were needed, do not create an empty commit.

---

## Self-Review

Spec coverage:

- Pet state, mood, energy, affection, personality: Task 1 and Task 3.
- Interactions: Task 3, Task 4, Task 5.
- Reminders: Task 3 and Task 7.
- Skills: Task 2, Task 3, Task 4, Task 5, Task 7.
- Preferences: Task 6.
- Status bar integration: Task 5.
- Pet panel: Task 4.
- Low-distraction behavior and quiet mode: Task 3 and Task 6.

No gaps remain in this plan. All new types referenced by following tasks are introduced by earlier tasks. The plan intentionally scopes macOS system notifications, daily summaries, affection levels, and desktop free-roaming to the second or third phase because the design assigns them outside the MVP.
