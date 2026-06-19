import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ClipboardStore
    @Environment(\.openWindow) private var openWindow
    @State private var accessibilityTrusted = true

    private let permissionService = PermissionService()

    private var appendModeBinding: Binding<Bool> {
        Binding {
            store.isAppendModeEnabled
        } set: { enabled in
            store.setAppendModeEnabled(enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let lastErrorMessage = store.lastErrorMessage {
                ChainFeedbackBanner(
                    message: lastErrorMessage,
                    style: .error,
                    dismiss: store.dismissFeedback
                )
            } else if let lastInfoMessage = store.lastInfoMessage {
                ChainFeedbackBanner(
                    message: lastInfoMessage,
                    style: .info,
                    dismiss: store.dismissFeedback
                )
            } else if !accessibilityTrusted {
                ChainFeedbackBanner(
                    message: "Auto-paste needs Accessibility. Copy-only works now.",
                    style: .permission,
                    actionTitle: "Enable",
                    action: requestAccessibility
                )
            }

            Divider()

            quickControls

            if store.items.isEmpty {
                emptyState
            } else {
                recentItems
            }

            Divider()

            commandBar

            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .onAppear {
            accessibilityTrusted = permissionService.isAccessibilityTrusted()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: store.menuBarSystemImage)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.visualState == .error ? Color.red : Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("ChainCopy")
                    .font(.headline)

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            ChainStatusPill(state: store.visualState, count: store.items.count)
        }
    }

    private var quickControls: some View {
        HStack(spacing: 10) {
            Toggle(isOn: appendModeBinding) {
                Label("Append Mode", systemImage: "bolt.circle")
            }
            .toggleStyle(.switch)
            .disabled(!store.isCaptureEnabled)
            .help("Collect clipboard changes while this is on")
            .accessibilityLabel("Append Mode")

            Spacer()

            SeparatorMenu(store: store)
                .controlSize(.small)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Snippets", systemImage: "doc.on.clipboard")
        } description: {
            Text("Start with Append Clipboard or turn on Append Mode.")
        } actions: {
            Button {
                store.appendCurrentPasteboard()
            } label: {
                Label("Append Clipboard", systemImage: "plus.square.on.square")
            }
        }
        .frame(height: 178)
    }

    private var recentItems: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(store.items.suffix(8).reversed())) { item in
                    MenuClipRow(item: item, store: store)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 260)
        .accessibilityLabel("Recent snippets")
    }

    private var commandBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Composer", systemImage: "macwindow")
                }
                .accessibilityLabel("Open composer")

                Spacer()

                Button {
                    store.appendCurrentPasteboard()
                } label: {
                    Label("Append", systemImage: "plus")
                }
                .accessibilityLabel("Append current clipboard")
            }

            HStack {
                Button {
                    store.copyComposedToPasteboard()
                } label: {
                    Label("Copy Chain", systemImage: "doc.on.clipboard")
                }
                .disabled(store.composedText.isEmpty)

                Button {
                    Task {
                        await store.pasteComposedWithAutomation()
                    }
                } label: {
                    Label("Paste", systemImage: "arrow.down.doc")
                }
                .disabled(store.composedText.isEmpty)

                Spacer()

                Button {
                    store.setCaptureEnabled(!store.isCaptureEnabled)
                } label: {
                    Label(store.isCaptureEnabled ? "Pause" : "Resume", systemImage: store.isCaptureEnabled ? "pause" : "play")
                }
                .accessibilityLabel(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")

                Button(role: .destructive) {
                    store.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(store.items.isEmpty)
            }
        }
    }

    private var statusSubtitle: String {
        switch store.visualState {
        case .idle:
            return "Ready for a chain"
        case .collecting:
            return "\(store.items.count) snippets ready"
        case .appendMode:
            return "Append Mode is on"
        case .paused:
            return "Capture paused"
        case .error:
            return "Needs attention"
        }
    }

    private func requestAccessibility() {
        accessibilityTrusted = permissionService.isAccessibilityTrusted(prompt: true)
    }
}

private struct MenuClipRow: View {
    let item: ClipItem
    @ObservedObject var store: ClipboardStore

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

            Spacer(minLength: 8)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            Button("Copy Snippet") {
                store.copyItemToPasteboard(item)
            }

            Button(item.isPinned ? "Unpin" : "Pin") {
                store.togglePinned(item)
            }

            Divider()

            Button(role: .destructive) {
                store.remove(item)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.metadataSummary)
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView(store: ClipboardStore(items: PreviewData.clips))
            .frame(width: 420)
    }
}
