import AppKit
import Foundation

// MARK: - Animation Character Definition

enum RunCatCharacter: String, CaseIterable {
    case cat = "cat"
    case gamingCat = "gaming-cat"
    case partyParrot = "party-parrot"

    var displayName: String {
        switch self {
        case .cat: return "ネコ"
        case .gamingCat: return "ゲーミング・ネコ"
        case .partyParrot: return "虹色のオウム"
        }
    }

    var localizedName: String { displayName }

    /// Number of animation frames for this character
    var frameCount: Int {
        switch self {
        case .cat: return 5
        case .gamingCat: return 10
        case .partyParrot: return 10
        }
    }

    /// Whether this character uses template rendering (monochrome, macOS auto-inverts)
    var isTemplate: Bool {
        switch self {
        case .cat: return true
        case .gamingCat: return false  // Has RGB colors (gaming RGB)
        case .partyParrot: return false // Has RGB colors (rainbow parrot)
        }
    }

    /// Resource subdirectory name in Resources/RunCat/
    var resourceDir: String { rawValue }
}

// MARK: - RunCatAnimation

@MainActor
final class RunCatAnimation {
    private var timer: Timer?
    private var currentFrame: Int = 0
    private var isActive: Bool = false
    private var frames: [NSImage] = []
    private var character: RunCatCharacter = .cat
    private var speedMultiplier: Double = 1.0

    /// Current animation interval in seconds (based on network speed + multiplier)
    private var currentInterval: TimeInterval = 0.5

    /// Callback invoked when the frame changes (passes frame index)
    var onFrameChange: ((Int) -> Void)?

    // MARK: - Initialization

    init(character: RunCatCharacter = .cat, speedMultiplier: Double = 1.0, onFrameChange: @escaping (Int) -> Void) {
        self.character = character
        self.speedMultiplier = speedMultiplier
        self.onFrameChange = onFrameChange
        loadFrames()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Frame Loading

    private func loadFrames() {
        frames.removeAll()
        let resourcePath = "RunCat/\(character.resourceDir)"

        for i in 0..<character.frameCount {
            if let url = Bundle.main.url(forResource: "frame_\(i)", withExtension: "png", subdirectory: resourcePath) {
                if let image = NSImage(contentsOf: url) {
                    image.isTemplate = character.isTemplate
                    frames.append(image)
                }
            }
        }

        // Fallback: if no frames loaded from bundle, try path-based loading
        if frames.isEmpty {
            loadFramesFromPath()
        }

        // Ensure we have at least one frame
        if frames.isEmpty {
            frames.append(createFallbackImage())
        }
    }

    private func loadFramesFromPath() {
        for i in 0..<character.frameCount {
            let fileName = "frame_\(i).png"
            // Try Bundle.main.resourcePath
            if let resourcePath = Bundle.main.resourcePath {
                let fullPath = "\(resourcePath)/RunCat/\(character.resourceDir)/\(fileName)"
                if let image = NSImage(contentsOf: URL(fileURLWithPath: fullPath)) {
                    image.isTemplate = character.isTemplate
                    frames.append(image)
                }
            }
        }
    }

    private func createFallbackImage() -> NSImage {
        // Create a tiny 16x16 template image as fallback
        let size = NSSize(width: 28, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        let body = NSRect(x: 4, y: 6, width: 14, height: 8)
        body.fill()
        let head = NSRect(x: 18, y: 8, width: 6, height: 6)
        head.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Character & Speed Changes

    func setCharacter(_ newCharacter: RunCatCharacter) {
        guard newCharacter != character else { return }
        character = newCharacter
        currentFrame = 0
        loadFrames()
        if isActive {
            restartTimer()
        }
        onFrameChange?(currentFrame)
    }

    func setSpeedMultiplier(_ multiplier: Double) {
        speedMultiplier = max(0.25, min(4.0, multiplier))
        if isActive {
            restartTimer()
        }
    }

    // MARK: - Network Speed

    /// Update animation speed based on network throughput.
    /// - Parameter totalBytesPerSecond: Combined upload + download speed in bytes/sec
    func updateNetworkSpeed(totalBytesPerSecond: Double) {
        // Logarithmic mapping:
        // 0 B/s   → 500ms interval (slow idle animation)
        // 1 KB/s  → 250ms
        // 100 KB/s → 100ms
        // 1 MB/s  → 60ms
        // 100 MB/s+ → 40ms
        let baseInterval: TimeInterval
        if totalBytesPerSecond <= 0 {
            baseInterval = 0.5
        } else {
            let speedMB = totalBytesPerSecond / 1_000_000
            // Log mapping: faster speed = shorter interval
            baseInterval = max(0.04, min(0.5, 0.5 / (1.0 + log10(max(speedMB, 0.001) + 1.0) * 3.0)))
        }

        let adjustedInterval = baseInterval / speedMultiplier
        let newInterval = max(0.03, min(2.0, adjustedInterval))

        if abs(newInterval - currentInterval) > 0.005 {
            currentInterval = newInterval
            if isActive {
                restartTimer()
            }
        }
    }

    // MARK: - Active State

    func setActive(_ active: Bool) {
        if active && !isActive {
            isActive = true
            restartTimer()
        } else if !active && isActive {
            isActive = false
            stop()
        }
    }

    // MARK: - Timer

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    private func advanceFrame() {
        currentFrame = (currentFrame + 1) % max(frames.count, 1)
        onFrameChange?(currentFrame)
    }

    // MARK: - Frame Access

    var currentFrameIndex: Int { currentFrame }

    /// Get the current frame as an NSImage
    func currentImage() -> NSImage? {
        guard !frames.isEmpty else { return nil }
        return frames[currentFrame % frames.count]
    }

    /// Get a specific frame as an NSImage
    func image(at index: Int) -> NSImage? {
        guard index >= 0, index < frames.count else { return nil }
        return frames[index]
    }

    /// The natural size of the animation frame (in points, accounting for retina)
    var frameSize: NSSize {
        if let first = frames.first {
            return first.size
        }
        return NSSize(width: 28, height: 18)
    }
}
