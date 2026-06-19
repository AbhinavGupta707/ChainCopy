import SwiftUI

@main
struct ChainCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store = ClipboardStore()
    @StateObject private var shortcutPreferences = ShortcutPreferences()
    @StateObject private var hotkeyManager = GlobalHotkeyManager()
    @State private var pasteboardMonitor = PasteboardMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .background(hotkeyLifecycle)
                .frame(width: 380)
                .onAppear {
                    pasteboardMonitor.start(store: store)
                }
        } label: {
            Label("ChainCopy", systemImage: "link.badge.plus")
                .background(hotkeyLifecycle)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("ChainCopy", id: "main") {
            RootView(store: store)
                .background(hotkeyLifecycle)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 860, height: 560)

        Settings {
            SettingsView(
                store: store,
                shortcutPreferences: shortcutPreferences,
                hotkeyManager: hotkeyManager
            )
            .background(hotkeyLifecycle)
        }
    }

    private var hotkeyLifecycle: some View {
        HotkeyLifecycleView(
            store: store,
            shortcutPreferences: shortcutPreferences,
            hotkeyManager: hotkeyManager
        )
    }
}
