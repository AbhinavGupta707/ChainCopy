import Foundation

protocol ClipboardPersistence {
    func load() throws -> PersistedClipboardState?
    func save(_ state: PersistedClipboardState) throws
    func clearItems() throws
}

struct PersistedClipboardState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var settings: ClipboardSettings
    var items: [ClipItem]

    init(
        schemaVersion: Int = PersistedClipboardState.currentSchemaVersion,
        settings: ClipboardSettings = ClipboardSettings(),
        items: [ClipItem] = []
    ) {
        self.schemaVersion = schemaVersion
        self.settings = settings.normalized()
        self.items = items
    }

    func normalizedForCurrentSettings() -> PersistedClipboardState {
        let normalizedSettings = settings.normalized()

        return PersistedClipboardState(
            schemaVersion: PersistedClipboardState.currentSchemaVersion,
            settings: normalizedSettings,
            items: Self.retainedItems(items, settings: normalizedSettings)
        )
    }

    static func retainedItems(_ items: [ClipItem], settings: ClipboardSettings) -> [ClipItem] {
        var retainedItems = items.filter { $0.text.utf8.count <= settings.maxItemSizeBytes }

        while retainedItems.count > settings.maxItemCount {
            if let removableIndex = retainedItems.lastIndex(where: { !$0.isPinned }) {
                retainedItems.remove(at: removableIndex)
            } else {
                retainedItems.removeLast()
            }
        }

        return retainedItems
    }
}

extension PersistedClipboardState {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case settings
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0,
            settings: try container.decodeIfPresent(ClipboardSettings.self, forKey: .settings) ?? ClipboardSettings(),
            items: try container.decodeIfPresent([ClipItem].self, forKey: .items) ?? []
        )
    }
}

struct FileClipboardPersistenceStore: ClipboardPersistence {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func applicationSupportStore(fileManager: FileManager = .default) -> FileClipboardPersistenceStore {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let directoryURL = baseURL.appendingPathComponent("ChainCopy", isDirectory: true)

        return FileClipboardPersistenceStore(
            fileURL: directoryURL.appendingPathComponent("clipboard-state.json")
        )
    }

    func load() throws -> PersistedClipboardState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(PersistedClipboardState.self, from: data).normalizedForCurrentSettings()
    }

    func save(_ state: PersistedClipboardState) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(state.normalizedForCurrentSettings())
        try data.write(to: fileURL, options: [.atomic])
    }

    func clearItems() throws {
        let state = try load() ?? PersistedClipboardState()
        try save(PersistedClipboardState(settings: state.settings, items: []))
    }
}
