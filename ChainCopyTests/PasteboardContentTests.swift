import XCTest
@testable import ChainCopy

final class PasteboardContentTests: XCTestCase {
    func testModelsPlainText() {
        let content = PasteboardContent.plainText("Alpha")

        XCTAssertEqual(content.kind, .text)
        XCTAssertEqual(content.capturableText, "Alpha")
        XCTAssertEqual(content.byteCount, 5)
    }

    func testModelsURLAsCapturableText() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/path"))
        let content = PasteboardContent.url(url)

        XCTAssertEqual(content.kind, .url)
        XCTAssertEqual(content.capturableText, "https://example.com/path")
    }

    func testModelsFileURLsAsJoinedPaths() {
        let content = PasteboardContent.fileURLs([
            URL(fileURLWithPath: "/tmp/Alpha.txt"),
            URL(fileURLWithPath: "/tmp/Beta.txt")
        ])

        XCTAssertEqual(content.kind, .fileURLs)
        XCTAssertEqual(content.capturableText, "/tmp/Alpha.txt\n/tmp/Beta.txt")
        XCTAssertEqual(content.fileURLs.count, 2)
    }

    func testModelsRichTextAsPlaceholderWithoutCapturableText() {
        let content = PasteboardContent.richTextPlaceholder(types: [PasteboardTypeNames.rtf])

        XCTAssertEqual(content.kind, .richText)
        XCTAssertNil(content.capturableText)
    }

    func testModelsUnsupportedContentWithoutCapturableText() {
        let content = PasteboardContent.unsupported(types: ["public.tiff"])

        XCTAssertEqual(content.kind, .unsupported)
        XCTAssertNil(content.capturableText)
    }
}
