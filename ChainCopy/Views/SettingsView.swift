import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var shortcutPreferences: ShortcutPreferences
    @ObservedObject var hotkeyManager: GlobalHotkeyManager

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "switch.2")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            automationTab
                .tabItem {
                    Label("Automation", systemImage: "hand.raised")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 680, height: 520)
        .padding(20)
        .onAppear {
            store.refreshAccessibilityStatus()
        }
    }

    private var generalTab: some View {
        Form {
            Toggle("Capture clipboard changes", isOn: captureBinding)

            Picker("Separator", selection: $store.separator) {
                Text("New Line").tag("\n")
                Text("Blank Line").tag("\n\n")
                Text("Space").tag(" ")
            }

            Stepper(value: $store.maxItemCount, in: 20...500, step: 20) {
                Text("Keep \(store.maxItemCount) items")
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsTab: some View {
        Form {
            Section("Global Shortcuts") {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                    ForEach(ShortcutAction.allCases) { action in
                        ShortcutSettingsRow(
                            action: action,
                            shortcutPreferences: shortcutPreferences,
                            hotkeyManager: hotkeyManager
                        )
                    }
                }
            }

            Section {
                Button("Reset Shortcuts") {
                    shortcutPreferences.resetAll()
                }
            } footer: {
                Text("Click a shortcut field, press a new key combination, or press Delete while recording to disable it.")
            }
        }
        .formStyle(.grouped)
    }

    private var automationTab: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Auto-paste", value: store.isAccessibilityTrusted ? "Granted" : "Manual paste fallback")

                Button {
                    store.requestAccessibilityPermission()
                } label: {
                    Label("Enable Accessibility", systemImage: "hand.raised")
                }
                .disabled(store.isAccessibilityTrusted)

                Button {
                    store.openAccessibilitySettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }

                Button("Check Again") {
                    store.refreshAccessibilityStatus()
                }
            }

            if let result = store.lastPasteAutomationResult {
                Section("Last Paste Action") {
                    Text(result.message)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        Form {
            LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.abhinavgupta.ChainCopy")
            LabeledContent("Minimum macOS", value: "14.0")
            LabeledContent("Distribution", value: "Direct download")
            LabeledContent("License provider", value: "Not configured")
        }
        .formStyle(.grouped)
    }

    private var captureBinding: Binding<Bool> {
        Binding {
            store.isCaptureEnabled
        } set: { enabled in
            store.setCaptureEnabled(enabled)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            store: ClipboardStore(items: PreviewData.clips),
            shortcutPreferences: ShortcutPreferences(),
            hotkeyManager: GlobalHotkeyManager()
        )
    }
}

private struct ShortcutSettingsRow: View {
    let action: ShortcutAction
    @ObservedObject var shortcutPreferences: ShortcutPreferences
    @ObservedObject var hotkeyManager: GlobalHotkeyManager

    private var shortcutBinding: Binding<HotkeyShortcut?> {
        Binding {
            shortcutPreferences.shortcut(for: action)
        } set: { shortcut in
            shortcutPreferences.setShortcut(shortcut, for: action)
        }
    }

    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.callout)

                Text(action.settingsDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(minWidth: 220, alignment: .leading)

            ShortcutRecorderView(shortcut: shortcutBinding)
                .frame(width: 164, height: 28)

            Text(hotkeyManager.displayStatus(for: action))
                .font(.caption)
                .foregroundStyle(statusStyle)
                .frame(width: 120, alignment: .leading)

            Button("Default") {
                shortcutPreferences.reset(action)
            }
            .controlSize(.small)
        }
    }

    private var statusStyle: AnyShapeStyle {
        if shortcutPreferences.conflictingActions.contains(action) {
            return AnyShapeStyle(.red)
        }

        switch hotkeyManager.statuses[action] {
        case .registered:
            return AnyShapeStyle(.green)
        case .disabled:
            return AnyShapeStyle(.secondary)
        case .conflict, .invalid, .failed:
            return AnyShapeStyle(.red)
        case nil:
            return AnyShapeStyle(.secondary)
        }
    }
}
