import ApplicationServices
import AppKit
import Foundation

protocol AccessibilityPermissionServicing {
    func isAccessibilityTrusted(prompt: Bool) -> Bool
    func openAccessibilitySettings()
}

struct PermissionService: AccessibilityPermissionServicing {
    func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
