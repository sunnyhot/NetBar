import AppKit
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

enum CustomCharacterImageProcessor {
    static let generatedStaticFrameCount = 6

    static func sortedFrameURLs(_ urls: [URL]) -> [URL] {
        urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    static func processedStaticFrames(
        from image: NSImage,
        motionStyle: CustomCharacterMotionStyle,
        pixelation: CustomCharacterPixelationScale
    ) throws -> [NSImage] {
        let source = try normalizedImage(from: image)
        let baseSize = source.size
        let canvasSize = NSSize(width: max(baseSize.width + 4, 1), height: max(baseSize.height + 4, 1))

        let frames = (0..<generatedStaticFrameCount).map { index in
            frame(from: source, canvasSize: canvasSize, motionStyle: motionStyle, index: index)
        }
        return try frames.map { try pixelated($0, scale: pixelation) }
    }

    static func processedFrameSequence(
        from urls: [URL],
        pixelation: CustomCharacterPixelationScale
    ) throws -> [NSImage] {
        let frames = try sortedFrameURLs(urls).compactMap { url -> NSImage? in
            guard let image = NSImage(contentsOf: url) else { return nil }
            return try normalizedImage(from: image)
        }
        guard !frames.isEmpty else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        return try normalizeFrameSizes(frames).map { try pixelated($0, scale: pixelation) }
    }

    static func processedGIFFrames(
        from url: URL,
        pixelation: CustomCharacterPixelationScale,
        maxFrames: Int = 60
    ) throws -> [NSImage] {
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

        let frames = indexes.compactMap { index -> NSImage? in
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return NSImage(cgImage: cgImage, size: size)
        }
        guard !frames.isEmpty else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        return try normalizeFrameSizes(frames).map { try pixelated($0, scale: pixelation) }
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
        }

        let drawSize = NSSize(width: source.size.width * scale, height: source.size.height * scale)
        let drawRect = NSRect(
            x: (canvasSize.width - drawSize.width) / 2 + offset.x,
            y: (canvasSize.height - drawSize.height) / 2 + offset.y,
            width: drawSize.width,
            height: drawSize.height
        )

        return drawImage(size: canvasSize) {
            source.draw(in: drawRect, from: NSRect(origin: .zero, size: source.size), operation: .sourceOver, fraction: alpha)
            if whiteOverlay > 0 {
                NSColor.white.withAlphaComponent(whiteOverlay).setFill()
                NSRect(origin: .zero, size: canvasSize).fill(using: .sourceAtop)
            }
        }
    }

    private static func normalizeFrameSizes(_ frames: [NSImage]) throws -> [NSImage] {
        guard let first = frames.first else { throw CustomCharacterImageProcessorError.emptyFrameSet }
        let size = first.size
        return frames.map { frame in
            drawImage(size: size) {
                frame.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: frame.size), operation: .sourceOver, fraction: 1)
            }
        }
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
}

