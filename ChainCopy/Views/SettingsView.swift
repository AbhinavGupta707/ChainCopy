import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @State private var accessibilityTrusted = PermissionService().isAccessibilityTrusted()

    private var captureBinding: Binding<Bool> {
        Binding {
            store.isCaptureEnabled
        } set: { enabled in
            store.setCaptureEnabled(enabled)
        }
    }

    private var appendModeBinding: Binding<Bool> {
        Binding {
            store.isAppendModeEnabled
        } set: { enabled in
            store.setAppendModeEnabled(enabled)
        }
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "switch.2")
                }

            composeTab
                .tabItem {
                    Label("Compose", systemImage: "text.line.first.and.arrowtriangle.forward")
                }

            privacyTab
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 580, height: 420)
        .padding(20)
        .onAppear {
            accessibilityTrusted = PermissionService().isAccessibilityTrusted()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Capture") {
                Toggle("Capture enabled", isOn: captureBinding)
                Toggle("Append Mode", isOn: appendModeBinding)
                    .disabled(!store.isCaptureEnabled)
            }

            Section("Retention") {
                Stepper(value: $store.maxItemCount, in: 20...500, step: 20) {
                    Text("Keep \(store.maxItemCount) items")
                }
            }

            Section {
                Button(role: .destructive) {
                    store.clear()
                } label: {
                    Label("Clear Current Chain", systemImage: "trash")
                }
                .disabled(store.items.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private var composeTab: some View {
        Form {
            Section("Output") {
                SeparatorPicker(store: store)

                TextField("Custom separator", text: $store.separator)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Preview", value: store.separatorPreset.preview)
            }

            Section {
                Button {
                    store.copyComposedToPasteboard()
                } label: {
                    Label("Copy Joined Block", systemImage: "doc.on.clipboard")
                }
                .disabled(store.composedText.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private var privacyTab: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Accessibility", value: accessibilityTrusted ? "Granted" : "Needed for auto-paste")

                Button {
                    accessibilityTrusted = PermissionService().isAccessibilityTrusted(prompt: true)
                } label: {
                    Label("Enable Accessibility", systemImage: "hand.raised")
                }
                .disabled(accessibilityTrusted)

                Button("Check Again") {
                    accessibilityTrusted = PermissionService().isAccessibilityTrusted()
                }
            }

            Section("Local Data") {
                LabeledContent("Clipboard content persistence", value: "Off")
                LabeledContent("Cloud sync", value: "Off")
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsTab: some View {
        Form {
            Section("Default Actions") {
                ShortcutDisplayRow(title: "Append selected text", value: "Ctrl Cmd C")
                ShortcutDisplayRow(title: "Append current clipboard", value: "Ctrl Shift Cmd C")
                ShortcutDisplayRow(title: "Toggle Append Mode", value: "Ctrl Cmd A")
                ShortcutDisplayRow(title: "Copy joined block", value: "Ctrl Cmd V")
                ShortcutDisplayRow(title: "Clear chain", value: "Ctrl Cmd X")
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
}

private struct ShortcutDisplayRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent {
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        } label: {
            Text(title)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: ClipboardStore(items: PreviewData.clips))
    }
}
