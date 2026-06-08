import AppKit
import CommonCrypto
import Foundation
import ImageIO

enum CustomCharacterImageProcessorError: LocalizedError {
    case unreadableImage(URL)
    case emptyFrameSet
    case cannotEncodePNG

    var errorDescription: String? {
        switch self {
        case .unreadableImage(let url):
            return "Unable to read image at \(url.path)"
        case .emptyFrameSet:
            return "No readable image frames were found."
        case .cannotEncodePNG:
            return "Unable to encode image as PNG."
        }
    }
}

struct GIFExtractionProgress: Sendable {
    let current: Int
    let total: Int
}

enum CustomCharacterImageProcessor {
    static let generatedStaticFrameCount = 8

    private static let cacheDirectory: URL = {
        let tmp = FileManager.default.temporaryDirectory
        return tmp.appendingPathComponent("NetBar_ProcessedFramesCache", isDirectory: true)
    }()

    static func sortedFrameURLs(_ urls: [URL]) -> [URL] {
        urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    static func processedStaticFrames(
        from image: NSImage,
        motionStyle: CustomCharacterMotionStyle,
        pixelation: CustomCharacterPixelationScale
    ) async throws -> [NSImage] {
        let source = try normalizedImage(from: image)
        let baseSize = source.size
        let canvasPadding = canvasPadding(for: motionStyle)
        let canvasSize = NSSize(
            width: max(baseSize.width + canvasPadding.width, 1),
            height: max(baseSize.height + canvasPadding.height, 1)
        )

        let rawFrames = (0..<generatedStaticFrameCount).map { index in
            frame(from: source, canvasSize: canvasSize, motionStyle: motionStyle, index: index)
        }
        return try await pixelatedFramesPreservingOrder(rawFrames, pixelation: pixelation)
    }

    static func processedFrameSequence(
        from urls: [URL],
        pixelation: CustomCharacterPixelationScale
    ) async throws -> [NSImage] {
        let frames = try sortedFrameURLs(urls).compactMap { url -> NSImage? in
            guard let image = NSImage(contentsOf: url) else { return nil }
            return try normalizedImage(from: image)
        }
        guard !frames.isEmpty else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        let normalized = try normalizeFrameSizes(frames)
        return try await pixelatedFramesPreservingOrder(normalized, pixelation: pixelation)
    }

    static func processedGIFFrames(
        from url: URL,
        pixelation: CustomCharacterPixelationScale,
        maxFrames: Int = 60,
        onProgress: ((GIFExtractionProgress) -> Void)? = nil
    ) async throws -> [NSImage] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CustomCharacterImageProcessorError.unreadableImage(url)
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        let cappedCount = max(min(maxFrames, count), 1)
        let indexes: [Int]
        if count <= cappedCount {
            indexes = Array(0..<count)
        } else {
            indexes = (0..<cappedCount).map { Int((Double($0) / Double(cappedCount)) * Double(count)) }
        }

        var rawFrames: [NSImage] = []
        rawFrames.reserveCapacity(indexes.count)
        for (i, index) in indexes.enumerated() {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            rawFrames.append(NSImage(cgImage: cgImage, size: size))
            onProgress?(GIFExtractionProgress(current: i + 1, total: indexes.count))
        }
        guard !rawFrames.isEmpty else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        let normalized = try normalizeFrameSizes(rawFrames)
        return try await pixelatedFramesPreservingOrder(normalized, pixelation: pixelation)
    }

    // MARK: - Persistent Cache

    static func cacheKey(data: Data, pixelation: CustomCharacterPixelationScale) -> String {
        var hasher = HashContext()
        hasher.update(data: data)
        hasher.update(data: withUnsafeBytes(of: pixelation.rawValue) { Data($0) })
        return hasher.finalize()
    }

    static func cachedFrames(for key: String) -> [NSImage]? {
        let dir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
              !files.isEmpty else { return nil }
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { NSImage(contentsOf: $0) }
    }

    static func storeFramesInCache(_ frames: [NSImage], key: String) {
        let dir = cacheDirectory.appendingPathComponent(key, isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, frame) in frames.enumerated() {
            guard let data = try? pngData(for: frame) else { continue }
            try? data.write(to: dir.appendingPathComponent("frame_\(i).png"))
        }
    }

    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    static func pixelated(_ image: NSImage, scale: CustomCharacterPixelationScale) throws -> NSImage {
        let source = try bitmapRepresentation(from: image)
        guard scale != .off else {
            return imageFromBitmap(source)
        }

        let blockSize = max(scale.rawValue, 1)
        guard let output = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: source.pixelsWide,
            pixelsHigh: source.pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw CustomCharacterImageProcessorError.cannotEncodePNG
        }
        output.size = source.size

        for y in stride(from: 0, to: source.pixelsHigh, by: blockSize) {
            for x in stride(from: 0, to: source.pixelsWide, by: blockSize) {
                let color = averageColor(in: source, x: x, y: y, blockSize: blockSize)
                for blockY in y..<min(y + blockSize, source.pixelsHigh) {
                    for blockX in x..<min(x + blockSize, source.pixelsWide) {
                        output.setColor(color, atX: blockX, y: blockY)
                    }
                }
            }
        }

        return imageFromBitmap(output)
    }

    static func writePNGFrames(_ frames: [NSImage], to directory: URL) throws -> (frameWidth: Int, frameHeight: Int) {
        guard let first = frames.first else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let existingFrames = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in existingFrames where url.lastPathComponent.hasPrefix("frame_") && url.pathExtension.lowercased() == "png" {
            try FileManager.default.removeItem(at: url)
        }

        for (index, frame) in frames.enumerated() {
            try pngData(for: frame).write(to: directory.appendingPathComponent("frame_\(index).png"))
        }

        return (
            frameWidth: max(Int(ceil(first.size.width)), 1),
            frameHeight: max(Int(ceil(first.size.height)), 1)
        )
    }

    static func pngData(for image: NSImage) throws -> Data {
        let bitmap = try bitmapRepresentation(from: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CustomCharacterImageProcessorError.cannotEncodePNG
        }
        return data
    }

    private static func frame(
        from source: NSImage,
        canvasSize: NSSize,
        motionStyle: CustomCharacterMotionStyle,
        index: Int
    ) -> NSImage {
        let progress = CGFloat(index) / CGFloat(generatedStaticFrameCount)
        var scale: CGFloat = 1
        var offset = CGPoint.zero
        var alpha: CGFloat = 1
        var whiteOverlay: CGFloat = 0
        var rotationDegrees: CGFloat = 0
        var sparkles: [CGPoint] = []

        switch motionStyle {
        case .bounceBreathe:
            scale = 0.96 + 0.06 * (0.5 + 0.5 * sin(progress * .pi * 2))
            offset.y = 1.5 * sin(progress * .pi * 2)
        case .swayRun:
            offset.x = 2.0 * sin(progress * .pi * 2)
            offset.y = 0.7 * abs(sin(progress * .pi * 2))
        case .pixelJitterFlicker:
            let jitter: [CGPoint] = [
                CGPoint(x: -1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: -1),
                CGPoint(x: 1, y: 0),
                CGPoint(x: -1, y: -1),
                CGPoint(x: 0, y: 1)
            ]
            offset = jitter[index % jitter.count]
            alpha = index % 2 == 0 ? 0.92 : 1
            whiteOverlay = index % 3 == 0 ? 0.08 : 0
        case .materialize:
            let reveal = min(progress * 1.8, 1)
            alpha = 0.18 + 0.82 * reveal
            scale = 0.72 + 0.32 * reveal + 0.03 * sin(progress * .pi * 2)
            offset.y = -2.0 + 2.0 * reveal
            whiteOverlay = index <= 2 ? 0.14 - CGFloat(index) * 0.04 : 0
            sparkles = sparklePoints(for: index, count: 3, radius: 0.42)
        case .flight:
            offset.x = -2.8 * cos(progress * .pi * 2)
            offset.y = 3.2 * sin(progress * .pi * 2)
            rotationDegrees = -10 * sin(progress * .pi * 2)
            scale = 0.98 + 0.04 * sin(progress * .pi * 4)
        case .sparkleFlash:
            let flash = index % 4 == 0
            alpha = flash ? 0.82 : 1
            scale = flash ? 1.08 : 0.98 + 0.02 * sin(progress * .pi * 2)
            whiteOverlay = flash ? 0.24 : 0.04
            sparkles = sparklePoints(for: index, count: 5, radius: 0.48)
        case .heartbeat:
            let beat = [1.0, 1.12, 0.96, 1.06, 1.0, 1.08, 0.98, 1.0]
            scale = CGFloat(beat[index % beat.count])
            offset.y = scale > 1.05 ? 0.8 : 0
            whiteOverlay = scale > 1.08 ? 0.06 : 0
        case .orbitFloat:
            offset.x = 2.4 * cos(progress * .pi * 2)
            offset.y = 2.0 * sin(progress * .pi * 2)
            rotationDegrees = 7 * sin(progress * .pi * 2)
            scale = 0.98 + 0.04 * (0.5 + 0.5 * cos(progress * .pi * 2))
        }

        let drawSize = NSSize(width: source.size.width * scale, height: source.size.height * scale)
        let drawRect = NSRect(
            x: (canvasSize.width - drawSize.width) / 2 + offset.x,
            y: (canvasSize.height - drawSize.height) / 2 + offset.y,
            width: drawSize.width,
            height: drawSize.height
        )

        return drawImage(size: canvasSize) {
            draw(source, in: drawRect, rotationDegrees: rotationDegrees, alpha: alpha)
            if whiteOverlay > 0 {
                NSColor.white.withAlphaComponent(whiteOverlay).setFill()
                NSRect(origin: .zero, size: canvasSize).fill(using: .sourceAtop)
            }
            drawSparkles(sparkles, in: canvasSize, alpha: max(alpha, 0.45))
        }
    }

    private static func canvasPadding(for motionStyle: CustomCharacterMotionStyle) -> NSSize {
        switch motionStyle {
        case .bounceBreathe, .swayRun, .pixelJitterFlicker:
            return NSSize(width: 4, height: 4)
        case .materialize, .heartbeat, .sparkleFlash:
            return NSSize(width: 8, height: 8)
        case .flight, .orbitFloat:
            return NSSize(width: 10, height: 10)
        }
    }

    private static func draw(
        _ source: NSImage,
        in drawRect: NSRect,
        rotationDegrees: CGFloat,
        alpha: CGFloat
    ) {
        NSGraphicsContext.saveGraphicsState()
        if rotationDegrees != 0 {
            let transform = NSAffineTransform()
            transform.translateX(by: drawRect.midX, yBy: drawRect.midY)
            transform.rotate(byDegrees: rotationDegrees)
            transform.translateX(by: -drawRect.midX, yBy: -drawRect.midY)
            transform.concat()
        }
        source.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver,
            fraction: alpha
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func sparklePoints(for index: Int, count: Int, radius: CGFloat) -> [CGPoint] {
        (0..<count).map { sparkleIndex in
            let angle = (CGFloat(index + sparkleIndex * 2) / CGFloat(generatedStaticFrameCount)) * .pi * 2
            let distance = radius + CGFloat(sparkleIndex % 2) * 0.08
            return CGPoint(
                x: 0.5 + cos(angle) * distance,
                y: 0.5 + sin(angle) * distance * 0.78
            )
        }
    }

    private static func drawSparkles(_ points: [CGPoint], in canvasSize: NSSize, alpha: CGFloat) {
        guard !points.isEmpty else { return }
        for (index, point) in points.enumerated() {
            let center = CGPoint(x: point.x * canvasSize.width, y: point.y * canvasSize.height)
            let length = CGFloat(1.7 + Double(index % 2) * 0.8)
            let path = NSBezierPath()
            path.move(to: CGPoint(x: center.x - length, y: center.y))
            path.line(to: CGPoint(x: center.x + length, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - length))
            path.line(to: CGPoint(x: center.x, y: center.y + length))
            path.lineWidth = 0.9
            path.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.55 * alpha).setStroke()
            path.stroke()
        }
    }

    private static func normalizeFrameSizes(_ frames: [NSImage]) throws -> [NSImage] {
        guard let first = frames.first else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        let size = first.size
        return frames.map { frame in
            drawImage(size: size) {
                frame.draw(
                    in: aspectFitRect(contentSize: frame.size, canvasSize: size),
                    from: NSRect(origin: .zero, size: frame.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }
    }

    private static func aspectFitRect(contentSize: NSSize, canvasSize: NSSize) -> NSRect {
        guard contentSize.width > 0, contentSize.height > 0 else {
            return NSRect(origin: .zero, size: canvasSize)
        }
        let scale = min(canvasSize.width / contentSize.width, canvasSize.height / contentSize.height)
        let fittedSize = NSSize(width: contentSize.width * scale, height: contentSize.height * scale)
        return NSRect(
            x: (canvasSize.width - fittedSize.width) / 2,
            y: (canvasSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private static func normalizedImage(from image: NSImage) throws -> NSImage {
        let size = NSSize(width: max(ceil(image.size.width), 1), height: max(ceil(image.size.height), 1))
        return drawImage(size: size) {
            image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
        }
    }

    private static func drawImage(size: NSSize, draw: () -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        draw()
        image.unlockFocus()
        return image
    }

    private static func bitmapRepresentation(from image: NSImage) throws -> NSBitmapImageRep {
        let width = max(Int(ceil(image.size.width)), 1)
        let height = max(Int(ceil(image.size.height)), 1)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw CustomCharacterImageProcessorError.cannotEncodePNG
        }

        bitmap.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private static func imageFromBitmap(_ bitmap: NSBitmapImageRep) -> NSImage {
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    private static func averageColor(in bitmap: NSBitmapImageRep, x: Int, y: Int, blockSize: Int) -> NSColor {
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero
        var count = CGFloat.zero

        for blockY in y..<min(y + blockSize, bitmap.pixelsHigh) {
            for blockX in x..<min(x + blockSize, bitmap.pixelsWide) {
                guard let color = bitmap.colorAt(x: blockX, y: blockY)?.usingColorSpace(.deviceRGB) else { continue }
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                alpha += color.alphaComponent
                count += 1
            }
        }

        guard count > 0 else { return .clear }
        return NSColor(
            calibratedRed: red / count,
            green: green / count,
            blue: blue / count,
            alpha: alpha / count
        )
    }

    private static func pixelatedFramesPreservingOrder(
        _ frames: [NSImage],
        pixelation: CustomCharacterPixelationScale
    ) async throws -> [NSImage] {
        try await withThrowingTaskGroup(of: (Int, NSImage).self) { group in
            for (index, frame) in frames.enumerated() {
                group.addTask {
                    (index, try await self.pixelatedAsync(frame, scale: pixelation))
                }
            }

            var results = frames
            for try await (index, image) in group {
                results[index] = image
            }
            return results
        }
    }

    private static func pixelatedAsync(_ image: NSImage, scale: CustomCharacterPixelationScale) async throws -> NSImage {
        try await Task.detached(priority: .utility) {
            try pixelated(image, scale: scale)
        }.value
    }
}

private struct HashContext {
    private var context: CC_SHA256_CTX

    init() {
        context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
    }

    mutating func update(data: Data) {
        data.withUnsafeBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                CC_SHA256_Update(&context, baseAddress, CC_LONG(data.count))
            }
        }
    }

    func finalize() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        var localContext = context
        CC_SHA256_Final(&digest, &localContext)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
