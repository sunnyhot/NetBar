import Combine
import Foundation

@MainActor
final class PetController: ObservableObject {
    @Published private(set) var state: PetState
    @Published private(set) var latestCue: PetCue?
    @Published var settings: PetSettings {
        didSet { saveSettings() }
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private let reminderCooldown: TimeInterval = 15 * 60
    private let settingsKey = "pet.settings"
    private let stateKey = "pet.state"
    private var tickCount = 0
    private var isStateDirty = false
    private var dirtySaveTimer: Timer?
    private static let dirtySaveInterval: TimeInterval = 30.0

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
        let date = now()
        clearExpiredActiveSkillIfNeeded(at: date)
        let totalBytesPerSecond = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond

        if totalBytesPerSecond >= settings.highTrafficThresholdBytesPerSecond {
            state.mood = .excited
            let topApplication = topTrafficApplication(in: appTraffic)
            emitReminder(
                .highTraffic,
                title: text("流量跑起来了", "Traffic is running"),
                message: highTrafficMessage(
                    totalBytesPerSecond: totalBytesPerSecond,
                    topApplication: topApplication
                ),
                animationHint: .happyHop
            )
        } else if totalBytesPerSecond < 100 {
            state.mood = .sleepy
        } else {
            state.mood = .happy
        }
        markStateUpdatedAndSave(at: date)
    }

    func observe(anomaly event: NetworkAnomalyEvent) {
        guard settings.isEnabled else { return }
        let date = now()
        clearExpiredActiveSkillIfNeeded(at: date)
        state.mood = mood(for: event)
        if !settings.isQuietModeEnabled {
            emitCue(
                kind: .networkIntelligence,
                title: event.kind.title(language: petLanguage),
                message: petMessage(for: event),
                animationHint: animationHint(for: event)
            )
        }
        markStateUpdatedAndSave(at: date)
    }

    func observe(todaySummary summary: NetworkDailySummary) {
        guard settings.isEnabled else { return }
        let date = now()
        clearExpiredActiveSkillIfNeeded(at: date)
        if summary.totalBytes >= 10_000_000_000
            || summary.peakDownloadBytesPerSecond + summary.peakUploadBytesPerSecond >= settings.highTrafficThresholdBytesPerSecond {
            state.mood = .excited
        } else if summary.activeSeconds < 60 {
            state.mood = .sleepy
        } else if summary.topApplications.isEmpty {
            state.mood = .happy
        } else {
            state.mood = .focused
        }
        markStateUpdatedAndSave(at: date)
    }

    func tick() {
        guard settings.isEnabled else { return }
        let date = now()
        clearExpiredActiveSkillIfNeeded(at: date)
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
        markStateUpdatedAndSave(at: date)
    }

    func interact(_ interaction: PetInteraction) {
        guard settings.isEnabled else { return }
        let date = now()
        clearExpiredActiveSkillIfNeeded(at: date)
        state.lastInteraction = interaction
        state.lastInteractionAt = date
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
            emitCue(
                kind: .interaction,
                title: text("补充能量", "Energy up"),
                message: text("活力恢复了。", "Energy restored."),
                animationHint: .happyHop
            )
        case .encourage:
            state.mood = .excited
            emitCue(
                kind: .interaction,
                title: text("打起精神", "Encouraged"),
                message: text("它准备继续陪你。", "Your pet is ready to keep going."),
                animationHint: .sparkle
            )
        case .focus:
            state.mood = .focused
            state.activeSkillID = PetSkillID.focusGuard.rawValue
            state.activeSkillStartedAt = date
            state.activeSkillEndsAt = date.addingTimeInterval(25 * 60)
            emitCue(
                kind: .skill,
                title: text("专注开始", "Focus started"),
                message: text("接下来 25 分钟减少打扰。", "Distractions are reduced for 25 minutes."),
                animationHint: .focused
            )
        case .play:
            state.energy = max(state.energy - 5, 0)
            state.affection = min(state.affection + 2, 999)
            state.mood = .excited
            emitCue(
                kind: .interaction,
                title: text("玩了一会儿", "Play time"),
                message: text("亲密度提升了。", "Affection increased."),
                animationHint: .sparkle
            )
        }
        markStateUpdatedAndSaveImmediately(at: date)
    }

    @discardableResult
    func triggerSkill(
        _ skillID: PetSkillID,
        snapshot: NetworkSnapshot,
        appTraffic: ApplicationTrafficState
    ) -> PetCue? {
        guard settings.isEnabled, settings.isSkillEnabled(skillID) else { return nil }
        let date = now()
        clearExpiredActiveSkillIfNeeded(at: date)
        let skill = PetSkill.builtIn(skillID)
        if let lastTriggeredAt = state.lastSkillTriggeredDate(for: skillID),
           date.timeIntervalSince(lastTriggeredAt) < skill.cooldownSeconds {
            return nil
        }

        switch skillID {
        case .networkScout:
            let top = topTrafficApplication(in: appTraffic)
            let message: String
            if let top {
                let total = top.downloadBytesPerSecond + top.uploadBytesPerSecond
                message = text(
                    "\(top.displayName) 当前最活跃，约 \(ByteFormat.speed(total))。",
                    "\(top.displayName) is most active at about \(ByteFormat.speed(total))."
                )
            } else {
                let total = snapshot.downloadBytesPerSecond + snapshot.uploadBytesPerSecond
                message = text(
                    "现在没有明显占流量的应用，当前合计 \(ByteFormat.speed(total))。",
                    "No app is using notable traffic right now. Current total is \(ByteFormat.speed(total))."
                )
            }
            emitCue(
                kind: .skill,
                title: text("网络侦察", "Network Scout"),
                message: message,
                animationHint: .focused
            )
        case .focusGuard:
            interact(.focus)
        case .luckyFlash:
            state.mood = .happy
            emitCue(
                kind: .skill,
                title: text("幸运闪光", "Lucky Flash"),
                message: text("今天也会顺利的。", "A little luck for the day."),
                animationHint: .sparkle
            )
        }
        state.recordSkillTrigger(skillID, at: date)
        markStateUpdatedAndSaveImmediately(at: date)
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

    private var petLanguage: AppLanguage {
        switch settings.personality {
        case .healing, .playful:
            return .simplifiedChinese
        case .professional:
            return .english
        }
    }

    private func mood(for event: NetworkAnomalyEvent) -> PetMood {
        switch event.kind {
        case .highTraffic:
            return .excited
        case .applicationSpike, .proxyAttributionGap:
            return event.severity == .critical ? .worried : .focused
        case .networkDrop:
            return .worried
        case .networkRecovered:
            return .happy
        }
    }

    private func animationHint(for event: NetworkAnomalyEvent) -> PetAnimationHint {
        switch event.kind {
        case .highTraffic:
            return .happyHop
        case .applicationSpike, .proxyAttributionGap:
            return .focused
        case .networkDrop:
            return .worried
        case .networkRecovered:
            return .sparkle
        }
    }

    private func petMessage(for event: NetworkAnomalyEvent) -> String {
        switch event.kind {
        case .highTraffic:
            if let bytesPerSecond = event.bytesPerSecond {
                return text(
                    "总流量升高到约 \(ByteFormat.speed(bytesPerSecond))，我帮你盯着。",
                    "Total traffic is up to about \(ByteFormat.speed(bytesPerSecond)). I am watching it."
                )
            }
            return text(
                "总流量有点高，我帮你盯着。",
                "Total traffic is running high. I am watching it."
            )
        case .applicationSpike:
            let applicationName = event.applicationName ?? text("某个应用", "An app")
            if let bytesPerSecond = event.bytesPerSecond {
                return text(
                    "\(applicationName) 突然忙起来，约 \(ByteFormat.speed(bytesPerSecond))。",
                    "\(applicationName) suddenly got busy at about \(ByteFormat.speed(bytesPerSecond))."
                )
            }
            return text(
                "\(applicationName) 突然忙起来了。",
                "\(applicationName) suddenly got busy."
            )
        case .networkDrop:
            return text(
                "网络像是安静下来了，可能有断流。",
                "Network traffic went quiet. There may be a drop."
            )
        case .networkRecovered:
            return text(
                "网络恢复了，呼吸又顺了。",
                "Network traffic recovered."
            )
        case .proxyAttributionGap:
            return text(
                "系统总流量和应用列表有差距，可能是代理或系统进程。",
                "Total traffic differs from app attribution. It may be proxy or system traffic."
            )
        }
    }

    private func topTrafficApplication(in appTraffic: ApplicationTrafficState) -> ApplicationTrafficRate? {
        appTraffic.applications.max { lhs, rhs in
            let lhsTotal = lhs.downloadBytesPerSecond + lhs.uploadBytesPerSecond
            let rhsTotal = rhs.downloadBytesPerSecond + rhs.uploadBytesPerSecond
            return lhsTotal < rhsTotal
        }
    }

    private func highTrafficMessage(
        totalBytesPerSecond: Double,
        topApplication: ApplicationTrafficRate?
    ) -> String {
        if let topApplication {
            return text(
                "\(topApplication.displayName) 当前最活跃，合计 \(ByteFormat.speed(totalBytesPerSecond))。",
                "\(topApplication.displayName) is most active. Current total is \(ByteFormat.speed(totalBytesPerSecond))."
            )
        }
        return text(
            "当前合计 \(ByteFormat.speed(totalBytesPerSecond))。",
            "Current total is \(ByteFormat.speed(totalBytesPerSecond))."
        )
    }

    private func clearExpiredActiveSkillIfNeeded(at date: Date) {
        guard let endsAt = state.activeSkillEndsAt, date >= endsAt else { return }
        state.activeSkillID = nil
        state.activeSkillStartedAt = nil
        state.activeSkillEndsAt = nil
        if state.mood == .focused {
            state.mood = .happy
        }
    }

    private func markStateUpdatedAndSave(at date: Date) {
        state.markUpdated(at: date)
        isStateDirty = true
        scheduleDirtySave()
    }

    private func markStateUpdatedAndSaveImmediately(at date: Date) {
        state.markUpdated(at: date)
        isStateDirty = false
        dirtySaveTimer?.invalidate()
        dirtySaveTimer = nil
        saveState()
    }

    private func scheduleDirtySave() {
        guard dirtySaveTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: Self.dirtySaveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flushDirtyState()
            }
        }
        dirtySaveTimer = timer
    }

    private func flushDirtyState() {
        dirtySaveTimer = nil
        guard isStateDirty else { return }
        isStateDirty = false
        saveState()
    }

    private func saveSettings() {
        Self.encode(settings, key: settingsKey, defaults: defaults)
    }

    private func saveState() {
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

    deinit {
        dirtySaveTimer?.invalidate()
    }
}
