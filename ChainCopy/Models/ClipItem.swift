import Foundation

struct ClipItem: Identifiable, Hashable, Codable {
    var id: UUID
    var text: String
    var capturedAt: Date
    var sourceAppName: String?
    var sourceAppBundleIdentifier: String?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        capturedAt: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleIdentifier: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
        self.sourceAppName = sourceAppName
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
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
}

extension ClipItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case capturedAt
        case sourceAppName
        case sourceAppBundleIdentifier
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            text: try container.decodeIfPresent(String.self, forKey: .text) ?? "",
            capturedAt: try container.decodeIfPresent(Date.self, forKey: .capturedAt) ?? Date(),
            sourceAppName: try container.decodeIfPresent(String.self, forKey: .sourceAppName),
            sourceAppBundleIdentifier: try container.decodeIfPresent(String.self, forKey: .sourceAppBundleIdentifier),
            isPinned: try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try container.encodeIfPresent(sourceAppBundleIdentifier, forKey: .sourceAppBundleIdentifier)
        try container.encode(isPinned, forKey: .isPinned)
    }
}
