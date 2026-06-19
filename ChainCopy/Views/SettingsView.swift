import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var shortcutPreferences: ShortcutPreferences
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @State private var ignoredAppNamesText: String
    @State private var ignoredAppBundleIdentifiersText: String
    @State private var ignoredPasteboardTypesText: String
    @State private var sensitiveContentPatternsText: String

    init(
        store: ClipboardStore,
        shortcutPreferences: ShortcutPreferences,
        hotkeyManager: GlobalHotkeyManager
    ) {
        self.store = store
        self.shortcutPreferences = shortcutPreferences
        self.hotkeyManager = hotkeyManager
        _ignoredAppNamesText = State(initialValue: store.settings.ignoredAppNames.joined(separator: "\n"))
        _ignoredAppBundleIdentifiersText = State(initialValue: store.settings.ignoredAppBundleIdentifiers.joined(separator: "\n"))
        _ignoredPasteboardTypesText = State(initialValue: store.settings.ignoredPasteboardTypes.joined(separator: "\n"))
        _sensitiveContentPatternsText = State(initialValue: store.settings.sensitiveContentPatterns.joined(separator: "\n"))
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "switch.2")
                }

            privacyTab
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            automationTab
                .tabItem {
                    Label("Automation", systemImage: "cursorarrow.click")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 720, height: 560)
        .padding(20)
        .onAppear {
            store.refreshAccessibilityStatus()
        }
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

    private var generalTab: some View {
        Form {
            Toggle("Capture clipboard changes", isOn: captureBinding)
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
    }

    private var privacyTab: some View {
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
