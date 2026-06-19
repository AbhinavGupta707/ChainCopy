import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [ClipItem] {
        didSet {
            guard isReadyToPersist, !isApplyingRetention else {
                return
            }

            enforceRetention()
            persistState()
        }
    }

    @Published var isCaptureEnabled: Bool {
        didSet {
            updateSettingFromLegacyBinding { settings in
                settings.isCaptureEnabled = isCaptureEnabled
            }
        }
    }

    @Published var isAppendModeEnabled: Bool

    @Published var maxItemCount: Int {
        didSet {
            updateSettingFromLegacyBinding { settings in
                settings.maxItemCount = maxItemCount
            }
        }
    }

    @Published var maxItemSizeBytes: Int {
        didSet {
            updateSettingFromLegacyBinding { settings in
                settings.maxItemSizeBytes = maxItemSizeBytes
            }
        }
    }

    @Published var suppressAdjacentDuplicates: Bool {
        didSet {
            updateSettingFromLegacyBinding { settings in
                settings.suppressAdjacentDuplicates = suppressAdjacentDuplicates
            }
        }
    }

    @Published var separator: String {
        didSet {
            updateSettingFromLegacyBinding { settings in
                settings.separator = separator
            }
        }
    }

    @Published var lastInfoMessage: String?
    @Published var lastErrorMessage: String?
    @Published private(set) var settings: ClipboardSettings
    @Published private(set) var lastPersistenceError: Error?
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var lastPasteAutomationResult: PasteAutomationResult?

    private let composer: ClipboardComposer
    private let captureEngine: CaptureEngine
    private let pasteboardWriter: any PasteboardStringWriting
    private let ownWriteTracker: OwnPasteboardWriteTracker
    private let persistence: any ClipboardPersistence
    private let privacyFilter: ClipboardPrivacyFilter
    private let pasteAutomationService: PasteAutomationService
    private let snapshotProvider: any PasteboardSnapshotProviding
    private var lastPasteboardWrite: String?
    private var isReadyToPersist = false
    private var isApplyingRetention = false
    private var isApplyingSettings = false
    private var terminationObserver: NSObjectProtocol?

    init(
        items: [ClipItem]? = nil,
        settings: ClipboardSettings? = nil,
        isCaptureEnabled: Bool? = nil,
        isAppendModeEnabled: Bool = false,
        maxItemCount: Int? = nil,
        maxItemSizeBytes: Int? = nil,
        suppressAdjacentDuplicates: Bool? = nil,
        separator: String? = nil,
        composer: ClipboardComposer = ClipboardComposer(),
        captureEngine: CaptureEngine = CaptureEngine(),
        pasteboardWriter: any PasteboardStringWriting = NSPasteboardStringWriter(),
        ownWriteTracker: OwnPasteboardWriteTracker = OwnPasteboardWriteTracker(),
        persistence: any ClipboardPersistence = FileClipboardPersistenceStore.applicationSupportStore(),
        privacyFilter: ClipboardPrivacyFilter = ClipboardPrivacyFilter(),
        pasteAutomationService: PasteAutomationService = PasteAutomationService(),
        snapshotProvider: any PasteboardSnapshotProviding = NSPasteboardSnapshotProvider()
    ) {
        let persistedState = try? persistence.load()
        var resolvedSettings = settings ?? persistedState?.settings ?? ClipboardSettings()

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

        let shouldRestoreItems = resolvedSettings.persistClipboardContents && !resolvedSettings.clearHistoryOnQuit
        let resolvedItems = items ?? (shouldRestoreItems ? persistedState?.items ?? [] : [])

        self.items = PersistedClipboardState.retainedItems(resolvedItems, settings: resolvedSettings)
        self.isCaptureEnabled = resolvedSettings.isCaptureEnabled
        self.isAppendModeEnabled = isAppendModeEnabled && resolvedSettings.isCaptureEnabled
        self.maxItemCount = resolvedSettings.maxItemCount
        self.maxItemSizeBytes = resolvedSettings.maxItemSizeBytes
        self.suppressAdjacentDuplicates = resolvedSettings.suppressAdjacentDuplicates
        self.separator = resolvedSettings.separator
        self.settings = resolvedSettings
        self.composer = composer
        self.captureEngine = captureEngine
        self.pasteboardWriter = pasteboardWriter
        self.ownWriteTracker = ownWriteTracker
        self.persistence = persistence
        self.privacyFilter = privacyFilter
        self.pasteAutomationService = pasteAutomationService
        self.snapshotProvider = snapshotProvider
        self.isAccessibilityTrusted = pasteAutomationService.isAccessibilityTrusted()
        self.isReadyToPersist = true

        addTerminationObserver()
        persistState()
    }

    deinit {
        MainActor.assumeIsolated {
            if let terminationObserver {
                NotificationCenter.default.removeObserver(terminationObserver)
            }
        }
    }

    var composedText: String {
        composer.compose(items.map(\.text), separator: separator)
    }

    var composedCharacterCount: Int {
        composedText.count
    }

    var separatorPreset: SeparatorPreset {
        SeparatorPreset.matching(separator)
    }

    var visualState: ChainVisualState {
        if lastErrorMessage != nil {
            return .error
        }

        if !isCaptureEnabled {
            return .paused
        }

        if isAppendModeEnabled {
            return .appendMode
        }

        return items.isEmpty ? .idle : .collecting
    }

    var menuBarDisplayTitle: String {
        if isAppendModeEnabled || !items.isEmpty {
            return "\(items.count)"
        }

        return "ChainCopy"
    }

    var menuBarSystemImage: String {
        switch visualState {
        case .idle:
            return "link.badge.plus"
        case .collecting:
            return "text.badge.plus"
        case .appendMode:
            return "bolt.circle.fill"
        case .paused:
            return "pause.circle"
        case .permissionNeeded:
            return "hand.raised"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    func updateSettings(_ update: (inout ClipboardSettings) -> Void) {
        var updatedSettings = settings
        update(&updatedSettings)
        applySettings(updatedSettings.normalized())
    }

    @discardableResult
    func ingest(
        text: String,
        sourceAppName: String? = NSWorkspace.shared.frontmostApplication?.localizedName,
        sourceAppBundleIdentifier: String? = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
        pasteboardTypes: Set<String> = [PasteboardTypeNames.string],
        requiresAppendMode: Bool = false
    ) -> Bool {
        guard !requiresAppendMode || isAppendModeEnabled else {
            return false
        }

        let snapshot = PasteboardCaptureSnapshot(
            changeCount: -1,
            types: pasteboardTypes,
            content: .plainText(text, types: pasteboardTypes),
            sourceApplication: SourceApplication(
                name: sourceAppName,
                bundleIdentifier: sourceAppBundleIdentifier
            )
        )

        if case .captured = ingest(snapshot: snapshot, method: .manual) {
            return true
        }

        return false
    }

    @discardableResult
    func ingest(snapshot: PasteboardCaptureSnapshot, method: CaptureMethod) -> CaptureDecision {
        if method == .appendModeClipboardChange, !isAppendModeEnabled {
            return .ignored(.captureDisabled)
        }

        let decision = captureEngine.evaluate(
            snapshot: snapshot,
            method: method,
            existingItems: items,
            settings: settings,
            ownWriteTracker: ownWriteTracker
        )

        switch decision {
        case let .captured(item):
            appendItem(item)
            lastErrorMessage = nil
            lastInfoMessage = "Added \(items.count == 1 ? "first snippet" : "\(items.count) snippets")"
        case let .ignored(reason):
            if method != .appendModeClipboardChange {
                lastErrorMessage = message(for: reason)
            }
        }

        return decision
    }

    func appendCurrentPasteboard() {
        let decision = ingest(snapshot: snapshotProvider.snapshot(), method: .appendCurrentClipboard)
        if case .captured = decision {
            return
        }

        if case .ignored(.unsupportedContent) = decision {
            lastErrorMessage = "The current clipboard does not contain text ChainCopy can append."
        }
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        lastInfoMessage = "Removed snippet"
    }

    func clear() {
        items.removeAll()
        lastPasteAutomationResult = nil
        lastInfoMessage = "Chain cleared"
        lastErrorMessage = nil
    }

    func setCaptureEnabled(_ enabled: Bool) {
        isCaptureEnabled = enabled
        if enabled {
            lastInfoMessage = "ChainCopy resumed"
        } else {
            isAppendModeEnabled = false
            lastInfoMessage = "ChainCopy paused"
        }
        lastErrorMessage = nil
    }

    func setAppendModeEnabled(_ enabled: Bool) {
        guard isCaptureEnabled || !enabled else {
            lastErrorMessage = "Resume ChainCopy before enabling Append Mode."
            return
        }

        isAppendModeEnabled = enabled
        lastErrorMessage = nil
        lastInfoMessage = enabled ? "Append Mode on" : "Append Mode off"
    }

    func handleApplicationWillTerminate() {
        guard settings.clearHistoryOnQuit else {
            return
        }

        clear()

        do {
            try persistence.clearItems()
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error
        }
    }

    func togglePinned(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index].isPinned.toggle()
    }

    func updateText(for id: ClipItem.ID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].text = text
        items[index].contentHash = ContentHasher.hash(text)
        items[index].contentKind = .text
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func move(_ item: ClipItem, direction: ChainMoveDirection) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = max(items.startIndex, index - 1)
        case .down:
            targetIndex = min(items.index(before: items.endIndex), index + 1)
        }

        guard targetIndex != index else {
            return
        }

        items.swapAt(index, targetIndex)
    }

    func applySeparatorPreset(_ preset: SeparatorPreset) {
        separator = preset.separator
        lastInfoMessage = "Separator set to \(preset.title.lowercased())"
    }

    func copyComposedToPasteboard() {
        let text = composedText
        guard !text.isEmpty else {
            lastErrorMessage = "There is no chain to copy yet."
            return
        }

        guard writeToPasteboard(text) else {
            lastErrorMessage = "Could not write the chain to the clipboard."
            return
        }

        lastInfoMessage = "Copied joined block"
        lastErrorMessage = nil
    }

    func copyItemToPasteboard(_ item: ClipItem) {
        guard writeToPasteboard(item.text) else {
            lastErrorMessage = "Could not copy the snippet."
            return
        }

        lastInfoMessage = "Copied snippet"
        lastErrorMessage = nil
    }

    @discardableResult
    func pasteComposedWithAutomation() -> PasteAutomationResult {
        let text = composedText
        guard !text.isEmpty else {
            lastPasteAutomationResult = .emptyChain
            lastErrorMessage = PasteAutomationResult.emptyChain.message
            return .emptyChain
        }

        guard writeToPasteboard(text) else {
            lastPasteAutomationResult = .emptyChain
            lastErrorMessage = "Could not write the chain to the clipboard."
            return .emptyChain
        }

        let outcome = pasteAutomationService.sendPasteIfPermitted()
        refreshAccessibilityStatus()

        switch outcome {
        case .pasted:
            lastPasteAutomationResult = .pasted
        case .permissionRequired:
            lastPasteAutomationResult = .copiedPermissionRequired
        }

        lastInfoMessage = lastPasteAutomationResult?.message
        lastErrorMessage = nil
        return lastPasteAutomationResult ?? .emptyChain
    }

    func refreshAccessibilityStatus(prompt: Bool = false) {
        isAccessibilityTrusted = pasteAutomationService.isAccessibilityTrusted(prompt: prompt)
    }

    func requestAccessibilityPermission() {
        refreshAccessibilityStatus(prompt: true)
    }

    func openAccessibilitySettings() {
        pasteAutomationService.openAccessibilitySettings()
    }

    func dismissFeedback() {
        lastInfoMessage = nil
        lastErrorMessage = nil
    }

    func ownsPasteboardText(_ text: String) -> Bool {
        text == lastPasteboardWrite
    }

    func metadataPrivacyDecision(
        pasteboardTypes: Set<String>,
        sourceAppName: String?,
        sourceAppBundleIdentifier: String?
    ) -> ClipboardPrivacyFilterDecision {
        privacyFilter.metadataDecision(
            for: PasteboardInspection(
                types: pasteboardTypes,
                sourceAppName: sourceAppName,
                sourceAppBundleIdentifier: sourceAppBundleIdentifier,
                text: nil
            ),
            settings: settings
        )
    }

    private func appendItem(_ item: ClipItem) {
        items.append(item)
    }

    @discardableResult
    private func writeToPasteboard(_ text: String) -> Bool {
        guard !text.isEmpty, let changeCount = pasteboardWriter.writeString(text, ownedByChainCopy: true) else {
            return false
        }

        lastPasteboardWrite = text
        ownWriteTracker.record(changeCount: changeCount)
        return true
    }

    private func updateSettingFromLegacyBinding(_ update: (inout ClipboardSettings) -> Void) {
        guard isReadyToPersist, !isApplyingSettings else {
            return
        }

        var updatedSettings = settings
        update(&updatedSettings)
        applySettings(updatedSettings.normalized())
    }

    private func applySettings(_ newSettings: ClipboardSettings) {
        let normalizedSettings = newSettings.normalized()

        isApplyingSettings = true
        settings = normalizedSettings
        isCaptureEnabled = normalizedSettings.isCaptureEnabled
        maxItemCount = normalizedSettings.maxItemCount
        maxItemSizeBytes = normalizedSettings.maxItemSizeBytes
        suppressAdjacentDuplicates = normalizedSettings.suppressAdjacentDuplicates
        separator = normalizedSettings.separator
        isApplyingSettings = false

        if !normalizedSettings.isCaptureEnabled {
            isAppendModeEnabled = false
        }

        enforceRetention()
        persistState()
    }

    private func addTerminationObserver() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleApplicationWillTerminate()
            }
        }
    }

    private func enforceRetention() {
        let retainedItems = PersistedClipboardState.retainedItems(items, settings: settings)
        guard retainedItems != items else {
            return
        }

        isApplyingRetention = true
        items = retainedItems
        isApplyingRetention = false
    }

    private func persistState() {
        let persistedItems = settings.persistClipboardContents && !settings.clearHistoryOnQuit ? items : []
        let state = PersistedClipboardState(settings: settings, items: persistedItems)

        do {
            try persistence.save(state)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error
        }
    }

    private func message(for reason: CaptureRejectionReason) -> String {
        switch reason {
        case .captureDisabled:
            return "Capture is paused or Append Mode is off."
        case .ownWrite:
            return "ChainCopy skipped its own clipboard write."
        case .privacy(.ignoredPasteboardType):
            return "This clipboard item was skipped by privacy rules."
        case .privacy(.ignoredSourceApp):
            return "This source app is ignored by privacy settings."
        case .privacy(.emptyText):
            return "The clipboard text is empty."
        case .privacy(.oversizedText):
            return "The clipboard text is larger than the current limit."
        case .privacy(.sensitiveContentPattern):
            return "This clipboard item matched a sensitive-content rule."
        case .unsupportedContent:
            return "The current clipboard does not contain text ChainCopy can append."
        case .duplicateOfLatestItem:
            return "That snippet is already the latest item in the chain."
        }
    }
}

enum PasteAutomationResult: Equatable {
    case pasted
    case copiedPermissionRequired
    case emptyChain

    var message: String {
        switch self {
        case .pasted:
            return "Pasted chain into the active app."
        case .copiedPermissionRequired:
            return "Copied chain. Enable Accessibility to auto-paste."
        case .emptyChain:
            return "Nothing to paste yet."
        }
    }
}

enum ChainMoveDirection {
    case up
    case down
}
