import AppKit
import Foundation

@MainActor
protocol PasteboardSnapshotProviding {
    var changeCount: Int { get }
    func snapshot() -> PasteboardCaptureSnapshot
}

@MainActor
final class NSPasteboardSnapshotProvider: PasteboardSnapshotProviding {
    private let pasteboard: NSPasteboard
    private let sourceApplicationProvider: any SourceApplicationProviding

    init(
        pasteboard: NSPasteboard = .general,
        sourceApplicationProvider: any SourceApplicationProviding = NSWorkspaceSourceApplicationProvider()
    ) {
        self.pasteboard = pasteboard
        self.sourceApplicationProvider = sourceApplicationProvider
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func snapshot() -> PasteboardCaptureSnapshot {
        let types = Set((pasteboard.types ?? []).map(\.rawValue))

        return PasteboardCaptureSnapshot(
            changeCount: pasteboard.changeCount,
            types: types,
            content: readContent(types: types),
            sourceApplication: sourceApplicationProvider.frontmostApplication()
        )
    }

    private func readContent(types: Set<String>) -> PasteboardContent {
        if types.contains(PasteboardTypeNames.fileURL), let urls = readURLs(fileURLsOnly: true), !urls.isEmpty {
            return .fileURLs(urls, types: types)
        }

        if types.contains(PasteboardTypeNames.url), let url = readURL() {
            return .url(url, types: types)
        }

        if let text = pasteboard.string(forType: .string) {
            return .plainText(text, types: types)
        }

        if !types.isDisjoint(with: PasteboardTypeNames.richTextTypes) {
            return .richTextPlaceholder(types: types)
        }

        return .unsupported(types: types)
    }

    private func readURL() -> URL? {
        if let urls = readURLs(fileURLsOnly: false), let url = urls.first, !url.isFileURL {
            return url
        }

        guard let urlString = pasteboard.string(forType: .URL) else {
            return nil
        }

        return URL(string: urlString)
    }

    private func readURLs(fileURLsOnly: Bool) -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: fileURLsOnly
        ]

        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] else {
            return nil
        }

        return objects.map { $0 as URL }
    }
}
