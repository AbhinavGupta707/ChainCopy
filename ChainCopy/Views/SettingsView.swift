import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @State private var ignoredAppNamesText: String
    @State private var ignoredAppBundleIdentifiersText: String
    @State private var ignoredPasteboardTypesText: String
    @State private var sensitiveContentPatternsText: String

    init(store: ClipboardStore) {
        self.store = store
        _ignoredAppNamesText = State(initialValue: store.settings.ignoredAppNames.joined(separator: "\n"))
        _ignoredAppBundleIdentifiersText = State(initialValue: store.settings.ignoredAppBundleIdentifiers.joined(separator: "\n"))
        _ignoredPasteboardTypesText = State(initialValue: store.settings.ignoredPasteboardTypes.joined(separator: "\n"))
        _sensitiveContentPatternsText = State(initialValue: store.settings.sensitiveContentPatterns.joined(separator: "\n"))
    }

    var body: some View {
        TabView {
            Form {
                Toggle("Capture clipboard changes", isOn: $store.isCaptureEnabled)
                Toggle("Ignore adjacent duplicates", isOn: $store.suppressAdjacentDuplicates)

                Picker("Separator", selection: $store.separator) {
                    Text("Blank Line").tag("\n\n")
                    Text("New Line").tag("\n")
                    Text("Space").tag(" ")
                }

                Stepper(value: $store.maxItemCount, in: 1...500, step: 10) {
                    Text("Keep \(store.maxItemCount) items")
                }

                Stepper(value: maxItemSizeBinding, in: 1_024...10_000_000, step: 1_024) {
                    Text("Max item size \(formattedByteCount(store.maxItemSizeBytes))")
                }

                Toggle("Save clipboard contents locally", isOn: persistClipboardContentsBinding)
                Toggle("Clear stored items on quit", isOn: clearHistoryOnQuitBinding)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "switch.2")
            }

            Form {
                privacyTextEditor("Ignored app names", text: $ignoredAppNamesText)
                privacyTextEditor("Ignored bundle identifiers", text: $ignoredAppBundleIdentifiersText)
                privacyTextEditor("Ignored pasteboard types", text: $ignoredPasteboardTypesText)
                privacyTextEditor("Sensitive text patterns", text: $sensitiveContentPatternsText)

                Button(role: .destructive) {
                    store.clear()
                } label: {
                    Label("Clear Current Chain", systemImage: "trash")
                }
                .disabled(store.items.isEmpty)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }

            Form {
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.abhinavgupta.ChainCopy")
                LabeledContent("Minimum macOS", value: "14.0")
                LabeledContent("Distribution", value: "Direct download")
                LabeledContent("Cloud Sync", value: "Off")
                LabeledContent("License provider", value: "Not configured")
            }
            .formStyle(.grouped)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 520, height: 520)
        .padding(20)
        .onChange(of: ignoredAppNamesText) { _, newValue in
            store.updateSettings { settings in
                settings.ignoredAppNames = ClipboardSettings.sanitizedLines(from: newValue)
            }
        }
        .onChange(of: ignoredAppBundleIdentifiersText) { _, newValue in
            store.updateSettings { settings in
                settings.ignoredAppBundleIdentifiers = ClipboardSettings.sanitizedLines(from: newValue)
            }
        }
        .onChange(of: ignoredPasteboardTypesText) { _, newValue in
            store.updateSettings { settings in
                settings.ignoredPasteboardTypes = ClipboardSettings.sanitizedLines(from: newValue)
            }
        }
        .onChange(of: sensitiveContentPatternsText) { _, newValue in
            store.updateSettings { settings in
                settings.sensitiveContentPatterns = ClipboardSettings.sanitizedLines(from: newValue)
            }
        }
    }

    private var persistClipboardContentsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.persistClipboardContents },
            set: { newValue in
                store.updateSettings { settings in
                    settings.persistClipboardContents = newValue
                }
            }
        )
    }

    private var clearHistoryOnQuitBinding: Binding<Bool> {
        Binding(
            get: { store.settings.clearHistoryOnQuit },
            set: { newValue in
                store.updateSettings { settings in
                    settings.clearHistoryOnQuit = newValue
                }
            }
        )
    }

    private var maxItemSizeBinding: Binding<Int> {
        Binding(
            get: { store.settings.maxItemSizeBytes },
            set: { newValue in
                store.updateSettings { settings in
                    settings.maxItemSizeBytes = newValue
                }
            }
        )
    }

    private func privacyTextEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 58, idealHeight: 72)
                .scrollContentBackground(.hidden)
                .background(.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(store: ClipboardStore(items: PreviewData.clips))
    }
}
