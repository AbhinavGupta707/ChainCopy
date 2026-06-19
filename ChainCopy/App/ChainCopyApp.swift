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
                .frame(width: 390)
                .onAppear {
                    pasteboardMonitor.start(store: store)
                }
        } label: {
            Label(store.menuBarDisplayTitle, systemImage: store.menuBarSystemImage)
                .background(hotkeyLifecycle)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("ChainCopy", id: "main") {
            RootView(store: store)
                .background(hotkeyLifecycle)
        }
        .commands {
            CommandMenu("Chain") {
                Button("Append Clipboard") {
                    store.appendCurrentPasteboard()
                }
                .keyboardShortcut("c", modifiers: [.control, .command, .shift])
                .disabled(!store.isCaptureEnabled)

                Button(store.isAppendModeEnabled ? "Turn Append Mode Off" : "Turn Append Mode On") {
                    store.setAppendModeEnabled(!store.isAppendModeEnabled)
                }
                .keyboardShortcut("a", modifiers: [.control, .command])
                .disabled(!store.isCaptureEnabled)

                Divider()

                Button("Copy Chain") {
                    store.copyComposedToPasteboard()
                }
                .keyboardShortcut("v", modifiers: [.control, .command, .shift])
                .disabled(store.composedText.isEmpty)

                Button("Paste Chain") {
                    store.pasteComposedWithAutomation()
                }
                .keyboardShortcut("v", modifiers: [.control, .command])
                .disabled(store.composedText.isEmpty)

                Button("Clear Chain") {
                    store.clear()
                }
                .keyboardShortcut("x", modifiers: [.control, .command])
                .disabled(store.items.isEmpty)

                Divider()

                Button(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy") {
                    store.setCaptureEnabled(!store.isCaptureEnabled)
                }
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
