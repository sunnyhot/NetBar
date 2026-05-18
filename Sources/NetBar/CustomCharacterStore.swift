import AppKit
import Foundation

enum CustomCharacterStoreError: LocalizedError {
    case missingCharacter(String)
    case missingOriginalSource(String)
    case unsupportedImportSelection

    var errorDescription: String? {
        switch self {
        case .missingCharacter(let id):
            return "Custom character \(id) was not found."
        case .missingOriginalSource(let id):
            return "Original source for \(id) was not found."
        case .unsupportedImportSelection:
            return "The selected files cannot be imported as a character."
        }
    }
}

enum CharacterProcessingState: Equatable, Sendable {
    case ready
    case loading
    case error(String)
}

@MainActor
final class CustomCharacterStore: ObservableObject {
    @Published private(set) var characters: [CustomCharacter] = []
    @Published private(set) var processingStates: [String: CharacterProcessingState] = [:]
    private(set) var revision = 0

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let now: () -> Date

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
        self.fileManager = fileManager
        self.now = now
        loadManifest()
    }

    static func defaultRootDirectory(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupport
            .appendingPathComponent("NetBar", isDirectory: true)
            .appendingPathComponent("CustomCharacters", isDirectory: true)
    }

    func character(id: String) -> CustomCharacter? {
        characters.first { $0.id == id }
    }

    func validCharacterID(for selectedID: String) -> String {
        if selectedID.hasPrefix("custom.") {
            return character(id: selectedID) == nil ? RunCatCharacter.defaultCat.id : selectedID
        }
        return RunCatCharacter.allCharacters.contains { $0.id == selectedID }
            ? selectedID
            : RunCatCharacter.defaultCat.id
    }

    func characterDirectory(for character: CustomCharacter) -> URL {
        rootDirectory.appendingPathComponent(character.id, isDirectory: true)
    }

    func frameURL(for character: CustomCharacter, frameIndex: Int) -> URL {
        let safeIndex = max(frameIndex, 0) % character.sanitizedFrameCount
        return characterDirectory(for: character).appendingPathComponent("frame_\(safeIndex).png")
    }

    func importSelection(
        _ selection: CustomCharacterImportSelection,
        displayName: String,
        motionStyle: CustomCharacterMotionStyle = .bounceBreathe,
        pixelationScale: CustomCharacterPixelationScale = .off
    ) async throws -> CustomCharacter {
        switch selection.sourceKind {
        case .staticImage:
            guard let url = selection.urls.first else { throw CustomCharacterStoreError.unsupportedImportSelection }
            return try await importStaticImage(
                from: url,
                displayName: displayName,
                motionStyle: motionStyle,
                pixelationScale: pixelationScale
            )
        case .gif:
            guard let url = selection.urls.first else { throw CustomCharacterStoreError.unsupportedImportSelection }
            return try await importGIF(from: url, displayName: displayName, pixelationScale: pixelationScale)
        case .frameSequence:
            return try await importFrameSequence(from: selection.urls, displayName: displayName, pixelationScale: pixelationScale)
        }
    }

    func importStaticImage(
        from sourceURL: URL,
        displayName: String,
        motionStyle: CustomCharacterMotionStyle,
        pixelationScale: CustomCharacterPixelationScale
    ) async throws -> CustomCharacter {
        guard let sourceImage = NSImage(contentsOf: sourceURL) else {
            throw CustomCharacterImageProcessorError.unreadableImage(sourceURL)
        }

        let id = makeID()
        processingStates[id] = .loading
        let directory = rootDirectory.appendingPathComponent(id, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try copyReplacing(sourceURL, to: originalURL(in: directory, extension: sourceURL.pathExtension))

        let cacheKey = cacheKeyForStaticImage(sourceURL: sourceURL, motionStyle: motionStyle, pixelation: pixelationScale)
        let frames: [NSImage]
        if let cached = CustomCharacterImageProcessor.cachedFrames(for: cacheKey) {
            frames = cached
        } else {
            frames = try await CustomCharacterImageProcessor.processedStaticFrames(
                from: sourceImage,
                motionStyle: motionStyle,
                pixelation: pixelationScale
            )
            CustomCharacterImageProcessor.storeFramesInCache(frames, key: cacheKey)
        }
        let dimensions = try CustomCharacterImageProcessor.writePNGFrames(frames, to: directory)
        let date = now()
        let character = CustomCharacter(
            id: id,
            displayName: sanitizedDisplayName(displayName, fallback: sourceURL.deletingPathExtension().lastPathComponent),
            sourceKind: .staticImage,
            frameCount: frames.count,
            frameWidth: dimensions.frameWidth,
            frameHeight: dimensions.frameHeight,
            motionStyle: motionStyle,
            pixelationScale: pixelationScale,
            createdAt: date,
            updatedAt: date
        )
        characters.append(character)
        try saveManifest()
        processingStates[id] = .ready
        return character
    }

    func importGIF(
        from sourceURL: URL,
        displayName: String,
        pixelationScale: CustomCharacterPixelationScale
    ) async throws -> CustomCharacter {
        let id = makeID()
        processingStates[id] = .loading
        let directory = rootDirectory.appendingPathComponent(id, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try copyReplacing(sourceURL, to: originalURL(in: directory, extension: "gif"))

        let cacheKey = cacheKeyForGIF(sourceURL: sourceURL, pixelation: pixelationScale)
        let frames: [NSImage]
        if let cached = CustomCharacterImageProcessor.cachedFrames(for: cacheKey) {
            frames = cached
        } else {
            frames = try await CustomCharacterImageProcessor.processedGIFFrames(from: sourceURL, pixelation: pixelationScale)
            CustomCharacterImageProcessor.storeFramesInCache(frames, key: cacheKey)
        }
        let dimensions = try CustomCharacterImageProcessor.writePNGFrames(frames, to: directory)
        let date = now()
        let character = CustomCharacter(
            id: id,
            displayName: sanitizedDisplayName(displayName, fallback: sourceURL.deletingPathExtension().lastPathComponent),
            sourceKind: .gif,
            frameCount: frames.count,
            frameWidth: dimensions.frameWidth,
            frameHeight: dimensions.frameHeight,
            motionStyle: nil,
            pixelationScale: pixelationScale,
            createdAt: date,
            updatedAt: date
        )
        characters.append(character)
        try saveManifest()
        processingStates[id] = .ready
        return character
    }

    func importFrameSequence(
        from sourceURLs: [URL],
        displayName: String,
        pixelationScale: CustomCharacterPixelationScale
    ) async throws -> CustomCharacter {
        let sortedURLs = CustomCharacterImageProcessor.sortedFrameURLs(sourceURLs)
        let id = makeID()
        processingStates[id] = .loading
        let directory = rootDirectory.appendingPathComponent(id, isDirectory: true)
        let originalsDirectory = directory.appendingPathComponent("originals", isDirectory: true)
        try fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)

        for (index, url) in sortedURLs.enumerated() {
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            try copyReplacing(url, to: originalsDirectory.appendingPathComponent("frame_\(index).\(ext)"))
        }

        let cacheKey = cacheKeyForFrameSequence(sourceURLs: sortedURLs, pixelation: pixelationScale)
        let frames: [NSImage]
        if let cached = CustomCharacterImageProcessor.cachedFrames(for: cacheKey) {
            frames = cached
        } else {
            frames = try await CustomCharacterImageProcessor.processedFrameSequence(from: sortedURLs, pixelation: pixelationScale)
            CustomCharacterImageProcessor.storeFramesInCache(frames, key: cacheKey)
        }

        let dimensions = try CustomCharacterImageProcessor.writePNGFrames(frames, to: directory)
        let date = now()
        let character = CustomCharacter(
            id: id,
            displayName: sanitizedDisplayName(displayName, fallback: sortedURLs.first?.deletingPathExtension().lastPathComponent ?? "Custom Character"),
            sourceKind: .frameSequence,
            frameCount: frames.count,
            frameWidth: dimensions.frameWidth,
            frameHeight: dimensions.frameHeight,
            motionStyle: nil,
            pixelationScale: pixelationScale,
            createdAt: date,
            updatedAt: date
        )
        characters.append(character)
        try saveManifest()
        processingStates[id] = .ready
        return character
    }

    func rename(id: String, displayName: String) throws {
        guard let index = characters.firstIndex(where: { $0.id == id }) else {
            throw CustomCharacterStoreError.missingCharacter(id)
        }
        var character = characters[index]
        character.displayName = sanitizedDisplayName(displayName, fallback: character.displayName)
        character.updatedAt = now()
        characters[index] = character
        try saveManifest()
    }

    func delete(id: String) throws {
        guard let index = characters.firstIndex(where: { $0.id == id }) else {
            throw CustomCharacterStoreError.missingCharacter(id)
        }
        let character = characters.remove(at: index)
        let directory = characterDirectory(for: character)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try saveManifest()
    }

    func updateStaticCharacter(
        id: String,
        motionStyle: CustomCharacterMotionStyle,
        pixelationScale: CustomCharacterPixelationScale
    ) async throws {
        guard let index = characters.firstIndex(where: { $0.id == id }) else {
            throw CustomCharacterStoreError.missingCharacter(id)
        }
        var character = characters[index]
        processingStates[id] = .loading
        character.motionStyle = motionStyle
        character.pixelationScale = pixelationScale
        try await regenerateFrames(for: &character)
        character.updatedAt = now()
        characters[index] = character
        try saveManifest()
        processingStates[id] = .ready
    }

    func updatePixelation(id: String, pixelationScale: CustomCharacterPixelationScale) async throws {
        guard let index = characters.firstIndex(where: { $0.id == id }) else {
            throw CustomCharacterStoreError.missingCharacter(id)
        }
        var character = characters[index]
        processingStates[id] = .loading
        character.pixelationScale = pixelationScale
        try await regenerateFrames(for: &character)
        character.updatedAt = now()
        characters[index] = character
        try saveManifest()
        processingStates[id] = .ready
    }

    private func regenerateFrames(for character: inout CustomCharacter) async throws {
        let directory = characterDirectory(for: character)
        let frames: [NSImage]
        switch character.sourceKind {
        case .staticImage:
            let original = try originalSourceURL(in: directory, id: character.id)
            guard let image = NSImage(contentsOf: original) else {
                throw CustomCharacterImageProcessorError.unreadableImage(original)
            }
            frames = try await CustomCharacterImageProcessor.processedStaticFrames(
                from: image,
                motionStyle: character.motionStyle ?? .bounceBreathe,
                pixelation: character.pixelationScale
            )
        case .gif:
            let original = try originalSourceURL(in: directory, id: character.id)
            frames = try await CustomCharacterImageProcessor.processedGIFFrames(from: original, pixelation: character.pixelationScale)
        case .frameSequence:
            let originals = directory.appendingPathComponent("originals", isDirectory: true)
            let urls = (try? fileManager.contentsOfDirectory(at: originals, includingPropertiesForKeys: nil)) ?? []
            frames = try await CustomCharacterImageProcessor.processedFrameSequence(from: urls, pixelation: character.pixelationScale)
        }

        let dimensions = try CustomCharacterImageProcessor.writePNGFrames(frames, to: directory)
        character.frameCount = frames.count
        character.frameWidth = dimensions.frameWidth
        character.frameHeight = dimensions.frameHeight
    }

    private func loadManifest() {
        do {
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                characters = []
                return
            }
            let data = try Data(contentsOf: manifestURL)
            characters = try JSONDecoder().decode(Manifest.self, from: data).characters
        } catch {
            characters = []
        }
    }

    private func saveManifest() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Manifest(characters: characters))
        try data.write(to: manifestURL, options: .atomic)
        revision += 1
    }

    private var manifestURL: URL {
        rootDirectory.appendingPathComponent("manifest.json")
    }

    private func makeID() -> String {
        "custom.\(UUID().uuidString.lowercased())"
    }

    private func originalURL(in directory: URL, extension ext: String) -> URL {
        directory.appendingPathComponent("original.\(ext.isEmpty ? "png" : ext.lowercased())")
    }

    private func originalSourceURL(in directory: URL, id: String) throws -> URL {
        let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        if let original = urls.first(where: { $0.lastPathComponent.hasPrefix("original.") }) {
            return original
        }
        throw CustomCharacterStoreError.missingOriginalSource(id)
    }

    private func copyReplacing(_ source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private func sanitizedDisplayName(_ displayName: String, fallback: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let fallbackTrimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallbackTrimmed.isEmpty ? "Custom Character" : fallbackTrimmed
    }

    private struct Manifest: Codable {
        var characters: [CustomCharacter]
    }

    private func cacheKeyForStaticImage(
        sourceURL: URL,
        motionStyle: CustomCharacterMotionStyle,
        pixelation: CustomCharacterPixelationScale
    ) -> String {
        let data = (try? Data(contentsOf: sourceURL)) ?? Data()
        return CustomCharacterImageProcessor.cacheKey(
            data: data + motionStyle.rawValue.data(using: .utf8)!,
            pixelation: pixelation
        )
    }

    private func cacheKeyForGIF(sourceURL: URL, pixelation: CustomCharacterPixelationScale) -> String {
        let data = (try? Data(contentsOf: sourceURL)) ?? Data()
        return CustomCharacterImageProcessor.cacheKey(data: data, pixelation: pixelation)
    }

    private func cacheKeyForFrameSequence(sourceURLs: [URL], pixelation: CustomCharacterPixelationScale) -> String {
        var combined = Data()
        for url in sourceURLs {
            combined.append((try? Data(contentsOf: url)) ?? Data())
        }
        return CustomCharacterImageProcessor.cacheKey(data: combined, pixelation: pixelation)
    }
}
