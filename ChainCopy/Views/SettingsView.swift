import SwiftUI

@MainActor
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

            privacyTab
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 680, height: 560)
        .padding(20)
        .onAppear {
            store.refreshAccessibilityStatus()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Capture") {
                Toggle("Capture clipboard changes", isOn: captureBinding)

                Toggle("Persist clipboard contents locally", isOn: settingsBinding(\.persistClipboardContents))

                Toggle("Clear stored items on quit", isOn: settingsBinding(\.clearHistoryOnQuit))
            }

            Section("Retention") {
                Stepper(value: settingsBinding(\.maxItemCount), in: 1...500, step: 10) {
                    Text("Keep \(store.maxItemCount) items")
                }

                Stepper(value: settingsBinding(\.maxItemSizeBytes), in: 1_024...10_000_000, step: 1_024) {
                    Text("Max item size \(formattedByteCount(store.maxItemSizeBytes))")
                }
            }

            Section("Compose") {
                SeparatorPicker(store: store)
            }
        }
        .formStyle(.grouped)
    }

    private var privacyTab: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Accessibility", value: store.isAccessibilityTrusted ? "Granted" : "Needed for auto-paste")

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

            Section("Ignored Sources") {
                MultilineSettingsField(
                    title: "Ignored app names",
                    text: linesBinding(\.ignoredAppNames)
                )

                MultilineSettingsField(
                    title: "Ignored bundle IDs",
                    text: linesBinding(\.ignoredAppBundleIdentifiers)
                )
            }

            Section("Ignored Content") {
                MultilineSettingsField(
                    title: "Ignored pasteboard types",
                    text: linesBinding(\.ignoredPasteboardTypes)
                )

                MultilineSettingsField(
                    title: "Sensitive text patterns",
                    text: linesBinding(\.sensitiveContentPatterns)
                )
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

    private var aboutTab: some View {
        Form {
            LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.abhinavgupta.ChainCopy")
            LabeledContent("Minimum macOS", value: "14.0")
            LabeledContent("Distribution", value: "Direct download")
            LabeledContent("Cloud Sync", value: "Off")
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

    private func settingsBinding<Value>(
        _ keyPath: WritableKeyPath<ClipboardSettings, Value>
    ) -> Binding<Value> {
        Binding {
            store.settings[keyPath: keyPath]
        } set: { value in
            store.updateSettings {
                $0[keyPath: keyPath] = value
            }
        }
    }

    private func linesBinding(
        _ keyPath: WritableKeyPath<ClipboardSettings, [String]>
    ) -> Binding<String> {
        Binding {
            store.settings[keyPath: keyPath].joined(separator: "\n")
        } set: { value in
            store.updateSettings {
                $0[keyPath: keyPath] = ClipboardSettings.sanitizedLines(from: value)
            }
        }
    }

    private func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

private struct MultilineSettingsField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)

            TextEditor(text: $text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 68)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary)
                }
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
                .frame(width: 110, alignment: .leading)

            Button("Default") {
                shortcutPreferences.reset(action)
            }
            .controlSize(.small)
        }
    }

    private var statusStyle: some ShapeStyle {
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
