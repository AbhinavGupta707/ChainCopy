import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ClipboardStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ChainCopy")
                        .font(.headline)

                    Text(store.isCaptureEnabled ? "Live chain" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $store.isCaptureEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            if store.items.isEmpty {
                ContentUnavailableView("No copied text", systemImage: "doc.on.clipboard")
                    .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(store.items.prefix(8)) { item in
                            MenuClipRow(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 260)
            }

            Divider()

            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open", systemImage: "macwindow")
                }

                Spacer()

                Button {
                    store.copyComposedToPasteboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
                .disabled(store.composedText.isEmpty)

                Button {
                    store.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(store.items.isEmpty)
            }

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }

            Button("Quit ChainCopy") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
    }
}

private struct MenuClipRow: View {
    let item: ClipItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: item.isPinned ? "pin.fill" : "text.alignleft")
                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewTitle)
                    .lineLimit(1)

                Text(DateFormatting.shortTime.string(from: item.capturedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView(store: ClipboardStore(items: PreviewData.clips))
            .frame(width: 380)
    }
}
