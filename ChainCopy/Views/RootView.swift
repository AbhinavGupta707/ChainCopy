import SwiftUI

struct RootView: View {
    @ObservedObject var store: ClipboardStore
    @State private var selectedItemID: ClipItem.ID?

    private var displayState: ChainVisualState {
        store.isAccessibilityTrusted ? store.visualState : .permissionNeeded
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarHeader(
                    store: store,
                    selectedItemID: $selectedItemID,
                    displayState: displayState,
                    requestAccessibility: requestAccessibility
                )

                if store.items.isEmpty {
                    EmptyChainSidebar(store: store)
                } else {
                    List(selection: $selectedItemID) {
                        ForEach(store.items) { item in
                            ChainItemRow(item: item)
                                .tag(item.id)
                                .contextMenu {
                                    itemContextMenu(item)
                                }
                        }
                        .onMove(perform: store.move)
                    }
                    .listStyle(.sidebar)
                    .onDeleteCommand {
                        removeSelectedItem()
                    }
                }

                SidebarFooter(store: store)
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            ComposerView(
                store: store,
                selectedItemID: selectedItemID,
                accessibilityTrusted: store.isAccessibilityTrusted,
                requestAccessibility: requestAccessibility
            )
        }
        .frame(minWidth: 820, minHeight: 540)
        .onAppear {
            store.refreshAccessibilityStatus()
        }
    }

    @ViewBuilder
    private func itemContextMenu(_ item: ClipItem) -> some View {
        Button("Copy Snippet") {
            store.copyItemToPasteboard(item)
        }

        Button(item.isPinned ? "Unpin" : "Pin") {
            store.togglePinned(item)
        }

        Divider()

        Button("Move Up") {
            store.move(item, direction: .up)
        }

        Button("Move Down") {
            store.move(item, direction: .down)
        }

        Divider()

        Button("Copy Chain") {
            store.copyComposedToPasteboard()
        }

        Button("Paste Chain") {
            store.pasteComposedWithAutomation()
        }

        Button("Remove", role: .destructive) {
            if selectedItemID == item.id {
                selectedItemID = nil
            }
            store.remove(item)
        }
    }

    private func removeSelectedItem() {
        guard let selectedItemID, let item = store.items.first(where: { $0.id == selectedItemID }) else {
            return
        }

        self.selectedItemID = nil
        store.remove(item)
    }

    private func requestAccessibility() {
        store.requestAccessibilityPermission()
    }
}

private struct SidebarHeader: View {
    @ObservedObject var store: ClipboardStore
    @Binding var selectedItemID: ClipItem.ID?
    let displayState: ChainVisualState
    let requestAccessibility: () -> Void

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ChainStatusPill(state: displayState, count: store.items.count)
            }

            HStack(spacing: 8) {
                Button {
                    selectedItemID = nil
                } label: {
                    Label("Review", systemImage: "text.viewfinder")
                }
                .controlSize(.small)
                .accessibilityLabel("Review composed chain")

                Toggle(isOn: appendModeBinding) {
                    Label("Append", systemImage: "bolt.circle")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!store.isCaptureEnabled)
                .accessibilityLabel("Append Mode")

                Spacer()

                Toggle(isOn: captureBinding) {
                    Image(systemName: store.isCaptureEnabled ? "pause.fill" : "play.fill")
                }
                .toggleStyle(.button)
                .labelsHidden()
                .controlSize(.small)
                .help(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")
                .accessibilityLabel(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")
            }

            if let lastErrorMessage = store.lastErrorMessage {
                ChainFeedbackBanner(message: lastErrorMessage, style: .error, dismiss: store.dismissFeedback)
            } else if let lastInfoMessage = store.lastInfoMessage {
                ChainFeedbackBanner(message: lastInfoMessage, style: .info, dismiss: store.dismissFeedback)
            } else if displayState == .permissionNeeded {
                ChainFeedbackBanner(
                    message: "Auto-paste will need Accessibility permission. Manual copy works now.",
                    style: .permission,
                    actionTitle: "Enable",
                    action: requestAccessibility
                )
            }
        }
        .padding(14)
    }

    private var subtitle: String {
        switch displayState {
        case .idle:
            return "Ready for an explicit append"
        case .collecting:
            return "Review and copy one clean block"
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
}

private struct ChainItemRow: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isPinned ? "pin.fill" : "text.alignleft")
                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewTitle)
                    .lineLimit(1)
                    .font(.callout)

                Text(item.metadataSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let pinned = item.isPinned ? "Pinned. " : ""
        return "\(pinned)\(item.previewTitle). \(item.metadataSummary)"
    }
}

private struct EmptyChainSidebar: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ContentUnavailableView {
                Label(store.isCaptureEnabled ? "No Snippets" : "Paused", systemImage: "doc.on.clipboard")
            } description: {
                Text(store.isCaptureEnabled ? "Append the clipboard or turn on Append Mode to start a chain." : "Resume ChainCopy before collecting snippets.")
            } actions: {
                Button {
                    store.appendCurrentPasteboard()
                } label: {
                    Label("Append Clipboard", systemImage: "plus.square.on.square")
                }
                .disabled(!store.isCaptureEnabled)
            }
            .padding(.horizontal, 18)

            Spacer()
        }
    }
}

private struct SidebarFooter: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        HStack(spacing: 8) {
            Label("\(store.items.count) items", systemImage: "number")
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.copyComposedToPasteboard()
            } label: {
                Label("Copy", systemImage: "doc.on.clipboard")
            }
            .disabled(store.composedText.isEmpty)
            .controlSize(.small)

            Button {
                store.pasteComposedWithAutomation()
            } label: {
                Label("Paste", systemImage: "arrow.down.doc")
            }
            .disabled(store.composedText.isEmpty)
            .controlSize(.small)

            Button(role: .destructive) {
                store.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(store.items.isEmpty)
            .controlSize(.small)
        }
        .font(.callout)
        .padding(12)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(store: ClipboardStore(items: PreviewData.clips))
    }
}
