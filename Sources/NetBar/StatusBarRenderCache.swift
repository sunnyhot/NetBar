import AppKit

@MainActor
final class StatusBarRenderedImageCache {
    private let limit: Int
    private var entries: [(signature: StatusBarRenderSignature, image: NSImage)] = []

    init(limit: Int = 12) {
        self.limit = max(limit, 1)
    }

    func image(for signature: StatusBarRenderSignature) -> NSImage? {
        guard let index = entries.firstIndex(where: { $0.signature == signature }) else { return nil }
        let entry = entries.remove(at: index)
        entries.append(entry)
        return entry.image
    }

    func store(_ image: NSImage, for signature: StatusBarRenderSignature) {
        entries.removeAll { $0.signature == signature }
        entries.append((signature, image))
        while entries.count > limit {
            entries.removeFirst()
        }
    }

    func removeAll() {
        entries.removeAll()
    }
}

struct StatusBarPreviewRenderOutput {
    let presentation: StatusBarPresentation
    let image: NSImage
}

@MainActor
final class StatusBarPreviewRenderCache {
    typealias ImageFactory = (
        _ snapshot: NetworkSnapshot,
        _ settings: StatusBarSettings,
        _ scale: CGFloat,
        _ customCharacterStore: CustomCharacterStore?,
        _ catFrameIndex: Int?
    ) -> NSImage

    private struct Key: Equatable {
        let signature: StatusBarRenderSignature
        let scaleBucket: Int
    }

    private let limit: Int
    private var entries: [(key: Key, output: StatusBarPreviewRenderOutput)] = []

    init(limit: Int = 36) {
        self.limit = max(limit, 1)
    }

    func render(
        snapshot: NetworkSnapshot,
        settings: StatusBarSettings,
        scale: CGFloat,
        customCharacterStore: CustomCharacterStore? = nil,
        catFrameIndex: Int? = nil,
        appearanceName: String = "NetBarPreview",
        renderTime: TimeInterval = Date().timeIntervalSince1970,
        imageFactory: ImageFactory? = nil
    ) -> StatusBarPreviewRenderOutput {
        let signature = StatusBarDisplayRenderer.signature(
            snapshot: snapshot,
            settings: settings,
            appearanceName: appearanceName,
            customCharacterStore: customCharacterStore,
            catFrameIndex: catFrameIndex,
            renderTime: renderTime,
            reduceMotion: true
        )
        let key = Key(signature: signature, scaleBucket: Int((scale * 100).rounded()))
        if let index = entries.firstIndex(where: { $0.key == key }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.output
        }

        let image: NSImage
        if let imageFactory {
            image = imageFactory(snapshot, settings, scale, customCharacterStore, catFrameIndex)
        } else {
            image = StatusBarDisplayRenderer.image(
                snapshot: snapshot,
                settings: settings,
                scale: scale,
                customCharacterStore: customCharacterStore,
                catFrameIndex: catFrameIndex,
                renderTime: renderTime
            )
        }
        let output = StatusBarPreviewRenderOutput(presentation: signature.presentation, image: image)
        entries.removeAll { $0.key == key }
        entries.append((key, output))
        while entries.count > limit {
            entries.removeFirst()
        }
        return output
    }

    func removeAll() {
        entries.removeAll()
    }
}

struct StatusBarTextLayoutCacheKey: Hashable {
    let lines: [String]
    let fontSize: Double
    let isBold: Bool
    let lineSpacing: Double
    let alignment: StatusBarAlignment
    let showsBackground: Bool
}

struct StatusBarCachedTextLayout: Equatable {
    let width: CGFloat
    let horizontalPadding: CGFloat
    let lines: [String]
}

@MainActor
final class StatusBarTextLayoutCache {
    private let limit: Int
    private var entries: [(key: StatusBarTextLayoutCacheKey, layout: StatusBarCachedTextLayout)] = []

    init(limit: Int = 24) {
        self.limit = max(limit, 1)
    }

    func layout(for key: StatusBarTextLayoutCacheKey) -> StatusBarCachedTextLayout? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        let entry = entries.remove(at: index)
        entries.append(entry)
        return entry.layout
    }

    func store(_ layout: StatusBarCachedTextLayout, for key: StatusBarTextLayoutCacheKey) {
        entries.removeAll { $0.key == key }
        entries.append((key, layout))
        while entries.count > limit {
            entries.removeFirst()
        }
    }
}
