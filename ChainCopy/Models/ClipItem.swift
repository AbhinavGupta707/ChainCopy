import Foundation

struct ClipItem: Identifiable, Hashable, Codable {
    var id: UUID
    var text: String
    var capturedAt: Date
    var sourceAppName: String?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        capturedAt: Date = Date(),
        sourceAppName: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
        self.sourceAppName = sourceAppName
        self.isPinned = isPinned
    }

    var previewTitle: String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.count > 72 else {
            return collapsed.isEmpty ? "Empty text" : collapsed
        }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: 72)
        return String(collapsed[..<endIndex]) + "..."
    }

    var characterCount: Int {
        text.count
    }

    var lineCount: Int {
        max(1, text.split(whereSeparator: \.isNewline).count)
    }

    var sourceDisplayName: String {
        sourceAppName ?? "Unknown App"
    }

    var metadataSummary: String {
        "\(sourceDisplayName) - \(DateFormatting.shortTime.string(from: capturedAt)) - \(characterCount) chars"
    }
}
