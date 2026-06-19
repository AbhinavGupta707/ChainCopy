import Foundation

enum CaptureMethod: String, Codable, Hashable {
    case appendModeClipboardChange
    case appendCurrentClipboard
    case appendSelectedText
    case seedFromExistingClipboard
    case manual
}

struct ClipItem: Identifiable, Hashable, Codable {
    var id: UUID
    var text: String
    var capturedAt: Date
    var sourceAppName: String?
    var sourceAppBundleIdentifier: String?
    var captureMethod: CaptureMethod
    var contentHash: String
    var contentKind: PasteboardContentKind
    var pasteboardChangeCount: Int?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        capturedAt: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleIdentifier: String? = nil,
        captureMethod: CaptureMethod = .manual,
        contentHash: String? = nil,
        contentKind: PasteboardContentKind = .text,
        pasteboardChangeCount: Int? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
        self.sourceAppName = sourceAppName
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
        self.captureMethod = captureMethod
        self.contentHash = contentHash ?? ContentHasher.hash(text)
        self.contentKind = contentKind
        self.pasteboardChangeCount = pasteboardChangeCount
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
        max(text.components(separatedBy: .newlines).count, 1)
    }

    var sourceDisplayName: String {
        sourceAppName ?? "Unknown App"
    }

    var metadataSummary: String {
        "\(sourceDisplayName) - \(DateFormatting.shortTime.string(from: capturedAt)) - \(characterCount) chars"
    }
}

extension ClipItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case capturedAt
        case sourceAppName
        case sourceAppBundleIdentifier
        case captureMethod
        case contentHash
        case contentKind
        case pasteboardChangeCount
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""

        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            text: text,
            capturedAt: try container.decodeIfPresent(Date.self, forKey: .capturedAt) ?? Date(),
            sourceAppName: try container.decodeIfPresent(String.self, forKey: .sourceAppName),
            sourceAppBundleIdentifier: try container.decodeIfPresent(String.self, forKey: .sourceAppBundleIdentifier),
            captureMethod: try container.decodeIfPresent(CaptureMethod.self, forKey: .captureMethod) ?? .manual,
            contentHash: try container.decodeIfPresent(String.self, forKey: .contentHash) ?? ContentHasher.hash(text),
            contentKind: try container.decodeIfPresent(PasteboardContentKind.self, forKey: .contentKind) ?? .text,
            pasteboardChangeCount: try container.decodeIfPresent(Int.self, forKey: .pasteboardChangeCount),
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
        try container.encode(captureMethod, forKey: .captureMethod)
        try container.encode(contentHash, forKey: .contentHash)
        try container.encode(contentKind, forKey: .contentKind)
        try container.encodeIfPresent(pasteboardChangeCount, forKey: .pasteboardChangeCount)
        try container.encode(isPinned, forKey: .isPinned)
    }
}
