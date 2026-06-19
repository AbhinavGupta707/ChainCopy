import SwiftUI

@main
struct ChainCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store = ClipboardStore()
    @State private var pasteboardMonitor = PasteboardMonitor()

    var body: some Scene {
        MenuBarExtra("ChainCopy", systemImage: "link.badge.plus") {
            MenuBarView(store: store)
                .frame(width: 380)
                .onAppear {
                    pasteboardMonitor.start(store: store)
                }
        }
        .menuBarExtraStyle(.window)

        WindowGroup("ChainCopy", id: "main") {
            RootView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 860, height: 560)

        Settings {
            SettingsView(store: store)
        }
    }
}
