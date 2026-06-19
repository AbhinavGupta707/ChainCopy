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

    @Published var separator: String {
        didSet {
            updateSettingFromLegacyBinding { settings in
                settings.separator = separator
            }
        }
    }

    @Published private(set) var settings: ClipboardSettings
    @Published private(set) var lastPersistenceError: Error?

    private let composer: ClipboardComposer
    private let persistence: any ClipboardPersistence
    private let privacyFilter: ClipboardPrivacyFilter
    private var lastPasteboardWrite: String?
    private var isReadyToPersist = false
    private var isApplyingRetention = false
    private var isApplyingSettings = false
    private var terminationObserver: NSObjectProtocol?

    init(
        items: [ClipItem]? = nil,
        isCaptureEnabled: Bool? = nil,
        maxItemCount: Int? = nil,
        separator: String? = nil,
        settings: ClipboardSettings? = nil,
        composer: ClipboardComposer = ClipboardComposer(),
        persistence: any ClipboardPersistence = FileClipboardPersistenceStore.applicationSupportStore(),
        privacyFilter: ClipboardPrivacyFilter = ClipboardPrivacyFilter()
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

        self.items = PersistedClipboardState.retainedItems(resolvedItems, settings: resolvedSettings)
        self.isCaptureEnabled = resolvedSettings.isCaptureEnabled
        self.maxItemCount = resolvedSettings.maxItemCount
        self.separator = resolvedSettings.separator
        self.settings = resolvedSettings
        self.composer = composer
        self.persistence = persistence
        self.privacyFilter = privacyFilter
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
        pasteboardTypes: Set<String> = [NSPasteboard.PasteboardType.string.rawValue]
    ) -> Bool {
        guard isCaptureEnabled else {
            return false
        }

        let inspection = PasteboardInspection(
            types: pasteboardTypes,
            sourceAppName: sourceAppName,
            sourceAppBundleIdentifier: sourceAppBundleIdentifier,
            text: text
        )
        guard privacyFilter.decision(for: inspection, settings: settings).isAllowed else {
            return false
        }

        guard items.first?.text != text else {
            return false
        }

        items.insert(
            ClipItem(
                text: text,
                sourceAppName: sourceAppName,
                sourceAppBundleIdentifier: sourceAppBundleIdentifier
            ),
            at: 0
        )

        return true
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
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
        let text = composedText
        guard !text.isEmpty else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastPasteboardWrite = text
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
