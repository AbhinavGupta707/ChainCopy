import Foundation

enum PasteAutomationOutcome: Equatable {
    case pasted
    case permissionRequired
}

struct PasteAutomationService {
    private let permissionService: AccessibilityPermissionServicing
    private let keyEventSynthesizer: KeyEventSynthesizing

    init(
        permissionService: AccessibilityPermissionServicing = PermissionService(),
        keyEventSynthesizer: KeyEventSynthesizing = CGKeyEventSynthesizer()
    ) {
        self.permissionService = permissionService
        self.keyEventSynthesizer = keyEventSynthesizer
    }

    func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        permissionService.isAccessibilityTrusted(prompt: prompt)
    }

    func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    func sendPasteIfPermitted() -> PasteAutomationOutcome {
        guard isAccessibilityTrusted() else {
            return .permissionRequired
        }

        keyEventSynthesizer.sendPaste()
        return .pasted
    }
}
