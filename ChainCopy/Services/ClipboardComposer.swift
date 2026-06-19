import Foundation

struct ClipboardComposer {
    func compose(_ fragments: [String], separator: String) -> String {
        fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}
