import AppKit
import Foundation

@MainActor
protocol PasteboardStringWriting {
    @discardableResult
    func writeString(_ text: String, ownedByChainCopy: Bool) -> Int?
}

@MainActor
final class NSPasteboardStringWriter: PasteboardStringWriting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    func writeString(_ text: String, ownedByChainCopy: Bool = true) -> Int? {
        var types: [NSPasteboard.PasteboardType] = [.string]

        if ownedByChainCopy {
            types.append(.chainCopyOwnedWrite)
        }

        pasteboard.clearContents()
        pasteboard.declareTypes(types, owner: nil)

        guard pasteboard.setString(text, forType: .string) else {
            return nil
        }

        if ownedByChainCopy {
            pasteboard.setString(UUID().uuidString, forType: .chainCopyOwnedWrite)
        }

        return pasteboard.changeCount
    }
}
