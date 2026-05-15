import AppKit
import Foundation

enum CustomCharacterSourceKind: String, Codable, CaseIterable, Identifiable {
    case staticImage
    case gif
    case frameSequence

    var id: String { rawValue }
}

enum CustomCharacterMotionStyle: String, Codable, CaseIterable, Identifiable {
    case bounceBreathe
    case swayRun
    case pixelJitterFlicker

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .bounceBreathe:
            return language.text("呼吸/弹跳", "Bounce/Breathe")
        case .swayRun:
            return language.text("左右摇摆/跑动", "Sway/Run")
        case .pixelJitterFlicker:
            return language.text("像素抖动/闪烁", "Pixel Jitter/Flicker")
        }
    }
}

enum CustomCharacterPixelationScale: Int, Codable, CaseIterable, Identifiable {
    case off = 1
    case two = 2
    case three = 3
    case four = 4
    case six = 6
    case eight = 8

    var id: Int { rawValue }

    var displayValue: String {
        self == .off ? "Off" : "\(rawValue)x"
    }

    static func clamped(_ value: Int) -> CustomCharacterPixelationScale {
        if let exact = Self(rawValue: value) {
            return exact
        }
        if value <= Self.off.rawValue {
            return .off
        }
        if value >= Self.eight.rawValue {
            return .eight
        }
        return Self.allCases.last { $0.rawValue <= value } ?? .off
    }
}

struct CustomCharacter: Codable, Equatable, Identifiable {
    let id: String
    var displayName: String
    var sourceKind: CustomCharacterSourceKind
    var frameCount: Int
    var frameWidth: Int
    var frameHeight: Int
    var motionStyle: CustomCharacterMotionStyle?
    var pixelationScale: CustomCharacterPixelationScale
    var createdAt: Date
    var updatedAt: Date

    var directoryName: String { id }

    var sanitizedFrameCount: Int {
        max(frameCount, 1)
    }
}

struct CustomCharacterImportSelection: Equatable {
    let sourceKind: CustomCharacterSourceKind
    let urls: [URL]

    static func classify(_ urls: [URL]) -> CustomCharacterImportSelection? {
        guard !urls.isEmpty else { return nil }
        let sorted = CustomCharacterImageProcessor.sortedFrameURLs(urls)
        if sorted.count == 1 {
            let url = sorted[0]
            let ext = url.pathExtension.lowercased()
            if ext == "gif" {
                return CustomCharacterImportSelection(sourceKind: .gif, urls: sorted)
            }
            return CustomCharacterImportSelection(sourceKind: .staticImage, urls: sorted)
        }
        return CustomCharacterImportSelection(sourceKind: .frameSequence, urls: sorted)
    }
}

struct CharacterAsset: Equatable, Identifiable {
    enum Source: Equatable {
        case builtIn(RunCatCharacter)
        case custom(CustomCharacter)
    }

    let source: Source

    init(builtIn character: RunCatCharacter) {
        source = .builtIn(character)
    }

    init(custom character: CustomCharacter) {
        source = .custom(character)
    }

    static func resolve(id: String, customCharacters: [CustomCharacter]) -> CharacterAsset {
        if id.hasPrefix("custom.") {
            guard let custom = customCharacters.first(where: { $0.id == id }) else {
                return CharacterAsset(builtIn: .defaultCat)
            }
            return CharacterAsset(custom: custom)
        }
        return CharacterAsset(builtIn: RunCatCharacter.byId(id))
    }

    var id: String {
        switch source {
        case .builtIn(let character):
            return character.id
        case .custom(let character):
            return character.id
        }
    }

    var displayName: String {
        switch source {
        case .builtIn(let character):
            return character.displayName
        case .custom(let character):
            return character.displayName
        }
    }

    var frameCount: Int {
        switch source {
        case .builtIn(let character):
            return character.frameCount
        case .custom(let character):
            return character.sanitizedFrameCount
        }
    }

    var frameWidth: Int {
        switch source {
        case .builtIn(let character):
            return character.frameWidth
        case .custom(let character):
            return max(character.frameWidth, 1)
        }
    }

    var frameHeight: Int {
        switch source {
        case .builtIn:
            return 18
        case .custom(let character):
            return max(character.frameHeight, 1)
        }
    }

    var isCustom: Bool {
        if case .custom = source { return true }
        return false
    }

    var isTemplate: Bool {
        switch source {
        case .builtIn(let character):
            return character.isTemplate
        case .custom:
            return false
        }
    }

    var isGooglyEyes: Bool {
        switch source {
        case .builtIn(let character):
            return character.isGooglyEyes
        case .custom:
            return false
        }
    }

    var supportsColorControls: Bool {
        switch source {
        case .builtIn(let character):
            return character.supportsColorControls
        case .custom:
            return false
        }
    }
}

