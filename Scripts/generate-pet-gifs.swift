import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 从 Resources/RunCat/<id>/frame_N.png 合成 README 展示用的角色 GIF（docs/images/pets/）。
// 用法（在仓库根目录执行）：
//   swift Scripts/generate-pet-gifs.swift              # 重新生成 README 画廊的角色
//   swift Scripts/generate-pet-gifs.swift sushi cat     # 只生成指定角色

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = rootURL.appendingPathComponent("docs/images/pets")

// README 小宠物画廊展示的角色，调整后需同步更新 README 中的引用。
let showcaseIDs = [
    "cat",
    "party-parrot",
    "mock_nyan_cat",
    "shiba_inu",
    "golden_cat",
    "maneki_neko",
]

let characterIDs = CommandLine.arguments.count > 1
    ? Array(CommandLine.arguments.dropFirst())
    : showcaseIDs

let frameScale = 3
let frameDelay: Double = 0.125
let cardPadding = 14.0
let cardCornerRadius = 12.0
let cardBackgroundColor = CGColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1)  // #f2f3f5

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

for characterID in characterIDs {
    let framesDirectory = rootURL.appendingPathComponent("Resources/RunCat/\(characterID)")
    guard let frameFiles = try? FileManager.default.contentsOfDirectory(at: framesDirectory, includingPropertiesForKeys: nil),
        !frameFiles.isEmpty else {
        print("跳过 \(characterID)：找不到 Resources/RunCat/\(characterID)")
        continue
    }

    let frameImages = frameFiles
        .filter { $0.pathExtension == "png" && $0.lastPathComponent.hasPrefix("frame_") }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        .compactMap { url -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
    guard let first = frameImages.first else {
        print("跳过 \(characterID)：没有 frame_*.png")
        continue
    }

    let canvasWidth = Int((Double(first.width * frameScale) + cardPadding * 2).rounded())
    let canvasHeight = Int((Double(first.height * frameScale) + cardPadding * 2).rounded())

    let destinationURL = outputURL.appendingPathComponent("\(characterID).gif")
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.gif.identifier as CFString, frameImages.count, nil) else {
        print("跳过 \(characterID)：无法创建 \(destinationURL.path)")
        continue
    }
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFLoopCount: 0] as CFDictionary)

    let frameProperties = [kCGImagePropertyGIFDelayTime: frameDelay] as CFDictionary
    for frame in frameImages {
        CGImageDestinationAddImage(destination, renderCardCanvas(frame), frameProperties)
    }
    guard CGImageDestinationFinalize(destination) else {
        print("跳过 \(characterID)：GIF 编码失败")
        continue
    }
    print("\(characterID): \(frameImages.count) 帧 -> \(destinationURL.path) (\(canvasWidth)x\(canvasHeight))")
}

func renderCardCanvas(_ frame: CGImage) -> CGImage {
    let canvasWidth = Int((Double(frame.width * frameScale) + cardPadding * 2).rounded())
    let canvasHeight = Int((Double(frame.height * frameScale) + cardPadding * 2).rounded())
    let context = CGContext(
        data: nil,
        width: canvasWidth,
        height: canvasHeight,
        bitsPerComponent: 8,
        bytesPerRow: canvasWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let cardRect = CGRect(x: 0, y: 0, width: CGFloat(canvasWidth), height: CGFloat(canvasHeight))
    context.addPath(CGPath(roundedRect: cardRect, cornerWidth: cardCornerRadius, cornerHeight: cardCornerRadius, transform: nil))
    context.setFillColor(cardBackgroundColor)
    context.fillPath()

    context.interpolationQuality = .none
    let frameWidth = CGFloat(frame.width * frameScale)
    let frameHeight = CGFloat(frame.height * frameScale)
    let frameRect = CGRect(
        x: (CGFloat(canvasWidth) - frameWidth) / 2,
        y: (CGFloat(canvasHeight) - frameHeight) / 2,
        width: frameWidth,
        height: frameHeight
    )
    context.draw(frame, in: frameRect)
    return context.makeImage()!
}
