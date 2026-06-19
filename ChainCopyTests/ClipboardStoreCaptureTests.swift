import XCTest
@testable import ChainCopy

@MainActor
final class ClipboardStoreCaptureTests: XCTestCase {
    func testStoreAppliesMaxItemLimitThroughCapturePath() {
        let store = ClipboardStore(
            settings: ClipboardSettings(maxItemCount: 2),
            isAppendModeEnabled: true,
            persistence: NoOpClipboardPersistence()
        )

        store.ingest(snapshot: snapshot("Alpha", changeCount: 1), method: .appendModeClipboardChange)
        store.ingest(snapshot: snapshot("Beta", changeCount: 2), method: .appendModeClipboardChange)
        store.ingest(snapshot: snapshot("Gamma", changeCount: 3), method: .appendModeClipboardChange)

        XCTAssertEqual(store.items.map(\.text), ["Beta", "Gamma"])
    }

    func testStoreCapturesInClipboardOrder() {
        let store = ClipboardStore(
            settings: ClipboardSettings(),
            isAppendModeEnabled: true,
            persistence: NoOpClipboardPersistence()
        )

        store.ingest(snapshot: snapshot("Alpha", changeCount: 1), method: .appendModeClipboardChange)
        store.ingest(snapshot: snapshot("Beta", changeCount: 2), method: .appendModeClipboardChange)

        XCTAssertEqual(store.items.map(\.text), ["Alpha", "Beta"])
        XCTAssertEqual(store.composedText, "Alpha\n\nBeta")
    }

    func testComposedCopyRecordsOwnedWriteAndSuppressesAppendModeRecapture() {
        let tracker = OwnPasteboardWriteTracker()
        let writer = RecordingPasteboardWriter(nextChangeCount: 99)
        let store = ClipboardStore(
            items: [ClipItem(text: "Alpha"), ClipItem(text: "Beta")],
            settings: ClipboardSettings(),
            isAppendModeEnabled: true,
            pasteboardWriter: writer,
            ownWriteTracker: tracker,
            persistence: NoOpClipboardPersistence()
        )

        store.copyComposedToPasteboard()

        XCTAssertEqual(writer.writes.map(\.text), ["Alpha\n\nBeta"])
        XCTAssertEqual(writer.writes.map(\.ownedByChainCopy), [true])

        let decision = store.ingest(
            snapshot: PasteboardCaptureSnapshot(
                changeCount: 99,
                types: [PasteboardTypeNames.string],
                content: .plainText("Alpha\n\nBeta")
            ),
            method: .appendModeClipboardChange
        )

        guard case .ignored(.ownWrite) = decision else {
            return XCTFail("Expected composed copy to be ignored as an own write")
        }

        XCTAssertEqual(store.items.map(\.text), ["Alpha", "Beta"])
    }

    func testComposedCopyMarkerAlsoSuppressesRecapture() {
        let store = ClipboardStore(
            items: [ClipItem(text: "Alpha")],
            settings: ClipboardSettings(),
            isAppendModeEnabled: true,
            persistence: NoOpClipboardPersistence()
        )

        let decision = store.ingest(
            snapshot: PasteboardCaptureSnapshot(
                changeCount: 100,
                types: [PasteboardTypeNames.string, PasteboardTypeNames.chainCopyOwnedWrite],
                content: .plainText("Alpha")
            ),
            method: .appendModeClipboardChange
        )

        guard case .ignored(.ownWrite) = decision else {
            return XCTFail("Expected marker type to be ignored as an own write")
        }
    }

    private func snapshot(_ text: String, changeCount: Int) -> PasteboardCaptureSnapshot {
        PasteboardCaptureSnapshot(
            changeCount: changeCount,
            content: .plainText(text)
        )
    }
}

private struct NoOpClipboardPersistence: ClipboardPersistence {
    func load() throws -> PersistedClipboardState? {
        nil
    }

    func save(_ state: PersistedClipboardState) throws {}

    func clearItems() throws {}
}

@MainActor
private final class RecordingPasteboardWriter: PasteboardStringWriting {
    struct Write: Equatable {
        var text: String
        var ownedByChainCopy: Bool
    }

    var writes: [Write] = []
    private var nextChangeCount: Int

    init(nextChangeCount: Int) {
        self.nextChangeCount = nextChangeCount
    }

    func writeString(_ text: String, ownedByChainCopy: Bool) -> Int? {
        writes.append(Write(text: text, ownedByChainCopy: ownedByChainCopy))
        defer { nextChangeCount += 1 }
        return nextChangeCount
    }
}
