import SwiftUI

struct RootView: View {
    @ObservedObject var store: ClipboardStore
    @State private var selectedItemID: ClipItem.ID?

    private var selectedItem: ClipItem? {
        store.items.first { $0.id == selectedItemID }
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HeaderBlock(store: store)

                List(selection: $selectedItemID) {
                    ForEach(store.items) { item in
                        ClipRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("Copy Chain") {
                                    store.copyComposedToPasteboard()
                                }

                                Button("Paste Chain") {
                                    store.pasteComposedWithAutomation()
                                }

                                Button(item.isPinned ? "Unpin" : "Pin") {
                                    store.togglePinned(item)
                                }

                                Divider()

                                Button("Remove", role: .destructive) {
                                    store.remove(item)
                                }
                            }
                    }
                }
                .listStyle(.sidebar)

                HStack {
                    Button {
                        store.clear()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(store.items.isEmpty)

                    Spacer()

                    Text("\(store.items.count) items")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            ComposerView(store: store, selectedItem: selectedItem)
        }
        .frame(minWidth: 760, minHeight: 500)
    }
}

private struct HeaderBlock: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ChainCopy")
                        .font(.headline)

                    Text(store.isCaptureEnabled ? "Capturing clipboard" : "Capture paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $store.isCaptureEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding(14)
    }
}

private struct ClipRow: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isPinned ? "pin.fill" : "text.alignleft")
                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewTitle)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(DateFormatting.shortTime.string(from: item.capturedAt))

                    if let sourceAppName = item.sourceAppName {
                        Text(sourceAppName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(store: ClipboardStore(items: PreviewData.clips))
    }
}
