import AppKit
import Combine
import SwiftUI

// MARK: - Menu Bar Group Enum

enum MenuBarPreferenceGroup: String, CaseIterable {
    case preview
    case display
    case character
    case animation
    case layout

    func title(language: AppLanguage) -> String {
        switch self {
        case .preview:
            return language.text("实时预览", "Live Preview")
        case .display:
            return language.text("显示内容", "Display")
        case .character:
            return language.text("角色", "Character")
        case .animation:
            return language.text("动画与轮换", "Animation & Rotation")
        case .layout:
            return language.text("宽度与布局", "Width & Layout")
        }
    }

    var systemImage: String {
        switch self {
        case .preview: return "eye"
        case .display: return "textformat.size"
        case .character: return "pawprint"
        case .animation: return "waveform.path"
        case .layout: return "rectangle.split.3x1"
        }
    }
}

// MARK: - Menu Bar Subsection Header

struct MenuBarSubsectionHeader: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Character Color Mode Picker

struct CharacterColorModePicker: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences

    var body: some View {
        HStack {
            Text(appPreferences.text("颜色模式", "Color Mode"))
                .font(.subheadline)
            Picker("", selection: $settings.catColorMode) {
                ForEach(CatColorMode.allCases) { mode in
                    Text(mode.displayName(zh: appPreferences.resolvedLanguage == .simplifiedChinese))
                        .tag(mode.rawValue)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 220)
            .onChange(of: settings.catColorMode) { newMode in
                if newMode != CatColorMode.solid.rawValue && settings.usesSystemTextColor {
                    settings.usesSystemTextColor = false
                }
            }
        }
    }
}

// MARK: - Character Grid Card

struct CharacterGridCard: View {
    let character: RunCatCharacter
    let isSelected: Bool
    let frameIndex: Int
    let playbackDetail: String?

    var body: some View {
        VStack(spacing: 4) {
            CharacterPickerPreviewIcon(
                character: character,
                frameIndex: frameIndex
            )
            .frame(width: 28, height: 22)

            Text(character.displayName)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let playbackDetail {
                Text(playbackDetail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)
        )
    }
}

// MARK: - Character Choice Label (legacy, kept for custom characters)

struct CharacterChoiceLabel<Icon: View>: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let detail {
                    Text(detail)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: detail == nil ? 26 : 34, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}

// MARK: - Status Bar Preview

struct StatusBarPreview: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    let catFrameIndex: Int?
    @State private var renderCache = StatusBarPreviewRenderCache(limit: 48)

    private let previewSnapshot = NetworkSnapshot(
        timestamp: Date(timeIntervalSince1970: 0),
        interfaces: [],
        downloadBytesPerSecond: 1_280_000,
        uploadBytesPerSecond: 84_000,
        totalReceivedBytes: 0,
        totalSentBytes: 0,
        sampleCount: 1
    )

    var body: some View {
        HStack {
            Spacer()
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            let renderOutput = renderCache.render(
                snapshot: previewSnapshot,
                settings: settings,
                scale: scale,
                customCharacterStore: customCharacterStore,
                catFrameIndex: catFrameIndex,
                appearanceName: NSApp?.effectiveAppearance.name.rawValue ?? appPreferences.appearanceMode.rawValue
            )
            let presentation = renderOutput.presentation

            if presentation.kind == .nativeTitle {
                Text(AttributedString(StatusBarDisplayRenderer.attributedTitle(snapshot: previewSnapshot, settings: settings)))
                    .multilineTextAlignment(textAlignment)
                    .frame(
                        width: presentation.width,
                        height: max(NSStatusBar.system.thickness, 24)
                    )
            } else {
                Image(nsImage: renderOutput.image)
                .frame(
                    width: presentation.width,
                    height: max(NSStatusBar.system.thickness, 24)
                )
            }
            Spacer()
        }
        .frame(height: 56)
        .background(
            ZStack {
                // Grid guidelines background
                Canvas { context, size in
                    let gridColor = Color.primary.opacity(0.04)
                    let gridSpacing: CGFloat = 20
                    var path = Path()
                    var x: CGFloat = gridSpacing
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += gridSpacing
                    }
                    var y: CGFloat = gridSpacing
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += gridSpacing
                    }
                    context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                }
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .underPageBackgroundColor))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        )
    }

    private var textAlignment: TextAlignment {
        switch settings.alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

// MARK: - Menu Bar Settings Summary

struct MenuBarSettingsSummary: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    let characterName: String

    var body: some View {
        HStack(spacing: 8) {
            NetBarBadge(
                text: settings.showsCat ? characterName : appPreferences.text("无角色", "No character"),
                tone: settings.showsCat ? .download : .neutral
            )
            NetBarBadge(
                text: settings.usesAutomaticWidth ? appPreferences.text("自动宽度", "Auto width") : appPreferences.text("手动宽度", "Manual width"),
                tone: .neutral
            )
            NetBarBadge(
                text: settings.showsBackground ? appPreferences.text("背景开启", "Background on") : appPreferences.text("透明背景", "Transparent"),
                tone: settings.showsBackground ? .success : .neutral
            )
            if settings.showsCat {
                NetBarBadge(text: String(format: "%.1fx", settings.catSpeedMultiplier), tone: .upload)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Color Swatch (circular preset color)

struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isSelected ? 2.5 : 0.5)
            )
            .onTapGesture { onTap() }
    }
}

// MARK: - Character Picker Preview Icon

struct CharacterPickerPreviewIcon: View {
    let character: RunCatCharacter
    let frameIndex: Int

    private static let imageCache = NSCache<NSString, NSImage>()

    static func contrastShadowOpacity(for character: RunCatCharacter) -> Double {
        character.isTemplate ? 0 : 0.32
    }

    private static func contrastShadowRadius(for character: RunCatCharacter) -> CGFloat {
        character.isTemplate ? 0 : 0.7
    }

    var body: some View {
        Group {
            if let image = Self.cachedImage(for: character, frameIndex: frameIndex) {
                Image(nsImage: image)
                    .renderingMode(character.isTemplate ? .template : .original)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: character.isGooglyEyes ? "eye" : "questionmark.square.dashed")
                    .symbolRenderingMode(.hierarchical)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .foregroundStyle(.primary)
        .shadow(
            color: Color.primary.opacity(Self.contrastShadowOpacity(for: character)),
            radius: Self.contrastShadowRadius(for: character),
            x: 0,
            y: 0
        )
        .frame(width: 24, height: 18)
        .accessibilityHidden(true)
    }

    private static func cachedImage(for character: RunCatCharacter, frameIndex: Int) -> NSImage? {
        let safeFrameIndex = frameIndex % max(character.frameCount, 1)
        let cacheKey = "\(character.id)_\(safeFrameIndex)" as NSString

        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        let image = loadFromDisk(character: character, frameIndex: safeFrameIndex)
        if let image {
            imageCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    private static func loadFromDisk(character: RunCatCharacter, frameIndex: Int) -> NSImage? {
        let resourcePath = "RunCat/\(character.id)"
        if let url = Bundle.main.url(
            forResource: "frame_\(frameIndex)",
            withExtension: "png",
            subdirectory: resourcePath
        ) {
            return NSImage(contentsOf: url)
        }
        if let resourcePath = Bundle.main.resourcePath {
            let bundledURL = URL(fileURLWithPath: "\(resourcePath)/RunCat/\(character.id)/frame_\(frameIndex).png")
            if let image = NSImage(contentsOf: bundledURL) {
                return image
            }
        }
        let sourceTreeURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("RunCat")
            .appendingPathComponent(character.id)
            .appendingPathComponent("frame_\(frameIndex).png")
        if FileManager.default.fileExists(atPath: sourceTreeURL.path) {
            return NSImage(contentsOf: sourceTreeURL)
        }
        return nil
    }
}

// MARK: - Animated Preview Section

struct AnimatedPreviewSection: View {
    @ObservedObject var settings: StatusBarSettings
    @ObservedObject var appPreferences: AppPreferences
    @ObservedObject var customCharacterStore: CustomCharacterStore
    let selectedCharacterAsset: CharacterAsset

    @State private var previewFrameTimeline = CharacterPreviewFrameTimeline()

    private static let previewFrameInterval: TimeInterval = 1.0 / 8.0

    private var selectedPreviewFrameIndex: Int? {
        guard settings.showsCat else { return nil }
        return previewFrameTimeline.frameIndex(for: selectedCharacterAsset)
    }

    var body: some View {
        PreferenceSection(title: MenuBarPreferenceGroup.preview.title(language: appPreferences.resolvedLanguage)) {
            StatusBarPreview(
                settings: settings,
                appPreferences: appPreferences,
                customCharacterStore: customCharacterStore,
                catFrameIndex: selectedPreviewFrameIndex
            )

            MenuBarSettingsSummary(
                settings: settings,
                appPreferences: appPreferences,
                characterName: selectedCharacterAsset.displayName
            )
        }
        .onReceive(Timer.publish(every: Self.previewFrameInterval, on: .main, in: .common).autoconnect()) { _ in
            guard settings.showsCat else {
                previewFrameTimeline.reset()
                return
            }
            previewFrameTimeline.advance(for: selectedCharacterAsset)
        }
    }
}

// MARK: - Animated Character Catalog

struct AnimatedCharacterCatalog: View {
    @ObservedObject var settings: StatusBarSettings
    let characterPickerFrameTick: Int?
    let playbackCounts: [String: UInt64]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(RunCatCharacter.Category.allCases, id: \.rawValue) { category in
                VStack(alignment: .leading, spacing: 5) {
                    Text(category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)

                    let charsInCategory = RunCatCharacter.allCharacters.filter { $0.category == category }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 6) {
                        ForEach(charsInCategory) { character in
                            Button(action: {
                                settings.catCharacter = character.id
                            }) {
                                CharacterGridCard(
                                    character: character,
                                    isSelected: settings.catCharacter == character.id,
                                    frameIndex: characterPickerFrameTick ?? 0,
                                    playbackDetail: CharacterPlaybackPresentation.totalPlayCountText(
                                        playbackCounts[character.id] ?? 0,
                                        language: language
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
