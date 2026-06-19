import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ClipboardStore
    @Environment(\.openWindow) private var openWindow

    private var appendModeBinding: Binding<Bool> {
        Binding {
            store.isAppendModeEnabled
        } set: { enabled in
            store.setAppendModeEnabled(enabled)
        }
    }

    private var captureBinding: Binding<Bool> {
        Binding {
            store.isCaptureEnabled
        } set: { enabled in
            store.setCaptureEnabled(enabled)
        }
    }

    private var displayState: ChainVisualState {
        store.isAccessibilityTrusted ? store.visualState : .permissionNeeded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let lastErrorMessage = store.lastErrorMessage {
                ChainFeedbackBanner(message: lastErrorMessage, style: .error, dismiss: store.dismissFeedback)
            } else if let lastInfoMessage = store.lastInfoMessage {
                ChainFeedbackBanner(message: lastInfoMessage, style: .info, dismiss: store.dismissFeedback)
            } else if !store.isAccessibilityTrusted {
                ChainFeedbackBanner(
                    message: "Auto-paste will need Accessibility permission. Copy-only review works now.",
                    style: .permission,
                    actionTitle: "Enable",
                    action: requestAccessibility
                )
            }

            Divider()

            controls

            if store.items.isEmpty {
                emptyState
            } else {
                chainItems
            }

            Divider()

            commandBar
            appLinks
        }
        .padding(14)
        .onAppear {
            store.refreshAccessibilityStatus()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: store.menuBarSystemImage)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(displayState == .error ? Color.red : Color.accentColor)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("ChainCopy")
                    .font(.headline)

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ChainStatusPill(state: displayState, count: store.items.count)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Toggle(isOn: appendModeBinding) {
                Label("Append", systemImage: "bolt.circle")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!store.isCaptureEnabled)
            .accessibilityLabel("Append Mode")

            Spacer()

            SeparatorMenu(store: store)
                .controlSize(.small)

            Toggle(isOn: captureBinding) {
                Image(systemName: store.isCaptureEnabled ? "pause.fill" : "play.fill")
            }
            .toggleStyle(.button)
            .labelsHidden()
            .controlSize(.small)
            .help(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")
            .accessibilityLabel(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(store.isCaptureEnabled ? "No Chain Yet" : "Paused", systemImage: "doc.on.clipboard")
        } description: {
            Text(store.isCaptureEnabled ? "Append the current clipboard or turn on Append Mode." : "Resume ChainCopy before collecting snippets.")
        } actions: {
            Button {
                store.appendCurrentPasteboard()
            } label: {
                Label("Append Clipboard", systemImage: "plus.square.on.square")
            }
            .disabled(!store.isCaptureEnabled)
        }
        .frame(height: 150)
    }

    private var chainItems: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chain")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(store.items.prefix(6)) { item in
                        MenuClipRow(item: item)
                            .contextMenu {
                                Button("Copy Snippet") {
                                    store.copyItemToPasteboard(item)
                                }

                                Button(item.isPinned ? "Unpin" : "Pin") {
                                    store.togglePinned(item)
                                }

                                Button("Remove", role: .destructive) {
                                    store.remove(item)
                                }
                            }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 210)
        }
    }

    private var commandBar: some View {
        HStack(spacing: 8) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Review", systemImage: "macwindow")
            }

            Button {
                store.appendCurrentPasteboard()
            } label: {
                Label("Append", systemImage: "plus.square.on.square")
            }
            .disabled(!store.isCaptureEnabled)

            Spacer()

            Button {
                store.copyComposedToPasteboard()
            } label: {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
            .disabled(store.composedText.isEmpty)

            Button {
                store.pasteComposedWithAutomation()
            } label: {
                Label("Paste", systemImage: "arrow.down.doc")
            }
            .disabled(store.composedText.isEmpty)

            Button(role: .destructive) {
                store.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(store.items.isEmpty)
        }
        .labelStyle(.iconOnly)
        .controlSize(.regular)
    }

    private var appLinks: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }

            Spacer()

            Button("Quit ChainCopy") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .font(.callout)
    }

    private var statusSubtitle: String {
        switch displayState {
        case .idle:
            return "Ready for an explicit append"
        case .collecting:
            return "\(store.items.count) snippets ready"
        case .appendMode:
            return "Collecting clipboard changes"
        case .paused:
            return "Capture paused"
        case .permissionNeeded:
            return "Permission needed for auto-paste"
        case .error:
            return "Action needed"
        }
    }

    private func requestAccessibility() {
        store.requestAccessibilityPermission()
    }
}

private struct MenuClipRow: View {
    let item: ClipItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: item.isPinned ? "pin.fill" : "text.alignleft")
                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewTitle)
                    .lineLimit(1)

                Text(item.metadataSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.metadataSummary)
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView(store: ClipboardStore(items: PreviewData.clips))
            .frame(width: 390)
    }
}
