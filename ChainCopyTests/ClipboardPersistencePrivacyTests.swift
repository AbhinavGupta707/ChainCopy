import XCTest
@testable import ChainCopy

final class ClipboardPersistencePrivacyTests: XCTestCase {
    @MainActor
    func testDefaultPersistenceStoresSettingsButNotClipboardContents() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.separator = " "
        }
        XCTAssertTrue(store.ingest(text: "Alpha", sourceAppName: "Notes"))

        let reloadedStore = ClipboardStore(persistence: persistence)

        XCTAssertEqual(reloadedStore.settings.separator, " ")
        XCTAssertTrue(reloadedStore.items.isEmpty)
    }

    @MainActor
    func testOptInLocalHistoryPersistsClipboardItems() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.persistClipboardContents = true
            settings.clearHistoryOnQuit = false
        }
        XCTAssertTrue(store.ingest(text: "Alpha", sourceAppName: "Notes", sourceAppBundleIdentifier: "com.apple.Notes"))
        XCTAssertTrue(store.ingest(text: "Beta", sourceAppName: "Safari", sourceAppBundleIdentifier: "com.apple.Safari"))

        let reloadedStore = ClipboardStore(persistence: persistence)

        XCTAssertEqual(reloadedStore.items.map(\.text), ["Beta", "Alpha"])
        XCTAssertEqual(reloadedStore.items.map(\.sourceAppName), ["Safari", "Notes"])
        XCTAssertEqual(reloadedStore.items.map(\.sourceAppBundleIdentifier), ["com.apple.Safari", "com.apple.Notes"])
    }

    @MainActor
    func testRetentionLimitIsAppliedBeforeAndAfterPersistence() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.persistClipboardContents = true
            settings.clearHistoryOnQuit = false
            settings.maxItemCount = 2
        }
        XCTAssertTrue(store.ingest(text: "One"))
        XCTAssertTrue(store.ingest(text: "Two"))
        XCTAssertTrue(store.ingest(text: "Three"))

        XCTAssertEqual(store.items.map(\.text), ["Three", "Two"])

        let reloadedStore = ClipboardStore(persistence: persistence)

        XCTAssertEqual(reloadedStore.items.map(\.text), ["Three", "Two"])
    }

    @MainActor
    func testPinnedItemsAreRetainedBeforeUnpinnedItems() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.persistClipboardContents = true
            settings.clearHistoryOnQuit = false
            settings.maxItemCount = 2
        }
        XCTAssertTrue(store.ingest(text: "One"))
        guard let oldest = store.items.first else {
            return XCTFail("Expected first item to exist")
        }
        store.togglePinned(oldest)
        XCTAssertTrue(store.ingest(text: "Two"))
        XCTAssertTrue(store.ingest(text: "Three"))

        XCTAssertEqual(store.items.map(\.text), ["Three", "One"])
    }

    @MainActor
    func testClearOnQuitRemovesPersistedClipboardItems() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.persistClipboardContents = true
            settings.clearHistoryOnQuit = false
        }
        XCTAssertTrue(store.ingest(text: "Temporary chain"))

        store.updateSettings { settings in
            settings.clearHistoryOnQuit = true
        }
        store.handleApplicationWillTerminate()

        let reloadedStore = ClipboardStore(persistence: persistence)

        XCTAssertTrue(reloadedStore.items.isEmpty)
        XCTAssertTrue(reloadedStore.settings.clearHistoryOnQuit)
    }

    @MainActor
    func testManualClearRemovesPersistedClipboardItems() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.persistClipboardContents = true
            settings.clearHistoryOnQuit = false
        }
        XCTAssertTrue(store.ingest(text: "Temporary chain"))
        store.clear()

        let reloadedStore = ClipboardStore(persistence: persistence)

        XCTAssertTrue(reloadedStore.items.isEmpty)
    }

    @MainActor
    func testFilteringSkipsIgnoredTypeAppSensitiveTextAndOversizedItems() throws {
        let fileURL = temporaryStateFileURL()
        defer { removeTemporaryStore(for: fileURL) }

        let persistence = FileClipboardPersistenceStore(fileURL: fileURL)
        let store = ClipboardStore(persistence: persistence)

        store.updateSettings { settings in
            settings.ignoredPasteboardTypes = ["private.secret"]
            settings.ignoredAppNames = ["Password Safe"]
            settings.ignoredAppBundleIdentifiers = ["com.example.secretbox"]
            settings.sensitiveContentPatterns = [#"token\s*:"#]
            settings.maxItemSizeBytes = 1_024
        }

        XCTAssertFalse(store.ingest(text: "Alpha", sourceAppName: "Notes", pasteboardTypes: ["private.secret"]))
        XCTAssertFalse(store.ingest(text: "Alpha", sourceAppName: "Password Safe"))
        XCTAssertFalse(store.ingest(text: "Alpha", sourceAppName: "Other", sourceAppBundleIdentifier: "com.example.secretbox"))
        XCTAssertFalse(store.ingest(text: "token: abc123", sourceAppName: "Terminal"))
        XCTAssertFalse(store.ingest(text: String(repeating: "a", count: 1_025), sourceAppName: "Terminal"))
        XCTAssertTrue(store.ingest(text: "Normal note", sourceAppName: "Notes"))
        XCTAssertEqual(store.items.map(\.text), ["Normal note"])
    }

    func testMetadataFilterBlocksIgnoredTypesBeforeTextRead() {
        var settings = ClipboardSettings()
        settings.ignoredPasteboardTypes = ["private.secret"]
        let filter = ClipboardPrivacyFilter()

        let decision = filter.metadataDecision(
            for: PasteboardInspection(types: ["private.secret"], sourceAppName: nil, sourceAppBundleIdentifier: nil, text: nil),
            settings: settings
        )

        XCTAssertEqual(decision.reason, .ignoredPasteboardType("private.secret"))
    }

    func testSettingsDecodeMissingKeysWithCurrentDefaults() throws {
        let json = #"{"separator":" "}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(ClipboardSettings.self, from: json)

        XCTAssertEqual(settings.separator, " ")
        XCTAssertEqual(settings.maxItemCount, 100)
        XCTAssertEqual(settings.maxItemSizeBytes, 1_000_000)
        XCTAssertFalse(settings.persistClipboardContents)
        XCTAssertTrue(settings.clearHistoryOnQuit)
        XCTAssertFalse(settings.ignoredPasteboardTypes.isEmpty)
    }

    private func temporaryStateFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ChainCopyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("clipboard-state.json")
    }

    private func removeTemporaryStore(for fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }
}
