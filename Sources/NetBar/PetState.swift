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

enum PetActivityLevel: String, Codable, CaseIterable, Identifiable {
    case idle
    case light
    case active
    case heavy

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .idle:
            return language.text("空闲", "Idle")
        case .light:
            return language.text("轻度", "Light")
        case .active:
            return language.text("活跃", "Active")
        case .heavy:
            return language.text("高活跃", "Heavy")
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
    case networkIntelligence
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
    var isPetMoodFeedbackEnabled: Bool
    var isPetActivityLevelEnabled: Bool

    init(
        isEnabled: Bool,
        isQuietModeEnabled: Bool,
        personality: PetPersonality,
        enabledReminderIDs: Set<String>,
        enabledSkillIDs: Set<String>,
        highTrafficThresholdBytesPerSecond: Double,
        isPetMoodFeedbackEnabled: Bool = true,
        isPetActivityLevelEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.isQuietModeEnabled = isQuietModeEnabled
        self.personality = personality
        self.enabledReminderIDs = enabledReminderIDs
        self.enabledSkillIDs = enabledSkillIDs
        self.highTrafficThresholdBytesPerSecond = highTrafficThresholdBytesPerSecond
        self.isPetMoodFeedbackEnabled = isPetMoodFeedbackEnabled
        self.isPetActivityLevelEnabled = isPetActivityLevelEnabled
    }

    static let `default` = PetSettings(
        isEnabled: false,
        isQuietModeEnabled: false,
        personality: .healing,
        enabledReminderIDs: PetReminderKind.defaultEnabled,
        enabledSkillIDs: PetSkillID.defaultEnabled,
        highTrafficThresholdBytesPerSecond: 10_000_000,
        isPetMoodFeedbackEnabled: true,
        isPetActivityLevelEnabled: true
    )

    func isReminderEnabled(_ kind: PetReminderKind) -> Bool {
        enabledReminderIDs.contains(kind.rawValue)
    }

    func isSkillEnabled(_ skillID: PetSkillID) -> Bool {
        enabledSkillIDs.contains(skillID.rawValue)
    }
}

extension PetSettings {
    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case isQuietModeEnabled
        case personality
        case enabledReminderIDs
        case enabledSkillIDs
        case highTrafficThresholdBytesPerSecond
        case isPetMoodFeedbackEnabled
        case isPetActivityLevelEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PetSettings.default
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? fallback.isEnabled,
            isQuietModeEnabled: try container.decodeIfPresent(Bool.self, forKey: .isQuietModeEnabled) ?? fallback.isQuietModeEnabled,
            personality: try container.decodeIfPresent(PetPersonality.self, forKey: .personality) ?? fallback.personality,
            enabledReminderIDs: try container.decodeIfPresent(Set<String>.self, forKey: .enabledReminderIDs) ?? fallback.enabledReminderIDs,
            enabledSkillIDs: try container.decodeIfPresent(Set<String>.self, forKey: .enabledSkillIDs) ?? fallback.enabledSkillIDs,
            highTrafficThresholdBytesPerSecond: try container.decodeIfPresent(
                Double.self,
                forKey: .highTrafficThresholdBytesPerSecond
            ) ?? fallback.highTrafficThresholdBytesPerSecond,
            isPetMoodFeedbackEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isPetMoodFeedbackEnabled
            ) ?? fallback.isPetMoodFeedbackEnabled,
            isPetActivityLevelEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isPetActivityLevelEnabled
            ) ?? fallback.isPetActivityLevelEnabled
        )
    }
}

struct PetState: Codable, Equatable {
    var mood: PetMood
    var activityLevel: PetActivityLevel
    var energy: Int
    var affection: Int
    var activeSkillID: String?
    var activeSkillStartedAt: Date?
    var activeSkillEndsAt: Date?
    var lastInteraction: PetInteraction?
    var lastInteractionAt: Date?
    var lastReminderAtByKind: [String: Date]
    var lastSkillTriggeredAtByID: [String: Date]
    var createdAt: Date
    var lastUpdatedAt: Date

    init(
        mood: PetMood,
        activityLevel: PetActivityLevel,
        energy: Int,
        affection: Int,
        activeSkillID: String?,
        activeSkillStartedAt: Date?,
        activeSkillEndsAt: Date?,
        lastInteraction: PetInteraction?,
        lastInteractionAt: Date?,
        lastReminderAtByKind: [String: Date],
        lastSkillTriggeredAtByID: [String: Date],
        createdAt: Date,
        lastUpdatedAt: Date
    ) {
        self.mood = mood
        self.activityLevel = activityLevel
        self.energy = energy
        self.affection = affection
        self.activeSkillID = activeSkillID
        self.activeSkillStartedAt = activeSkillStartedAt
        self.activeSkillEndsAt = activeSkillEndsAt
        self.lastInteraction = lastInteraction
        self.lastInteractionAt = lastInteractionAt
        self.lastReminderAtByKind = lastReminderAtByKind
        self.lastSkillTriggeredAtByID = lastSkillTriggeredAtByID
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    static func `default`(now: Date = Date()) -> PetState {
        PetState(
            mood: .happy,
            activityLevel: .idle,
            energy: 80,
            affection: 0,
            activeSkillID: nil,
            activeSkillStartedAt: nil,
            activeSkillEndsAt: nil,
            lastInteraction: nil,
            lastInteractionAt: nil,
            lastReminderAtByKind: [:],
            lastSkillTriggeredAtByID: [:],
            createdAt: now,
            lastUpdatedAt: now
        )
    }

    mutating func recordReminder(_ kind: PetReminderKind, at date: Date) {
        lastReminderAtByKind[kind.rawValue] = date
    }

    func lastReminderDate(for kind: PetReminderKind) -> Date? {
        lastReminderAtByKind[kind.rawValue]
    }

    mutating func recordSkillTrigger(_ skillID: PetSkillID, at date: Date) {
        lastSkillTriggeredAtByID[skillID.rawValue] = date
    }

    func lastSkillTriggeredDate(for skillID: PetSkillID) -> Date? {
        lastSkillTriggeredAtByID[skillID.rawValue]
    }

    mutating func markUpdated(at date: Date) {
        lastUpdatedAt = date
    }
}

extension PetState {
    private enum CodingKeys: String, CodingKey {
        case mood
        case activityLevel
        case energy
        case affection
        case activeSkillID
        case activeSkillStartedAt
        case activeSkillEndsAt
        case lastInteraction
        case lastInteractionAt
        case lastReminderAtByKind
        case lastSkillTriggeredAtByID
        case createdAt
        case lastUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        self.init(
            mood: try container.decodeIfPresent(PetMood.self, forKey: .mood) ?? .happy,
            activityLevel: try container.decodeIfPresent(PetActivityLevel.self, forKey: .activityLevel) ?? .idle,
            energy: try container.decodeIfPresent(Int.self, forKey: .energy) ?? 80,
            affection: try container.decodeIfPresent(Int.self, forKey: .affection) ?? 0,
            activeSkillID: try container.decodeIfPresent(String.self, forKey: .activeSkillID),
            activeSkillStartedAt: try container.decodeIfPresent(Date.self, forKey: .activeSkillStartedAt),
            activeSkillEndsAt: try container.decodeIfPresent(Date.self, forKey: .activeSkillEndsAt),
            lastInteraction: try container.decodeIfPresent(PetInteraction.self, forKey: .lastInteraction),
            lastInteractionAt: try container.decodeIfPresent(Date.self, forKey: .lastInteractionAt),
            lastReminderAtByKind: try container.decodeIfPresent([String: Date].self, forKey: .lastReminderAtByKind) ?? [:],
            lastSkillTriggeredAtByID: try container.decodeIfPresent([String: Date].self, forKey: .lastSkillTriggeredAtByID) ?? [:],
            createdAt: createdAt,
            lastUpdatedAt: try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? createdAt
        )
    }
}
