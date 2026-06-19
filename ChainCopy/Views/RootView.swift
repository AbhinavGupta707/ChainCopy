import SwiftUI

struct RootView: View {
    @ObservedObject var store: ClipboardStore
    @State private var selectedItemID: ClipItem.ID?
    @State private var accessibilityTrusted = true

    private let permissionService = PermissionService()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            ComposerView(
                store: store,
                selectedItemID: selectedItemID,
                accessibilityTrusted: accessibilityTrusted,
                requestAccessibility: requestAccessibility
            )
        }
        .frame(minWidth: 820, minHeight: 540)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.appendCurrentPasteboard()
                } label: {
                    Label("Append Clipboard", systemImage: "plus.square.on.square")
                }
                .help("Append the current clipboard contents")
                .accessibilityLabel("Append current clipboard")

                SeparatorMenu(store: store)
                    .help("Choose the separator for the composed chain")

                Button {
                    store.copyComposedToPasteboard()
                } label: {
                    Label("Copy Chain", systemImage: "doc.on.clipboard")
                }
                .disabled(store.composedText.isEmpty)
                .help("Copy the composed chain")
                .accessibilityLabel("Copy composed chain")

                Button {
                    Task {
                        await store.pasteComposedWithAutomation()
                    }
                } label: {
                    Label("Paste Chain", systemImage: "arrow.down.doc")
                }
                .disabled(store.composedText.isEmpty)
                .help("Paste the composed chain when Accessibility is granted")
                .accessibilityLabel("Paste composed chain")
            }
        }
        .onAppear {
            refreshPermissionStatus()
        }
        .onDeleteCommand {
            guard let selectedItemID else {
                return
            }

            store.remove(id: selectedItemID)
            self.selectedItemID = nil
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            SidebarHeader(
                store: store,
                selectedItemID: $selectedItemID,
                accessibilityTrusted: accessibilityTrusted,
                requestAccessibility: requestAccessibility
            )

            Divider()

            if store.items.isEmpty {
                EmptyChainSidebar(store: store)
            } else {
                List(selection: $selectedItemID) {
                    Section("Chain") {
                        ForEach(store.items) { item in
                            ChainItemRow(item: item)
                                .tag(item.id)
                                .contextMenu {
                                    itemContextMenu(for: item)
                                }
                        }
                        .onMove(perform: store.move)
                    }
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Collected snippets")
            }

            Divider()
            SidebarFooter(store: store)
        }
    }

    @ViewBuilder
    private func itemContextMenu(for item: ClipItem) -> some View {
        Button {
            store.copyItemToPasteboard(item)
        } label: {
            Label("Copy Snippet", systemImage: "doc.on.doc")
        }

        Button {
            store.copyComposedToPasteboard()
        } label: {
            Label("Copy Chain", systemImage: "doc.on.clipboard")
        }

        Divider()

        Button {
            store.togglePinned(item)
        } label: {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }

        Button {
            store.move(item, direction: .up)
        } label: {
            Label("Move Up", systemImage: "chevron.up")
        }

        Button {
            store.move(item, direction: .down)
        } label: {
            Label("Move Down", systemImage: "chevron.down")
        }

        Divider()

        Button(role: .destructive) {
            store.remove(item)
            if selectedItemID == item.id {
                selectedItemID = nil
            }
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    private func refreshPermissionStatus() {
        accessibilityTrusted = permissionService.isAccessibilityTrusted()
    }

    private func requestAccessibility() {
        accessibilityTrusted = permissionService.isAccessibilityTrusted(prompt: true)
    }
}

private struct SidebarHeader: View {
    @ObservedObject var store: ClipboardStore
    @Binding var selectedItemID: ClipItem.ID?
    let accessibilityTrusted: Bool
    let requestAccessibility: () -> Void

    private var appendModeBinding: Binding<Bool> {
        Binding {
            store.isAppendModeEnabled
        } set: { enabled in
            store.setAppendModeEnabled(enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: store.menuBarSystemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(store.visualState == .error ? Color.red : Color.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ChainCopy")
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ChainStatusPill(state: store.visualState, count: store.items.count)
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
                .help("Collect clipboard changes while Append Mode is on")
                .accessibilityLabel("Append Mode")

                Spacer()

                Button {
                    store.setCaptureEnabled(!store.isCaptureEnabled)
                } label: {
                    Image(systemName: store.isCaptureEnabled ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")
                .accessibilityLabel(store.isCaptureEnabled ? "Pause ChainCopy" : "Resume ChainCopy")
            }

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
                    message: "Auto-paste will need Accessibility permission. Copy-only review works now.",
                    style: .permission,
                    actionTitle: "Enable",
                    action: requestAccessibility
                )
            }
        }
        .padding(14)
    }

    private var subtitle: String {
        switch store.visualState {
        case .idle:
            return "Ready for an explicit append"
        case .collecting:
            return "Review and copy one clean block"
        case .appendMode:
            return "Collecting clipboard changes"
        case .paused:
            return "Capture paused"
        case .error:
            return "Action needed"
        }
    }
}

private struct ChainItemRow: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isPinned ? "pin.fill" : iconName)
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

    private var iconName: String {
        switch item.contentKind {
        case .text:
            return "text.alignleft"
        case .url:
            return "link"
        case .fileURLs:
            return "doc"
        case .richText:
            return "doc.richtext"
        case .unsupported:
            return "questionmark.square"
        }
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
                Label("No Snippets", systemImage: "doc.on.clipboard")
            } description: {
                Text("Append the current clipboard or turn on Append Mode to start a chain.")
            } actions: {
                Button {
                    store.appendCurrentPasteboard()
                } label: {
                    Label("Append Clipboard", systemImage: "plus.square.on.square")
                }
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
                store.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(store.items.isEmpty)
            .controlSize(.small)
            .accessibilityLabel("Clear chain")
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
