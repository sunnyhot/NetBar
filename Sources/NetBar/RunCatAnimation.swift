import AppKit

// MARK: - RunCat Animation Controller

@MainActor
final class RunCatAnimation {
    private(set) var currentFrameIndex: Int = 0
    let totalFrames: Int = 6
    private var timer: Timer?
    private var currentBytesPerSecond: Double = 0
    private var isActive: Bool = true

    var onFrameChange: ((Int) -> Void)?

    /// Width of the cat graphic in points
    static let catWidth: CGFloat = 22
    /// Right padding after the cat before the speed text
    static let catPadding: CGFloat = 3
    /// Total width consumed by the cat in the status bar (cat + padding)
    static let totalWidth: CGFloat = catWidth + catPadding

    init(onFrameChange: ((Int) -> Void)? = nil) {
        self.onFrameChange = onFrameChange
        rescheduleTimer()
    }

    func updateNetworkSpeed(upload: Double, download: Double) {
        let total = upload + download
        let changed = abs(total - currentBytesPerSecond) > 100
        currentBytesPerSecond = total
        if changed {
            rescheduleTimer()
        }
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active {
            rescheduleTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func rescheduleTimer() {
        guard isActive else { return }
        let fps = Self.speedToFPS(currentBytesPerSecond)
        let interval = 1.0 / fps

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % totalFrames
        onFrameChange?(currentFrameIndex)
    }

    /// Map network speed (bytes/s) to animation FPS.
    /// Uses logarithmic mapping for a natural feel:
    /// - 0 B/s     → 2 FPS  (nearly still, gentle idle)
    /// - 1 KB/s    → ~3 FPS (slow walk)
    /// - 100 KB/s  → ~5 FPS (walking)
    /// - 1 MB/s    → ~9 FPS (trotting)
    /// - 10 MB/s   → ~15 FPS (running)
    /// - 100 MB/s+ → 24 FPS (full sprint)
    private static func speedToFPS(_ bytesPerSecond: Double) -> Double {
        if bytesPerSecond <= 0 { return 2 }
        let bps = max(bytesPerSecond, 1)
        let logSpeed = log10(bps) // 0..9 for 1 B/s..1 GB/s
        let fps = 2 + (logSpeed / 9.0) * 22.0
        return min(max(fps, 2), 24)
    }

    // MARK: - Cat Frame Drawing (NSImage output)

    /// Draw the cat for a specific animation frame and return an NSImage.
    /// - Parameters:
    ///   - frameIndex: Animation frame (0..<6)
    ///   - scale: Retina scale factor (typically 2.0)
    /// - Returns: NSImage of the cat silhouette
    static func drawCatFrame(_ frameIndex: Int, scale: CGFloat = 2.0) -> NSImage {
        let width: CGFloat = catWidth
        let height: CGFloat = 18
        let size = NSSize(width: width, height: height)
        let safeScale = max(scale, 1)
        let pixelsWide = max(Int(ceil(width * safeScale)), 1)
        let pixelsHigh = max(Int(ceil(height * safeScale)), 1)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }

        representation.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return NSImage(size: size)
        }

        // Clear background
        context.clear(CGRect(origin: .zero, size: CGSize(width: pixelsWide, height: pixelsHigh)))

        // Draw cat silhouette in black (will be rendered as template image by status bar)
        let catColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        drawCatSilhouette(frameIndex, in: context, rect: CGRect(origin: .zero, size: size), color: catColor)

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        image.isTemplate = true
        return image
    }

    // MARK: - Cat Silhouette Drawing

    static func drawCatSilhouette(_ frameIndex: Int, in context: CGContext, rect: CGRect, color: CGColor) {
        let height = rect.height
        // Design coordinates: 22×22 pt bounding box, origin at bottom-left
        // Scale to fit the actual rect height while maintaining aspect ratio
        let scale = height / 22.0

        context.saveGState()
        context.translateBy(x: rect.origin.x, y: rect.origin.y)
        context.scaleBy(x: scale, y: scale)

        context.setFillColor(color)

        // Body (horizontal ellipse)
        context.fillEllipse(in: CGRect(x: 5, y: 7, width: 10, height: 5))

        // Head (circle, overlapping right side of body)
        context.fillEllipse(in: CGRect(x: 13, y: 8, width: 6.5, height: 6.5))

        // Left ear (triangle)
        context.move(to: CGPoint(x: 14.5, y: 14.5))
        context.addLine(to: CGPoint(x: 14.5, y: 17.5))
        context.addLine(to: CGPoint(x: 16.5, y: 14.5))
        context.closePath()
        context.fillPath()

        // Right ear (triangle)
        context.move(to: CGPoint(x: 17, y: 14.5))
        context.addLine(to: CGPoint(x: 18, y: 17.5))
        context.addLine(to: CGPoint(x: 19.5, y: 14.5))
        context.closePath()
        context.fillPath()

        // Eye (white dot for contrast)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fillEllipse(in: CGRect(x: 17.5, y: 10.5, width: 1.2, height: 1.5))
        context.setFillColor(color)

        // Tail (thick curved stroke going up-left)
        context.setStrokeColor(color)
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 5, y: 10))
        context.addCurve(
            to: CGPoint(x: 1.5, y: 16.5),
            control1: CGPoint(x: 4, y: 12),
            control2: CGPoint(x: 2, y: 14.5)
        )
        context.strokePath()

        // Legs (thick stroked lines, positions vary per frame)
        drawLegs(frame: frameIndex, in: context, color: color)

        context.restoreGState()
    }

    private static func drawLegs(frame: Int, in context: CGContext, color: CGColor) {
        context.setStrokeColor(color)
        context.setLineWidth(1.8)
        context.setLineCap(.round)

        switch frame {
        case 0: // Full stride — front legs forward, back legs back
            // Front right (reaching forward)
            context.move(to: CGPoint(x: 14, y: 7))
            context.addLine(to: CGPoint(x: 17, y: 2.5))
            // Front left
            context.move(to: CGPoint(x: 12, y: 7))
            context.addLine(to: CGPoint(x: 14.5, y: 3))
            // Back right (stretching back)
            context.move(to: CGPoint(x: 7, y: 7))
            context.addLine(to: CGPoint(x: 4, y: 2.5))
            // Back left
            context.move(to: CGPoint(x: 9, y: 7))
            context.addLine(to: CGPoint(x: 6.5, y: 3))

        case 1: // Gathering — legs coming under body
            context.move(to: CGPoint(x: 13, y: 7))
            context.addLine(to: CGPoint(x: 14, y: 3.5))
            context.move(to: CGPoint(x: 11, y: 7))
            context.addLine(to: CGPoint(x: 11, y: 3.5))
            context.move(to: CGPoint(x: 8, y: 7))
            context.addLine(to: CGPoint(x: 7, y: 3.5))
            context.move(to: CGPoint(x: 9.5, y: 7))
            context.addLine(to: CGPoint(x: 9.5, y: 3.5))

        case 2: // Crouch — legs tucked under body
            context.move(to: CGPoint(x: 12, y: 7))
            context.addLine(to: CGPoint(x: 12.5, y: 5))
            context.move(to: CGPoint(x: 10.5, y: 7))
            context.addLine(to: CGPoint(x: 10.5, y: 5))
            context.move(to: CGPoint(x: 8, y: 7))
            context.addLine(to: CGPoint(x: 7.5, y: 5))
            context.move(to: CGPoint(x: 9.5, y: 7))
            context.addLine(to: CGPoint(x: 9.5, y: 5))

        case 3: // Push off — back legs extending, front legs gathering
            context.move(to: CGPoint(x: 13, y: 7))
            context.addLine(to: CGPoint(x: 14, y: 3.5))
            context.move(to: CGPoint(x: 11, y: 7))
            context.addLine(to: CGPoint(x: 12, y: 3.5))
            context.move(to: CGPoint(x: 7, y: 7))
            context.addLine(to: CGPoint(x: 3.5, y: 2))
            context.move(to: CGPoint(x: 9, y: 7))
            context.addLine(to: CGPoint(x: 5.5, y: 2))

        case 4: // Airborne — all legs slightly tucked
            context.move(to: CGPoint(x: 13, y: 7))
            context.addLine(to: CGPoint(x: 14, y: 4.5))
            context.move(to: CGPoint(x: 11, y: 7))
            context.addLine(to: CGPoint(x: 11.5, y: 4.5))
            context.move(to: CGPoint(x: 8, y: 7))
            context.addLine(to: CGPoint(x: 7, y: 4.5))
            context.move(to: CGPoint(x: 9.5, y: 7))
            context.addLine(to: CGPoint(x: 9, y: 4.5))

        case 5: // Landing — front legs reaching forward, back legs under
            context.move(to: CGPoint(x: 14.5, y: 7))
            context.addLine(to: CGPoint(x: 17.5, y: 2.5))
            context.move(to: CGPoint(x: 12.5, y: 7))
            context.addLine(to: CGPoint(x: 15, y: 3))
            context.move(to: CGPoint(x: 7, y: 7))
            context.addLine(to: CGPoint(x: 6.5, y: 3.5))
            context.move(to: CGPoint(x: 9, y: 7))
            context.addLine(to: CGPoint(x: 8.5, y: 3.5))

        default:
            break
        }

        context.strokePath()
    }
}
