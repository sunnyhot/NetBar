import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent("Resources/AppIcon.iconset")
let icnsURL = rootURL.appendingPathComponent("Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconOutput {
    let name: String
    let pixels: CGFloat
}

let outputs: [IconOutput] = [
    IconOutput(name: "icon_16x16.png", pixels: 16),
    IconOutput(name: "icon_16x16@2x.png", pixels: 32),
    IconOutput(name: "icon_32x32.png", pixels: 32),
    IconOutput(name: "icon_32x32@2x.png", pixels: 64),
    IconOutput(name: "icon_128x128.png", pixels: 128),
    IconOutput(name: "icon_128x128@2x.png", pixels: 256),
    IconOutput(name: "icon_256x256.png", pixels: 256),
    IconOutput(name: "icon_256x256@2x.png", pixels: 512),
    IconOutput(name: "icon_512x512.png", pixels: 512),
    IconOutput(name: "icon_512x512@2x.png", pixels: 1024)
]

for output in outputs {
    let image = drawIcon(size: output.pixels)
    let destination = iconsetURL.appendingPathComponent(output.name)
    try writePNG(image, to: destination)
}

try? FileManager.default.removeItem(at: icnsURL)
try writeICNS(from: iconsetURL, to: icnsURL)

print(icnsURL.path)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let inset = size * 0.055
    let tile = rect.insetBy(dx: inset, dy: inset)
    let radius = size * 0.21
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.24, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.34, green: 0.34, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.12, alpha: 1)
    ])!
    gradient.draw(in: tilePath, angle: -35)

    NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
    tilePath.lineWidth = max(1, size * 0.012)
    tilePath.stroke()

    drawSoftCircle(
        center: CGPoint(x: size * 0.33, y: size * 0.68),
        radius: size * 0.34,
        color: NSColor(calibratedRed: 0.11, green: 0.48, blue: 1.0, alpha: 0.24)
    )
    drawSoftCircle(
        center: CGPoint(x: size * 0.72, y: size * 0.34),
        radius: size * 0.30,
        color: NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.15, alpha: 0.20)
    )

    let panel = NSRect(
        x: size * 0.20,
        y: size * 0.18,
        width: size * 0.60,
        height: size * 0.64
    )
    let panelPath = NSBezierPath(
        roundedRect: panel,
        xRadius: size * 0.11,
        yRadius: size * 0.11
    )
    NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
    panelPath.fill()

    drawArrow(
        direction: .up,
        center: CGPoint(x: size * 0.50, y: size * 0.62),
        size: size * 0.22,
        color: NSColor.white
    )
    drawArrow(
        direction: .down,
        center: CGPoint(x: size * 0.50, y: size * 0.38),
        size: size * 0.22,
        color: NSColor.white
    )

    NSColor(calibratedWhite: 1, alpha: 0.32).setStroke()
    let separator = NSBezierPath()
    separator.move(to: CGPoint(x: size * 0.33, y: size * 0.50))
    separator.line(to: CGPoint(x: size * 0.67, y: size * 0.50))
    separator.lineWidth = max(1, size * 0.012)
    separator.stroke()

    drawTrafficStroke(
        points: [
            CGPoint(x: size * 0.18, y: size * 0.33),
            CGPoint(x: size * 0.30, y: size * 0.27),
            CGPoint(x: size * 0.42, y: size * 0.31),
            CGPoint(x: size * 0.54, y: size * 0.24),
            CGPoint(x: size * 0.70, y: size * 0.30),
            CGPoint(x: size * 0.84, y: size * 0.26)
        ],
        color: NSColor(calibratedRed: 0.16, green: 0.58, blue: 1.0, alpha: 0.95),
        size: size
    )
    drawTrafficStroke(
        points: [
            CGPoint(x: size * 0.16, y: size * 0.75),
            CGPoint(x: size * 0.30, y: size * 0.70),
            CGPoint(x: size * 0.45, y: size * 0.76),
            CGPoint(x: size * 0.58, y: size * 0.68),
            CGPoint(x: size * 0.72, y: size * 0.74),
            CGPoint(x: size * 0.84, y: size * 0.70)
        ],
        color: NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.22, alpha: 0.92),
        size: size
    )

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "NetBarIcon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode PNG"
        ])
    }

    try pngData.write(to: url)
}

func drawSoftCircle(center: CGPoint, radius: CGFloat, color: NSColor) {
    let rect = NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    let gradient = NSGradient(colors: [
        color,
        color.withAlphaComponent(0)
    ])!
    gradient.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: NSPoint(x: 0, y: 0))
}

enum ArrowDirection {
    case up
    case down
}

func drawArrow(direction: ArrowDirection, center: CGPoint, size: CGFloat, color: NSColor) {
    let shaftWidth = size * 0.22
    let shaftHeight = size * 0.68
    let headWidth = size * 0.72
    let path = NSBezierPath()

    switch direction {
    case .up:
        path.move(to: CGPoint(x: center.x, y: center.y + size * 0.50))
        path.line(to: CGPoint(x: center.x - headWidth / 2, y: center.y + size * 0.08))
        path.line(to: CGPoint(x: center.x - shaftWidth / 2, y: center.y + size * 0.08))
        path.line(to: CGPoint(x: center.x - shaftWidth / 2, y: center.y - shaftHeight / 2))
        path.line(to: CGPoint(x: center.x + shaftWidth / 2, y: center.y - shaftHeight / 2))
        path.line(to: CGPoint(x: center.x + shaftWidth / 2, y: center.y + size * 0.08))
        path.line(to: CGPoint(x: center.x + headWidth / 2, y: center.y + size * 0.08))
    case .down:
        path.move(to: CGPoint(x: center.x, y: center.y - size * 0.50))
        path.line(to: CGPoint(x: center.x - headWidth / 2, y: center.y - size * 0.08))
        path.line(to: CGPoint(x: center.x - shaftWidth / 2, y: center.y - size * 0.08))
        path.line(to: CGPoint(x: center.x - shaftWidth / 2, y: center.y + shaftHeight / 2))
        path.line(to: CGPoint(x: center.x + shaftWidth / 2, y: center.y + shaftHeight / 2))
        path.line(to: CGPoint(x: center.x + shaftWidth / 2, y: center.y - size * 0.08))
        path.line(to: CGPoint(x: center.x + headWidth / 2, y: center.y - size * 0.08))
    }

    path.close()
    color.setFill()
    path.fill()
}

func drawTrafficStroke(points: [CGPoint], color: NSColor, size: CGFloat) {
    guard let first = points.first else { return }

    let path = NSBezierPath()
    path.move(to: first)
    for point in points.dropFirst() {
        path.line(to: point)
    }

    color.setStroke()
    path.lineWidth = max(1.5, size * 0.018)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func writeICNS(from iconsetURL: URL, to destinationURL: URL) throws {
    let entries: [(type: String, file: String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    var chunks: [(type: String, data: Data)] = []
    for entry in entries {
        let url = iconsetURL.appendingPathComponent(entry.file)
        chunks.append((entry.type, try Data(contentsOf: url)))
    }

    let totalLength = 8 + chunks.reduce(0) { partial, chunk in
        partial + 8 + chunk.data.count
    }

    var data = Data()
    data.append(contentsOf: Array("icns".utf8))
    data.appendUInt32(UInt32(totalLength))

    for chunk in chunks {
        data.append(contentsOf: Array(chunk.type.utf8))
        data.appendUInt32(UInt32(8 + chunk.data.count))
        data.append(chunk.data)
    }

    try data.write(to: destinationURL)
}

extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }
}
