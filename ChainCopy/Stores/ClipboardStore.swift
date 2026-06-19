import AppKit
import Combine
import Foundation

enum ChainVisualState: Equatable {
    case idle
    case collecting
    case appendMode
    case paused
    case error
}

enum ChainMoveDirection {
    case up
    case down
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [ClipItem] {
        didSet {
            guard isReadyToPersist, !isApplyingRetention else {
                return
            }

            self.enforceRetention()
            self.persistState()
        }
    }

    @Published private(set) var isCaptureEnabled: Bool
    @Published private(set) var isAppendModeEnabled: Bool
    @Published var maxItemCount: Int
    @Published var separator: String
    @Published private(set) var settings: ClipboardSettings
    @Published private(set) var lastInfoMessage: String?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published var hasSeenAccessibilityOnboarding: Bool {
        didSet {
            userDefaults.set(hasSeenAccessibilityOnboarding, forKey: Self.accessibilityOnboardingKey)
        }
    }

    private let composer: ClipboardComposer
    private let captureEngine: CaptureEngine
    private let snapshotProvider: any PasteboardSnapshotProviding
    private let pasteboardWriter: any PasteboardStringWriting
    private let ownWriteTracker: OwnPasteboardWriteTracker
    private let permissionService: PermissionService
    private let keyEventSynthesizer: any KeyEventSynthesizing
    private let userDefaults: UserDefaults
    private let persistence: any ClipboardPersistence

    private var isReadyToPersist = false
    private var isApplyingRetention = false
    private var terminationObserver: NSObjectProtocol?
    private(set) var lastPersistenceError: Error?

    private static let accessibilityOnboardingKey = "AccessibilityOnboardingSeen"

    init(
        items: [ClipItem]? = nil,
        isCaptureEnabled: Bool? = nil,
        isAppendModeEnabled: Bool = false,
        maxItemCount: Int? = nil,
        separator: String? = nil,
        settings: ClipboardSettings? = nil,
        composer: ClipboardComposer = ClipboardComposer(),
        captureEngine: CaptureEngine = CaptureEngine(),
        snapshotProvider: any PasteboardSnapshotProviding = NSPasteboardSnapshotProvider(),
        pasteboardWriter: any PasteboardStringWriting = NSPasteboardStringWriter(),
        ownWriteTracker: OwnPasteboardWriteTracker = OwnPasteboardWriteTracker(),
        permissionService: PermissionService = PermissionService(),
        keyEventSynthesizer: any KeyEventSynthesizing = CGKeyEventSynthesizer(),
        userDefaults: UserDefaults = .standard,
        persistence: any ClipboardPersistence = FileClipboardPersistenceStore.applicationSupportStore()
    ) {
        let persistedState = try? persistence.load()
        var resolvedSettings = settings ?? persistedState?.settings ?? ClipboardSettings()

        if let isCaptureEnabled {
            resolvedSettings.isCaptureEnabled = isCaptureEnabled
        }

        if let maxItemCount {
            resolvedSettings.maxItemCount = maxItemCount
        }

        if let separator {
            resolvedSettings.separator = separator
        }

        resolvedSettings = resolvedSettings.normalized()

        let shouldRestoreItems = resolvedSettings.persistClipboardContents && !resolvedSettings.clearHistoryOnQuit
        let resolvedItems = items ?? (shouldRestoreItems ? persistedState?.items ?? [] : [])

        self.items = Self.retainedItems(resolvedItems, settings: resolvedSettings)
        self.isCaptureEnabled = resolvedSettings.isCaptureEnabled
        self.isAppendModeEnabled = isAppendModeEnabled
        self.maxItemCount = resolvedSettings.maxItemCount
        self.separator = resolvedSettings.separator
        self.settings = resolvedSettings
        self.composer = composer
        self.captureEngine = captureEngine
        self.snapshotProvider = snapshotProvider
        self.pasteboardWriter = pasteboardWriter
        self.ownWriteTracker = ownWriteTracker
        self.permissionService = permissionService
        self.keyEventSynthesizer = keyEventSynthesizer
        self.userDefaults = userDefaults
        self.persistence = persistence
        self.isAccessibilityTrusted = permissionService.isAccessibilityTrusted()
        self.hasSeenAccessibilityOnboarding = userDefaults.bool(forKey: Self.accessibilityOnboardingKey)
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

    var maxItemSizeBytes: Int {
        settings.maxItemSizeBytes
    }

    var separatorPreset: SeparatorPreset {
        SeparatorPreset.matching(separator)
    }

    func updateSettings(_ update: (inout ClipboardSettings) -> Void) {
        var updatedSettings = settings
        update(&updatedSettings)
        applySettings(updatedSettings.normalized())
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

    var menuBarSystemImage: String {
        switch visualState {
        case .idle:
            return "link"
        case .collecting:
            return "link.badge.plus"
        case .appendMode:
            return "bolt.circle.fill"
        case .paused:
            return "pause.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    func setCaptureEnabled(_ enabled: Bool) {
        updateSettings { $0.isCaptureEnabled = enabled }

        if !enabled {
            isAppendModeEnabled = false
        }

        showInfo(enabled ? "ChainCopy resumed." : "ChainCopy paused.")
    }

    func setAppendModeEnabled(_ enabled: Bool) {
        guard isCaptureEnabled || !enabled else {
            showError("Resume ChainCopy before turning on Append Mode.")
            return
        }

        isAppendModeEnabled = enabled
        showInfo(enabled ? "Append Mode on." : "Append Mode off.")
    }

    func applySeparatorPreset(_ preset: SeparatorPreset) {
        guard preset != .custom else {
            return
        }

        updateSettings { $0.separator = preset.separator }
    }

    func appendCurrentPasteboard() {
        let snapshot = snapshotProvider.snapshot()
        applyCaptureDecision(
            captureEngine.evaluate(
                snapshot: snapshot,
                method: .appendCurrentClipboard,
                existingItems: items,
                settings: currentSettings,
                ownWriteTracker: ownWriteTracker
            )
        )
    }

    func ingestCurrentPasteboardChange() {
        guard isCaptureEnabled, isAppendModeEnabled else {
            return
        }

        let snapshot = snapshotProvider.snapshot()
        ingest(snapshot: snapshot, method: .appendModeClipboardChange)
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

        applyCaptureDecision(
            decision,
            quietIgnoredReasons: [.captureDisabled, .ownWrite, .duplicateOfLatestItem]
        )

        return decision
    }

    @discardableResult
    func ingest(
        text: String,
        sourceAppName: String? = nil,
        sourceAppBundleIdentifier: String? = nil,
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
        let decision = captureEngine.evaluate(
            snapshot: snapshot,
            method: .manual,
            existingItems: items,
            settings: currentSettings,
            ownWriteTracker: ownWriteTracker
        )

        guard case .captured(let item) = decision, appendItem(item) else {
            return false
        }

        showInfo("Added snippet.")
        return true
    }

    func appendSelectedTextWithAutomation() async {
        refreshAccessibilityStatus()

        guard isAccessibilityTrusted else {
            hasSeenAccessibilityOnboarding = true
            showError("Accessibility needed. Press Cmd+C, then Append Clipboard.")
            return
        }

        let previousSnapshot = snapshotProvider.snapshot()
        let previousText = previousSnapshot.content.capturableText
        let previousChangeCount = previousSnapshot.changeCount

        keyEventSynthesizer.sendCopy()

        guard await waitForPasteboardChange(after: previousChangeCount, timeout: 1.0) else {
            showError("Copy timed out. Press Cmd+C, then Append Clipboard.")
            return
        }

        let newSnapshot = snapshotProvider.snapshot()
        let newText = newSnapshot.content.capturableText

        if items.isEmpty,
           let previousText,
           !previousText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           previousText != newText {
            applyCaptureDecision(
                captureEngine.evaluate(
                    snapshot: previousSnapshot,
                    method: .seedFromExistingClipboard,
                    existingItems: items,
                    settings: currentSettings,
                    ownWriteTracker: ownWriteTracker
                ),
                quietIgnoredReasons: [.captureDisabled, .ownWrite, .duplicateOfLatestItem]
            )
        }

        applyCaptureDecision(
            captureEngine.evaluate(
                snapshot: newSnapshot,
                method: .appendSelectedText,
                existingItems: items,
                settings: currentSettings,
                ownWriteTracker: ownWriteTracker
            )
        )
    }

    func copyComposedToPasteboard() {
        guard writeComposedToPasteboard() else {
            showError("No chain to copy.")
            return
        }

        showInfo("Copied joined block.")
    }

    func pasteComposedWithAutomation() async {
        guard writeComposedToPasteboard() else {
            showError("No chain to paste.")
            return
        }

        refreshAccessibilityStatus()

        guard isAccessibilityTrusted else {
            hasSeenAccessibilityOnboarding = true
            showInfo("Joined block copied. Press Cmd+V to paste.")
            return
        }

        keyEventSynthesizer.sendPaste()
        try? await Task.sleep(nanoseconds: 600_000_000)
        clear(showFeedback: false)
        showInfo("Pasted joined block and reset.")
    }

    func copyItemToPasteboard(_ item: ClipItem) {
        guard let changeCount = pasteboardWriter.writeString(item.text, ownedByChainCopy: true) else {
            showError("Could not copy snippet.")
            return
        }

        ownWriteTracker.record(changeCount: changeCount)
        showInfo("Copied snippet.")
    }

    func performShortcutAction(_ action: ShortcutAction) {
        switch action {
        case .appendSelectedText:
            Task {
                await appendSelectedTextWithAutomation()
            }
        case .appendCurrentClipboard:
            appendCurrentPasteboard()
        case .toggleCapture:
            setAppendModeEnabled(!isAppendModeEnabled)
        case .copyChain:
            copyComposedToPasteboard()
        case .pasteChain:
            Task {
                await pasteComposedWithAutomation()
            }
        case .showComposer:
            showComposerWindow()
        case .clearChain:
            clear()
        }
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = permissionService.isAccessibilityTrusted()
    }

    func requestAccessibilityPermission() {
        hasSeenAccessibilityOnboarding = true
        isAccessibilityTrusted = permissionService.isAccessibilityTrusted(prompt: true)
    }

    func openAccessibilitySettings() {
        hasSeenAccessibilityOnboarding = true
        permissionService.openAccessibilitySettings()
    }

    func dismissFeedback() {
        lastInfoMessage = nil
        lastErrorMessage = nil
    }

    func clear() {
        clear(showFeedback: true)
    }

    func handleApplicationWillTerminate() {
        guard settings.clearHistoryOnQuit else {
            return
        }

        clear(showFeedback: false)

        do {
            try persistence.clearItems()
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error
        }
    }

    func remove(_ item: ClipItem) {
        remove(id: item.id)
    }

    func remove(id: ClipItem.ID) {
        items.removeAll { $0.id == id }
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
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let sourceIndexes = source.sorted()
        let movingItems = sourceIndexes.map { items[$0] }

        for index in sourceIndexes.sorted(by: >) {
            items.remove(at: index)
        }

        let removedBeforeDestination = sourceIndexes.filter { $0 < destination }.count
        let adjustedDestination = destination - removedBeforeDestination
        let insertionIndex = min(max(adjustedDestination, 0), items.count)
        items.insert(contentsOf: movingItems, at: insertionIndex)
    }

    func move(_ item: ClipItem, direction: ChainMoveDirection) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        switch direction {
        case .up where index > items.startIndex:
            items.swapAt(index, items.index(before: index))
        case .down where index < items.index(before: items.endIndex):
            items.swapAt(index, items.index(after: index))
        default:
            break
        }
    }

    func ownsPasteboardText(_ text: String) -> Bool {
        false
    }

    private var currentSettings: ClipboardSettings {
        settings
    }

    private func applySettings(_ newSettings: ClipboardSettings) {
        let normalizedSettings = newSettings.normalized()

        settings = normalizedSettings
        isCaptureEnabled = normalizedSettings.isCaptureEnabled
        maxItemCount = normalizedSettings.maxItemCount
        separator = normalizedSettings.separator

        if !isCaptureEnabled {
            isAppendModeEnabled = false
        }

            self.enforceRetention()
            self.persistState()
    }

    private func appendItem(_ item: ClipItem) -> Bool {
        guard isCaptureEnabled else {
            showError("ChainCopy is paused.")
            return false
        }

        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if items.last?.contentHash == item.contentHash {
            return false
        }

        items.append(item)
        enforceRetention()

        return true
    }

    private func applyCaptureDecision(
        _ decision: CaptureDecision,
        quietIgnoredReasons: [CaptureRejectionReason] = []
    ) {
        switch decision {
        case .captured(let item):
            if appendItem(item) {
                showInfo("Added snippet.")
            }
        case .ignored(let reason):
            guard !quietIgnoredReasons.contains(reason) else {
                return
            }

            showIgnoredReason(reason)
        }
    }

    private func showIgnoredReason(_ reason: CaptureRejectionReason) {
        switch reason {
        case .captureDisabled:
            showError("ChainCopy is paused.")
        case .ownWrite:
            break
        case .privacy(let privacyReason):
            showError(message(for: privacyReason))
        case .unsupportedContent:
            showError("Clipboard content is not supported yet.")
        case .duplicateOfLatestItem:
            showInfo("Already the latest snippet.")
        }
    }

    private func message(for reason: ClipboardPrivacyFilterReason) -> String {
        switch reason {
        case .ignoredPasteboardType:
            return "Ignored a protected pasteboard type."
        case .ignoredSourceApp:
            return "Ignored clipboard from a protected app."
        case .emptyText:
            return "Clipboard text was empty."
        case .oversizedText:
            return "Clipboard text is larger than the current limit."
        case .sensitiveContentPattern:
            return "Ignored clipboard text matching a sensitive pattern."
        }
    }

    private func writeComposedToPasteboard() -> Bool {
        let text = composedText
        guard !text.isEmpty, let changeCount = pasteboardWriter.writeString(text, ownedByChainCopy: true) else {
            return false
        }

        ownWriteTracker.record(changeCount: changeCount)
        return true
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
        let retainedItems = Self.retainedItems(items, settings: settings)
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

    private func clear(showFeedback: Bool) {
        items.removeAll()

        if showFeedback {
            showInfo("Chain cleared.")
        }
    }

    private func showInfo(_ message: String) {
        lastErrorMessage = nil
        lastInfoMessage = message
    }

    private func showError(_ message: String) {
        lastInfoMessage = nil
        lastErrorMessage = message
    }

    private func waitForPasteboardChange(after oldChangeCount: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if snapshotProvider.changeCount != oldChangeCount {
                return true
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return snapshotProvider.changeCount != oldChangeCount
    }

    private static func retainedItems(_ items: [ClipItem], settings: ClipboardSettings) -> [ClipItem] {
        var retainedItems = items.filter { $0.text.utf8.count <= settings.maxItemSizeBytes }

        while retainedItems.count > settings.maxItemCount {
            if let removableIndex = retainedItems.firstIndex(where: { !$0.isPinned }) {
                retainedItems.remove(at: removableIndex)
            } else {
                retainedItems.removeFirst()
            }
        }

        return retainedItems
    }

    private func showComposerWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.title == "ChainCopy" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
