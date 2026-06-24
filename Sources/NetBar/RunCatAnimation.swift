import AppKit
import Foundation

// MARK: - RunCat Character Definition

struct RunCatCharacter: Equatable, Identifiable {
    let id: String           // Resource directory name
    let nameZh: String       // Chinese name
    let nameEn: String       // English name
    let nameJa: String       // Japanese name (original)
    let frameCount: Int      // Number of animation frames
    let frameWidth: Int      // Width of each frame in pixels at 1x
    let isTemplate: Bool     // True = monochrome (system theme aware), False = full color
    let category: Category   // Character category

    enum Category: String, CaseIterable {
        case `default` = "默认"     // Free default runners
        case animal = "生物"        // Animal runners
        case inanimate = "非生物"   // Inanimate runners
        case seasonal = "季节"      // Seasonal runners
        case special = "特别"       // Special color runners
    }

    var resourceDir: String { id }
    var isGooglyEyes: Bool { id == Self.googlyEyesID }
    var supportsColorControls: Bool { !Self.originalColorOnlyIDs.contains(id) }

    var displayName: String {
        // Use Chinese name by default; can be switched based on locale
        nameZh
    }

    func displayName(language: AppLanguage) -> String {
        language == .simplifiedChinese ? nameZh : nameEn
    }

    static let allCharacters: [RunCatCharacter] = [
        // Default (free) runners
        RunCatCharacter(id: "cat", nameZh: "猫咪 α", nameEn: "Cat α", nameJa: "ネコ α",
                        frameCount: 5, frameWidth: 28, isTemplate: true, category: .default),
        RunCatCharacter(id: "cat_b", nameZh: "猫咪 β", nameEn: "Cat β", nameJa: "ネコ β",
                        frameCount: 5, frameWidth: 32, isTemplate: true, category: .default),
        RunCatCharacter(id: "cat_c", nameZh: "猫咪 γ", nameEn: "Cat γ", nameJa: "ネコ γ",
                        frameCount: 5, frameWidth: 42, isTemplate: true, category: .default),
        RunCatCharacter(id: "cat_tail", nameZh: "猫尾巴", nameEn: "Cat Tail", nameJa: "猫のしっぽ",
                        frameCount: 8, frameWidth: 56, isTemplate: true, category: .default),
        RunCatCharacter(id: "mock_nyan_cat", nameZh: "彩虹猫", nameEn: "Mock Nyan Cat", nameJa: "Nyan Cat もどき",
                        frameCount: 5, frameWidth: 44, isTemplate: false, category: .default),
        RunCatCharacter(id: "gaming-cat", nameZh: "游戏猫", nameEn: "Gaming Cat", nameJa: "ゲーミングキャット",
                        frameCount: 10, frameWidth: 34, isTemplate: false, category: .default),
        RunCatCharacter(id: "party-parrot", nameZh: "派对鹦鹉", nameEn: "Party Parrot", nameJa: "パーティーオウム",
                        frameCount: 10, frameWidth: 28, isTemplate: false, category: .default),

        // Animal runners
        RunCatCharacter(id: "cheetah", nameZh: "猎豹", nameEn: "Cheetah", nameJa: "チーター",
                        frameCount: 5, frameWidth: 41, isTemplate: true, category: .animal),
        RunCatCharacter(id: "dog", nameZh: "小狗", nameEn: "Dog", nameJa: "イヌ",
                        frameCount: 5, frameWidth: 33, isTemplate: true, category: .animal),
        RunCatCharacter(id: "puppy", nameZh: "幼犬", nameEn: "Puppy", nameJa: "子犬",
                        frameCount: 5, frameWidth: 31, isTemplate: true, category: .animal),
        RunCatCharacter(id: "rabbit", nameZh: "兔子", nameEn: "Rabbit", nameJa: "ウサギ",
                        frameCount: 5, frameWidth: 22, isTemplate: true, category: .animal),
        RunCatCharacter(id: "frog", nameZh: "青蛙", nameEn: "Frog", nameJa: "カエル",
                        frameCount: 5, frameWidth: 25, isTemplate: true, category: .animal),
        RunCatCharacter(id: "prism_fox", nameZh: "棱镜狐", nameEn: "Prism Fox", nameJa: "プリズムフォックス",
                        frameCount: 5, frameWidth: 40, isTemplate: false, category: .animal),
        RunCatCharacter(id: "starlight_dragon", nameZh: "星辉幼龙", nameEn: "Starlight Dragon", nameJa: "スターライトドラゴン",
                        frameCount: 5, frameWidth: 46, isTemplate: false, category: .animal),
        RunCatCharacter(id: "shiba_inu", nameZh: "柴犬", nameEn: "Shiba Inu", nameJa: "柴犬",
                        frameCount: 6, frameWidth: 28, isTemplate: false, category: .animal),
        RunCatCharacter(id: "bunny", nameZh: "兔兔", nameEn: "Bunny", nameJa: "うさぎ",
                        frameCount: 6, frameWidth: 24, isTemplate: false, category: .animal),
        RunCatCharacter(id: "penguin", nameZh: "企鹅", nameEn: "Penguin", nameJa: "ペンギン",
                        frameCount: 6, frameWidth: 26, isTemplate: false, category: .animal),

        // Inanimate runners
        RunCatCharacter(id: "cogwheel", nameZh: "齿轮", nameEn: "Cogwheel", nameJa: "歯車",
                        frameCount: 5, frameWidth: 19, isTemplate: true, category: .inanimate),
        RunCatCharacter(id: "bonfire", nameZh: "篝火", nameEn: "Bonfire", nameJa: "焚き火",
                        frameCount: 5, frameWidth: 14, isTemplate: true, category: .inanimate),
        RunCatCharacter(id: "drop", nameZh: "水滴", nameEn: "Drop", nameJa: "水滴",
                        frameCount: 5, frameWidth: 22, isTemplate: true, category: .inanimate),
        RunCatCharacter(id: "rocket", nameZh: "火箭", nameEn: "Rocket", nameJa: "ロケット",
                        frameCount: 5, frameWidth: 18, isTemplate: true, category: .inanimate),
        RunCatCharacter(id: "pendulum", nameZh: "钟摆", nameEn: "Pendulum", nameJa: "振り子",
                        frameCount: 8, frameWidth: 12, isTemplate: true, category: .inanimate),
        RunCatCharacter(id: "coffee_cup", nameZh: "咖啡杯", nameEn: "Coffee Cup", nameJa: "コーヒーカップ",
                        frameCount: 6, frameWidth: 24, isTemplate: false, category: .inanimate),
        RunCatCharacter(id: "little_cloud", nameZh: "小云朵", nameEn: "Little Cloud", nameJa: "小さな雲",
                        frameCount: 6, frameWidth: 28, isTemplate: false, category: .inanimate),
        RunCatCharacter(id: "tiny_plant", nameZh: "小盆栽", nameEn: "Tiny Plant", nameJa: "小さな鉢植え",
                        frameCount: 6, frameWidth: 24, isTemplate: false, category: .inanimate),

        // Seasonal runners
        RunCatCharacter(id: "reindeer", nameZh: "驯鹿与雪橇", nameEn: "Reindeer & Sleigh", nameJa: "トナカイとソリ",
                        frameCount: 5, frameWidth: 58, isTemplate: true, category: .seasonal),
        RunCatCharacter(id: "snowman", nameZh: "雪人", nameEn: "Snowman", nameJa: "雪だるま",
                        frameCount: 5, frameWidth: 26, isTemplate: true, category: .seasonal),
        RunCatCharacter(id: "wind_chime", nameZh: "风铃", nameEn: "Wind Chime", nameJa: "風鈴",
                        frameCount: 8, frameWidth: 13, isTemplate: false, category: .seasonal),
        RunCatCharacter(id: "sparkler", nameZh: "线香烟花", nameEn: "Sparkler", nameJa: "線香花火",
                        frameCount: 5, frameWidth: 22, isTemplate: false, category: .seasonal),

        // Special color runners
        RunCatCharacter(id: googlyEyesID, nameZh: "追踪眼睛", nameEn: "Googly Eyes", nameJa: "Googly Eyes",
                        frameCount: 2, frameWidth: 36, isTemplate: false, category: .special),
        RunCatCharacter(id: "golden_cat", nameZh: "黄金猫", nameEn: "Golden Cat", nameJa: "黄金のネコ",
                        frameCount: 10, frameWidth: 45, isTemplate: false, category: .special),
        RunCatCharacter(id: "metal_cluster_cat", nameZh: "金属集群猫", nameEn: "Metal Cluster Cat", nameJa: "メタルクラスタ キャット",
                        frameCount: 10, frameWidth: 149, isTemplate: false, category: .special),
        RunCatCharacter(id: "flash_cat", nameZh: "闪光猫", nameEn: "Flash Cat", nameJa: "赤い閃光猫",
                        frameCount: 5, frameWidth: 42, isTemplate: false, category: .special),
        RunCatCharacter(id: "maneki_neko", nameZh: "招财猫", nameEn: "Maneki Neko", nameJa: "招き猫",
                        frameCount: 15, frameWidth: 14, isTemplate: true, category: .special),
        RunCatCharacter(id: "chroma_slime", nameZh: "幻彩史莱姆", nameEn: "Chroma Slime", nameJa: "クロマスライム",
                        frameCount: 6, frameWidth: 30, isTemplate: false, category: .special),
        RunCatCharacter(id: "sushi", nameZh: "寿司", nameEn: "Sushi", nameJa: "お寿司",
                        frameCount: 16, frameWidth: 58, isTemplate: false, category: .special),
    ]

    static func byId(_ id: String) -> RunCatCharacter {
        allCharacters.first { $0.id == id } ?? allCharacters[0]
    }

    private static let googlyEyesID = "googly_eyes"
    private static let originalColorOnlyIDs: Set<String> = [
        "shiba_inu",
        "bunny",
        "penguin",
        "coffee_cup",
        "little_cloud",
        "tiny_plant",
        "sushi"
    ]
    static let defaultCat = allCharacters[0]
}

enum GooglyEyesTracker {
    static func screenCenter(forLocalCenter localCenter: CGPoint, statusItemFrame: CGRect) -> CGPoint {
        CGPoint(
            x: statusItemFrame.minX + localCenter.x,
            y: statusItemFrame.minY + localCenter.y
        )
    }

    static func pupilOffset(
        from eyeCenter: CGPoint,
        toward mouseLocation: CGPoint,
        maximumDistance: CGFloat
    ) -> CGSize {
        let deltaX = mouseLocation.x - eyeCenter.x
        let deltaY = mouseLocation.y - eyeCenter.y
        let distance = hypot(deltaX, deltaY)
        guard distance > 0, maximumDistance > 0 else { return .zero }

        let scale = min(distance, maximumDistance) / distance
        return CGSize(width: deltaX * scale, height: deltaY * scale)
    }
}

struct CharacterPreviewFrameTimeline: Equatable {
    private(set) var characterID: String?
    private(set) var frameIndex = 0

    func frameIndex(for character: CharacterAsset) -> Int {
        guard characterID == character.id else { return 0 }
        return frameIndex % max(character.frameCount, 1)
    }

    mutating func displayedFrame(for character: CharacterAsset) -> Int {
        sync(to: character)
        return frameIndex(for: character)
    }

    mutating func advance(for character: CharacterAsset) {
        sync(to: character)
        frameIndex = (frameIndex + 1) % max(character.frameCount, 1)
    }

    mutating func reset() {
        characterID = nil
        frameIndex = 0
    }

    private mutating func sync(to character: CharacterAsset) {
        guard characterID != character.id else { return }
        characterID = character.id
        frameIndex = 0
    }
}

// MARK: - Activity Level

enum ActivityLevel: Equatable {
    case idle       // < 100 B/s
    case low        // 100 B/s – 1 KB/s
    case moderate   // 1 KB/s – 100 KB/s
    case high       // > 100 KB/s
}

// MARK: - RunCat Animation Controller

final class RunCatAnimation {
    struct AnimatedCharacter: Equatable {
        let id: String
        let frameCount: Int

        init(asset: CharacterAsset) {
            id = asset.id
            frameCount = asset.frameCount
        }

        init(character: RunCatCharacter) {
            id = character.id
            frameCount = character.frameCount
        }
    }

    private(set) var character: AnimatedCharacter
    private var speedMultiplier: Double
    private let onFrameChange: (Int) -> Void
    var onPlaybackComplete: ((String) -> Void)?
    var onCharacterChange: ((RunCatCharacter) -> Void)?

    private var timer: Timer?
    private var rotationTimer: Timer?
    private var currentFrame: Int = 0
    private var isActive = false

    // Rotation settings
    var rotationEnabled: Bool = false
    var rotationIntervalMinutes: Double = 5.0
    var rotationPool: [RunCatCharacter] = []  // empty = all characters

    // Adaptive frame rate state
    private(set) var activityLevel: ActivityLevel = .idle
    private var idleStartDate: Date?
    private var isStatic = false
    private static let idleThreshold: TimeInterval = 30.0

    // Screen lock state
    private var wasActiveBeforeScreenLock = false

    init(character: CharacterAsset, speedMultiplier: Double = 1.0, onFrameChange: @escaping (Int) -> Void) {
        self.character = AnimatedCharacter(asset: character)
        self.speedMultiplier = speedMultiplier
        self.onFrameChange = onFrameChange
    }

    deinit {
        timer?.invalidate()
        timer = nil
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    func setActive(_ active: Bool) {
        if active && !isActive {
            isActive = true
            idleStartDate = activityLevel == .idle ? Date() : nil
            scheduleTimer()
            scheduleRotationTimer()
        } else if !active && isActive {
            isActive = false
            timer?.invalidate()
            timer = nil
            rotationTimer?.invalidate()
            rotationTimer = nil
        }
    }

    func setSpeedMultiplier(_ multiplier: Double) {
        speedMultiplier = multiplier
        if isActive {
            scheduleTimer()
        }
    }

    func pauseForScreenLock() {
        wasActiveBeforeScreenLock = isActive
        if isActive {
            timer?.invalidate()
            timer = nil
            rotationTimer?.invalidate()
            rotationTimer = nil
        }
    }

    func resumeFromScreenLock() {
        if wasActiveBeforeScreenLock {
            isActive = false
            setActive(true)
        }
        wasActiveBeforeScreenLock = false
    }

    func updateNetworkSpeed(totalBytesPerSecond: UInt64) {
        let bps = Double(totalBytesPerSecond)
        let newLevel: ActivityLevel
        if bps < 100 {
            newLevel = .idle
        } else if bps < 1_000 {
            newLevel = .low
        } else if bps < 100_000 {
            newLevel = .moderate
        } else {
            newLevel = .high
        }

        applyActivityLevel(newLevel)
    }

    /// Directly set an externally computed activity level (e.g. from CPU/memory/thermal metrics).
    func updateActivityLevel(_ level: ActivityLevel) {
        applyActivityLevel(level)
    }

    private func applyActivityLevel(_ newLevel: ActivityLevel) {
        let wasIdle = activityLevel == .idle
        activityLevel = newLevel

        if newLevel == .idle {
            if !wasIdle {
                idleStartDate = Date()
            }
        } else {
            idleStartDate = nil
        }

        // Resume from static when traffic returns
        if isStatic && newLevel != .idle {
            isStatic = false
            if isActive {
                scheduleTimer()
            }
            return
        }

        // Re-schedule timer when activity level changes
        if isActive && !isStatic {
            scheduleTimer()
        }
    }

    func checkIdleTimeout() {
        guard isActive, !isStatic, activityLevel == .idle else { return }
        if let idleStart = idleStartDate, Date().timeIntervalSince(idleStart) >= Self.idleThreshold {
            enterStaticMode()
        }
    }

    private func enterStaticMode() {
        isStatic = true
        timer?.invalidate()
        timer = nil
    }

    var isGooglyEyes: Bool {
        character.id == "googly_eyes"
    }

    private func targetInterval() -> TimeInterval {
        let baseInterval: TimeInterval
        switch activityLevel {
        case .idle:
            if isGooglyEyes {
                baseInterval = 1.0 / 5.0  // 5 FPS for GooglyEyes idle
            } else {
                baseInterval = 2.0  // 0.5 FPS
            }
        case .low:
            baseInterval = 1.0  // 1 FPS
        case .moderate:
            baseInterval = 0.5  // 2 FPS
        case .high:
            baseInterval = 1.0 / 10.0  // 10 FPS
        }
        return max(baseInterval / speedMultiplier, 1.0 / 15.0)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = targetInterval()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        let frameCount = max(character.frameCount, 1)
        let previousFrame = currentFrame
        currentFrame = (currentFrame + 1) % frameCount
        onFrameChange(currentFrame)
        if frameCount > 1 && previousFrame == frameCount - 1 && currentFrame == 0 {
            onPlaybackComplete?(character.id)
        }
        checkIdleTimeout()
    }

    func advanceFrameForTesting() {
        advanceFrame()
    }

    // MARK: - Character Rotation

    private func scheduleRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard rotationEnabled else { return }
        let pool = rotationPool.isEmpty ? RunCatCharacter.allCharacters : rotationPool
        guard pool.count > 1 else { return }  // No rotation needed with only 1 character
        let interval = max(rotationIntervalMinutes * 60, 10)  // Minimum 10 seconds
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.rotateToNextCharacter()
        }
    }

    func configureRotation(enabled: Bool, intervalMinutes: Double, pool: [RunCatCharacter]) {
        rotationEnabled = enabled
        rotationIntervalMinutes = intervalMinutes
        rotationPool = pool
        if isActive {
            scheduleRotationTimer()
        }
    }

    private func rotateToNextCharacter() {
        let pool = rotationPool.isEmpty ? RunCatCharacter.allCharacters : rotationPool
        guard pool.count > 1 else { return }
        // Pick a random character different from current
        let candidates = pool.filter { $0.id != character.id }
        guard let next = candidates.randomElement() else { return }
        character = AnimatedCharacter(character: next)
        currentFrame = 0
        onCharacterChange?(next)
    }
}
