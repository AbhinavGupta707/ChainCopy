import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [ClipItem]
    @Published var isCaptureEnabled: Bool
    @Published var maxItemCount: Int
    @Published var separator: String
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var lastPasteAutomationResult: PasteAutomationResult?

    private let composer: ClipboardComposer
    private let pasteAutomationService: PasteAutomationService
    private var lastPasteboardWrite: String?

    init(
        items: [ClipItem] = [],
        isCaptureEnabled: Bool = true,
        maxItemCount: Int = 200,
        separator: String = "\n",
        pasteAutomationService: PasteAutomationService = PasteAutomationService()
    ) {
        self.items = items
        self.isCaptureEnabled = isCaptureEnabled
        self.maxItemCount = maxItemCount
        self.separator = separator
        self.composer = ClipboardComposer()
        self.pasteAutomationService = pasteAutomationService
        self.isAccessibilityTrusted = pasteAutomationService.isAccessibilityTrusted()
    }

    var composedText: String {
        composer.compose(items.map(\.text), separator: separator)
    }

    var composedCharacterCount: Int {
        composedText.count
    }

    func ingest(text: String, sourceAppName: String? = NSWorkspace.shared.frontmostApplication?.localizedName) {
        guard isCaptureEnabled else {
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        guard items.first?.text != text else {
            return
        }

        items.insert(ClipItem(text: text, sourceAppName: sourceAppName), at: 0)

        if items.count > maxItemCount {
            items.removeLast(items.count - maxItemCount)
        }
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

    @discardableResult
    func pasteComposedWithAutomation() -> PasteAutomationResult {
        let text = composedText
        guard !text.isEmpty else {
            lastPasteAutomationResult = .emptyChain
            return .emptyChain
        }

        copyComposedToPasteboard()
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
