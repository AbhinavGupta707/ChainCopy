import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [ClipItem]
    @Published var isCaptureEnabled: Bool
    @Published var isAppendModeEnabled: Bool
    @Published var maxItemCount: Int
    @Published var separator: String
    @Published var lastInfoMessage: String?
    @Published var lastErrorMessage: String?

    private let composer: ClipboardComposer
    private var lastPasteboardWrite: String?

    init(
        items: [ClipItem] = [],
        isCaptureEnabled: Bool = true,
        isAppendModeEnabled: Bool = false,
        maxItemCount: Int = 200,
        separator: String = "\n\n"
    ) {
        self.items = items
        self.isCaptureEnabled = isCaptureEnabled
        self.isAppendModeEnabled = isAppendModeEnabled
        self.maxItemCount = maxItemCount
        self.separator = separator
        self.composer = ClipboardComposer()
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

    func ingest(
        text: String,
        sourceAppName: String? = NSWorkspace.shared.frontmostApplication?.localizedName,
        requiresAppendMode: Bool = true
    ) {
        guard isCaptureEnabled, !requiresAppendMode || isAppendModeEnabled else {
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

        lastErrorMessage = nil
        lastInfoMessage = "Added \(items.count == 1 ? "first snippet" : "\(items.count) snippets")"
    }

    func appendCurrentPasteboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            lastErrorMessage = "The current clipboard does not contain text."
            return
        }

        ingest(text: text, requiresAppendMode: false)
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        lastInfoMessage = "Removed snippet"
    }

    func clear() {
        items.removeAll()
        lastInfoMessage = "Chain cleared"
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

    func setCaptureEnabled(_ enabled: Bool) {
        isCaptureEnabled = enabled
        if !enabled {
            isAppendModeEnabled = false
            lastInfoMessage = "ChainCopy paused"
        } else {
            lastInfoMessage = "ChainCopy resumed"
        }
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

        writeToPasteboard(text)
        lastInfoMessage = "Copied joined block"
        lastErrorMessage = nil
    }

    func copyItemToPasteboard(_ item: ClipItem) {
        writeToPasteboard(item.text)
        lastInfoMessage = "Copied snippet"
        lastErrorMessage = nil
    }

    func dismissFeedback() {
        lastInfoMessage = nil
        lastErrorMessage = nil
    }

    func ownsPasteboardText(_ text: String) -> Bool {
        text == lastPasteboardWrite
    }

    private func writeToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastPasteboardWrite = text
    }
}

enum ChainMoveDirection {
    case up
    case down
}
