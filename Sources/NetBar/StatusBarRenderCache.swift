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
