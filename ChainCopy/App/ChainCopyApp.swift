import SwiftUI

@MainActor
@main
struct ChainCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store: ClipboardStore
    @StateObject private var shortcutPreferences: ShortcutPreferences
    @StateObject private var hotkeyManager: GlobalHotkeyManager
    @State private var pasteboardMonitor = PasteboardMonitor()

    init() {
        let store = ClipboardStore()
        let shortcutPreferences = ShortcutPreferences()
        let hotkeyManager = GlobalHotkeyManager()

        _store = StateObject(wrappedValue: store)
        _shortcutPreferences = StateObject(wrappedValue: shortcutPreferences)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)

        Task { @MainActor in
            hotkeyManager.start(preferences: shortcutPreferences) { action in
                store.performShortcutAction(action)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra("ChainCopy", systemImage: "link.badge.plus") {
            MenuBarView(store: store)
                .frame(width: 420)
                .onAppear {
                    pasteboardMonitor.start(store: store)
                }
        }
        .menuBarExtraStyle(.window)

        WindowGroup("ChainCopy", id: "main") {
            RootView(store: store)
                .onAppear {
                    pasteboardMonitor.start(store: store)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 860, height: 560)

        Settings {
            SettingsView(
                store: store,
                shortcutPreferences: shortcutPreferences,
                hotkeyManager: hotkeyManager
            )
        }
    }
}
