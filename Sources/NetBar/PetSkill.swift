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
