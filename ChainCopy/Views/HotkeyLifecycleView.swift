import AppKit
import SwiftUI

@MainActor
struct HotkeyLifecycleView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var shortcutPreferences: ShortcutPreferences
    @ObservedObject var hotkeyManager: GlobalHotkeyManager

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                hotkeyManager.start(preferences: shortcutPreferences) { action in
                    handle(action)
                }
            }
    }

    private func handle(_ action: ShortcutAction) {
        switch action {
        case .toggleCapture:
            store.setAppendModeEnabled(!store.isAppendModeEnabled)
        case .copyChain:
            store.copyComposedToPasteboard()
        case .pasteChain:
            store.pasteComposedWithAutomation()
        case .showComposer:
            showComposer()
        case .clearChain:
            store.clear()
        }
    }

    private func showComposer() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
