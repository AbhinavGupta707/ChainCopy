import XCTest
@testable import ChainCopy

final class PasteAutomationServiceTests: XCTestCase {
    func testPasteIsNotSynthesizedWithoutAccessibilityPermission() {
        let permissionService = FakePermissionService(isTrusted: false)
        let keyEventSynthesizer = RecordingKeyEventSynthesizer()
        let service = PasteAutomationService(
            permissionService: permissionService,
            keyEventSynthesizer: keyEventSynthesizer
        )

        let outcome = service.sendPasteIfPermitted()

        XCTAssertEqual(outcome, .permissionRequired)
        XCTAssertEqual(keyEventSynthesizer.pasteCount, 0)
    }

    func testPasteIsSynthesizedWhenAccessibilityPermissionIsGranted() {
        let permissionService = FakePermissionService(isTrusted: true)
        let keyEventSynthesizer = RecordingKeyEventSynthesizer()
        let service = PasteAutomationService(
            permissionService: permissionService,
            keyEventSynthesizer: keyEventSynthesizer
        )

        let outcome = service.sendPasteIfPermitted()

        XCTAssertEqual(outcome, .pasted)
        XCTAssertEqual(keyEventSynthesizer.pasteCount, 1)
    }

    func testPermissionPromptFlagIsPassedThrough() {
        let permissionService = FakePermissionService(isTrusted: false)
        let service = PasteAutomationService(permissionService: permissionService)

        _ = service.isAccessibilityTrusted(prompt: true)

        XCTAssertEqual(permissionService.promptValues, [true])
    }
}

private final class FakePermissionService: AccessibilityPermissionServicing {
    var isTrusted: Bool
    var promptValues: [Bool] = []
    private(set) var didOpenSettings = false

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        promptValues.append(prompt)
        return isTrusted
    }

    func openAccessibilitySettings() {
        didOpenSettings = true
    }
}

private final class RecordingKeyEventSynthesizer: KeyEventSynthesizing {
    private(set) var pasteCount = 0

    func sendPaste() {
        pasteCount += 1
    }
}
