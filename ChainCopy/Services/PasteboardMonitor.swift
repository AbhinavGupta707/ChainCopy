import AppKit
import Foundation

@MainActor
final class PasteboardMonitor {
    private let snapshotProvider: any PasteboardSnapshotProviding
    private var lastChangeCount: Int
    private var timer: Timer?

    init(snapshotProvider: any PasteboardSnapshotProviding = NSPasteboardSnapshotProvider()) {
        self.snapshotProvider = snapshotProvider
        self.lastChangeCount = snapshotProvider.changeCount
    }

    func start(store: ClipboardStore) {
        guard timer == nil else {
            return
        }

        lastChangeCount = snapshotProvider.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self, weak store] _ in
            Task { @MainActor in
                guard let self, let store else {
                    return
                }

                self.poll(store: store)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll(store: ClipboardStore) {
        let changeCount = snapshotProvider.changeCount
        guard changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = changeCount

        guard store.isCaptureEnabled, store.isAppendModeEnabled else {
            return
        }

        store.ingest(snapshot: snapshotProvider.snapshot(), method: .appendModeClipboardChange)
    }
}
