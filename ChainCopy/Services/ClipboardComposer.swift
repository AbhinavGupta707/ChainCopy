import Foundation

struct ClipboardComposer {
    func compose(_ fragments: [String], separator: String) -> String {
        let cleanedFragments = fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if separator == SeparatorPreset.bullets.separator {
            return cleanedFragments
                .map { "- " + $0 }
                .joined(separator: "\n")
        }

        return cleanedFragments.joined(separator: separator)
    }
}
