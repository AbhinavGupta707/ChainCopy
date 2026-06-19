import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [ClipItem]
    @Published var isCaptureEnabled: Bool
    @Published var maxItemCount: Int
    @Published var maxItemSizeBytes: Int
    @Published var suppressAdjacentDuplicates: Bool
    @Published var separator: String

    private let composer: ClipboardComposer
    private let captureEngine: CaptureEngine
    private let pasteboardWriter: any PasteboardStringWriting
    private let ownWriteTracker: OwnPasteboardWriteTracker

    private var ignoredAppNames: [String]
    private var ignoredAppBundleIdentifiers: [String]
    private var ignoredPasteboardTypes: [String]
    private var sensitiveContentPatterns: [String]

    init(
        items: [ClipItem] = [],
        settings: ClipboardSettings? = nil,
        isCaptureEnabled: Bool? = nil,
        maxItemCount: Int? = nil,
        maxItemSizeBytes: Int? = nil,
        suppressAdjacentDuplicates: Bool? = nil,
        separator: String? = nil,
        composer: ClipboardComposer = ClipboardComposer(),
        captureEngine: CaptureEngine = CaptureEngine(),
        pasteboardWriter: any PasteboardStringWriting = NSPasteboardStringWriter(),
        ownWriteTracker: OwnPasteboardWriteTracker = OwnPasteboardWriteTracker()
    ) {
        var resolvedSettings = settings ?? ClipboardSettings()

        if let isCaptureEnabled {
            resolvedSettings.isCaptureEnabled = isCaptureEnabled
        }

        if let maxItemCount {
            resolvedSettings.maxItemCount = maxItemCount
        }

        if let maxItemSizeBytes {
            resolvedSettings.maxItemSizeBytes = maxItemSizeBytes
        }

        if let suppressAdjacentDuplicates {
            resolvedSettings.suppressAdjacentDuplicates = suppressAdjacentDuplicates
        }

        if let separator {
            resolvedSettings.separator = separator
        }

        resolvedSettings = resolvedSettings.normalized()

        self.items = items
        self.isCaptureEnabled = resolvedSettings.isCaptureEnabled
        self.maxItemCount = resolvedSettings.maxItemCount
        self.maxItemSizeBytes = resolvedSettings.maxItemSizeBytes
        self.suppressAdjacentDuplicates = resolvedSettings.suppressAdjacentDuplicates
        self.separator = resolvedSettings.separator
        self.composer = composer
        self.captureEngine = captureEngine
        self.pasteboardWriter = pasteboardWriter
        self.ownWriteTracker = ownWriteTracker
        self.ignoredAppNames = resolvedSettings.ignoredAppNames
        self.ignoredAppBundleIdentifiers = resolvedSettings.ignoredAppBundleIdentifiers
        self.ignoredPasteboardTypes = resolvedSettings.ignoredPasteboardTypes
        self.sensitiveContentPatterns = resolvedSettings.sensitiveContentPatterns

        enforceRetention()
    }

    var composedText: String {
        composer.compose(items.map(\.text), separator: separator)
    }

    var composedCharacterCount: Int {
        composedText.count
    }

    private var currentSettings: ClipboardSettings {
        ClipboardSettings(
            isCaptureEnabled: isCaptureEnabled,
            separator: separator,
            maxItemCount: maxItemCount,
            maxItemSizeBytes: maxItemSizeBytes,
            suppressAdjacentDuplicates: suppressAdjacentDuplicates,
            ignoredAppNames: ignoredAppNames,
            ignoredAppBundleIdentifiers: ignoredAppBundleIdentifiers,
            ignoredPasteboardTypes: ignoredPasteboardTypes,
            sensitiveContentPatterns: sensitiveContentPatterns
        )
    }

    func ingest(text: String, sourceAppName: String? = NSWorkspace.shared.frontmostApplication?.localizedName) {
        let snapshot = PasteboardCaptureSnapshot(
            changeCount: -1,
            content: .plainText(text),
            sourceApplication: SourceApplication(name: sourceAppName, bundleIdentifier: nil)
        )

        ingest(snapshot: snapshot, method: .manual)
    }

    @discardableResult
    func ingest(snapshot: PasteboardCaptureSnapshot, method: CaptureMethod) -> CaptureDecision {
        let decision = captureEngine.evaluate(
            snapshot: snapshot,
            method: method,
            existingItems: items,
            settings: currentSettings,
            ownWriteTracker: ownWriteTracker
        )

        if case let .captured(item) = decision {
            appendItem(item)
        }

        return decision
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    func togglePinned(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].isPinned.toggle()
    }

    func copyComposedToPasteboard() {
        let text = composedText
        guard !text.isEmpty, let changeCount = pasteboardWriter.writeString(text, ownedByChainCopy: true) else {
            return
        }

        ownWriteTracker.record(changeCount: changeCount)
    }

    private func appendItem(_ item: ClipItem) {
        items.append(item)
        enforceRetention()
    }

    private func enforceRetention() {
        let settings = currentSettings
        items.removeAll { $0.text.utf8.count > settings.maxItemSizeBytes }

        while items.count > settings.maxItemCount {
            if let removableIndex = items.firstIndex(where: { !$0.isPinned }) {
                items.remove(at: removableIndex)
            } else {
                items.removeFirst()
            }
        }
    }
}
