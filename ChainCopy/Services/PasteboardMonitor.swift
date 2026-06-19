import AppKit
import Foundation

@MainActor
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(store: ClipboardStore) {
        guard timer == nil else {
            return
        }

        lastChangeCount = pasteboard.changeCount
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
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = changeCount

        guard store.isCaptureEnabled else {
            return
        }

        let sourceApplication = NSWorkspace.shared.frontmostApplication
        let pasteboardTypes = Set((pasteboard.types ?? []).map(\.rawValue))
        let metadataDecision = store.metadataPrivacyDecision(
            pasteboardTypes: pasteboardTypes,
            sourceAppName: sourceApplication?.localizedName,
            sourceAppBundleIdentifier: sourceApplication?.bundleIdentifier
        )
        guard metadataDecision.isAllowed else {
            return
        }

        guard let text = pasteboard.string(forType: .string), !store.ownsPasteboardText(text) else {
            return
        }

        store.ingest(
            text: text,
            sourceAppName: sourceApplication?.localizedName,
            sourceAppBundleIdentifier: sourceApplication?.bundleIdentifier,
            pasteboardTypes: pasteboardTypes
        )
    }
}
