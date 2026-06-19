import Foundation

enum PasteboardContentKind: String, Codable, Hashable {
    case text
    case url
    case fileURLs
    case richText
    case unsupported
}

struct PasteboardContent: Equatable {
    var kind: PasteboardContentKind
    var text: String?
    var fileURLs: [URL]
    var typeNames: Set<String>

    var capturableText: String? {
        text
    }

    var byteCount: Int {
        text?.utf8.count ?? 0
    }

    static func plainText(_ text: String, types: Set<String> = [PasteboardTypeNames.string]) -> PasteboardContent {
        PasteboardContent(kind: .text, text: text, fileURLs: [], typeNames: types)
    }

    static func url(_ url: URL, types: Set<String> = [PasteboardTypeNames.url]) -> PasteboardContent {
        PasteboardContent(kind: .url, text: url.absoluteString, fileURLs: [], typeNames: types)
    }

    static func fileURLs(_ urls: [URL], types: Set<String> = [PasteboardTypeNames.fileURL]) -> PasteboardContent {
        PasteboardContent(
            kind: .fileURLs,
            text: urls.map(\.path).joined(separator: "\n"),
            fileURLs: urls,
            typeNames: types
        )
    }

    static func richTextPlaceholder(types: Set<String>) -> PasteboardContent {
        PasteboardContent(kind: .richText, text: nil, fileURLs: [], typeNames: types)
    }

    static func unsupported(types: Set<String>) -> PasteboardContent {
        PasteboardContent(kind: .unsupported, text: nil, fileURLs: [], typeNames: types)
    }
}
