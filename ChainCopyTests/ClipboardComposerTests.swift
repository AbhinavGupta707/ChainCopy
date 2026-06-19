import XCTest
@testable import ChainCopy

final class ClipboardComposerTests: XCTestCase {
    func testComposeDropsEmptyFragmentsAndTrimsEdges() {
        let composer = ClipboardComposer()

        let result = composer.compose([" First ", "\n", "Second\n"], separator: "\n")

        XCTAssertEqual(result, "First\nSecond")
    }

    func testComposeUsesConfiguredSeparator() {
        let composer = ClipboardComposer()

        let result = composer.compose(["Alpha", "Beta", "Gamma"], separator: "\n\n")

        XCTAssertEqual(result, "Alpha\n\nBeta\n\nGamma")
    }

    func testComposeReturnsEmptyStringWhenNoUsableFragmentsExist() {
        let composer = ClipboardComposer()

        let result = composer.compose([" ", "\n"], separator: "\n")

        XCTAssertEqual(result, "")
    }
}
