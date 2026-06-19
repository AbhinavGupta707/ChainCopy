import AppKit
import Combine
import Foundation

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
    private var lastPasteboardWrite: String?
    private var isReadyToPersist = false
    private var isApplyingRetention = false
    private var isApplyingSettings = false
    private var terminationObserver: NSObjectProtocol?

    init(
        items: [ClipItem]? = nil,
        settings: ClipboardSettings? = nil,
        isCaptureEnabled: Bool? = nil,
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
        pasteAutomationService: PasteAutomationService = PasteAutomationService()
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
        pasteboardTypes: Set<String> = [PasteboardTypeNames.string]
    ) -> Bool {
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
        let decision = captureEngine.evaluate(
            snapshot: snapshot,
            method: method,
            existingItems: items,
            settings: settings,
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

    func setCaptureEnabled(_ enabled: Bool) {
        isCaptureEnabled = enabled
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

    func copyComposedToPasteboard() {
        writeToPasteboard(composedText)
    }

    @discardableResult
    func pasteComposedWithAutomation() -> PasteAutomationResult {
        let text = composedText
        guard !text.isEmpty else {
            lastPasteAutomationResult = .emptyChain
            return .emptyChain
        }

        writeToPasteboard(text)
        let outcome = pasteAutomationService.sendPasteIfPermitted()
        refreshAccessibilityStatus()

        switch outcome {
        case .pasted:
            lastPasteAutomationResult = .pasted
        case .permissionRequired:
            lastPasteAutomationResult = .copiedPermissionRequired
        }

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

    private func writeToPasteboard(_ text: String) {
        guard !text.isEmpty, let changeCount = pasteboardWriter.writeString(text, ownedByChainCopy: true) else {
            return
        }

        lastPasteboardWrite = text
        ownWriteTracker.record(changeCount: changeCount)
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
