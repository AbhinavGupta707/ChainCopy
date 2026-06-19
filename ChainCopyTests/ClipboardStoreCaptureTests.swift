import XCTest
@testable import ChainCopy

@MainActor
final class ClipboardStoreCaptureTests: XCTestCase {
    func testStoreAppliesMaxItemLimitThroughCapturePath() {
        let store = ClipboardStore(
            settings: ClipboardSettings(maxItemCount: 2),
            persistence: MemoryClipboardPersistence()
        )

        store.ingest(snapshot: snapshot("Alpha", changeCount: 1))
        store.ingest(snapshot: snapshot("Beta", changeCount: 2))
        store.ingest(snapshot: snapshot("Gamma", changeCount: 3))

        XCTAssertEqual(store.items.map(\.text), ["Beta", "Gamma"])
    }

    func testComposedCopyRecordsOwnedWriteAndSuppressesAppendModeRecapture() {
        let tracker = OwnPasteboardWriteTracker()
        let writer = RecordingPasteboardWriter(nextChangeCount: 99)
        let store = ClipboardStore(
            items: [ClipItem(text: "Alpha"), ClipItem(text: "Beta")],
            settings: ClipboardSettings(),
            persistence: MemoryClipboardPersistence(),
            ownWriteTracker: tracker,
            pasteboardWriter: writer
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
            persistence: MemoryClipboardPersistence()
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

private final class MemoryClipboardPersistence: ClipboardPersistence {
    var state: PersistedClipboardState?

    init(state: PersistedClipboardState? = nil) {
        self.state = state
    }

    func load() throws -> PersistedClipboardState? {
        state
    }

    func save(_ state: PersistedClipboardState) throws {
        self.state = state
    }

    func clearItems() throws {
        state = PersistedClipboardState(settings: state?.settings ?? ClipboardSettings(), items: [])
    }
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
