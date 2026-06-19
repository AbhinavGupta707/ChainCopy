import SwiftUI

struct ComposerView: View {
    @ObservedObject var store: ClipboardStore
    let selectedItemID: ClipItem.ID?
    let accessibilityTrusted: Bool
    let requestAccessibility: () -> Void

    private var selectedItem: ClipItem? {
        guard let selectedItemID else {
            return nil
        }

        return store.items.first { $0.id == selectedItemID }
    }

    private var selectedText: Binding<String> {
        Binding {
            selectedItem?.text ?? ""
        } set: { text in
            guard let selectedItemID else {
                return
            }

            store.updateText(for: selectedItemID, text: text)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let lastErrorMessage = store.lastErrorMessage {
                ChainFeedbackBanner(
                    message: lastErrorMessage,
                    style: .error,
                    dismiss: store.dismissFeedback
                )
            } else if !accessibilityTrusted {
                ChainFeedbackBanner(
                    message: "Permission needed for automatic paste later. Today, Copy Chain leaves the joined block on the clipboard.",
                    style: .permission,
                    actionTitle: "Enable",
                    action: requestAccessibility
                )
            }

            if let selectedItem {
                selectedItemEditor(selectedItem)
            } else {
                composedPreview
            }

            footer
        }
        .padding(24)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedItem == nil ? "Composed Chain" : "Snippet Detail")
                    .font(.title2.weight(.semibold))

                Text(headerSubtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            SeparatorMenu(store: store)
                .controlSize(.regular)

            Button {
                store.copyComposedToPasteboard()
            } label: {
                Label("Copy Chain", systemImage: "doc.on.clipboard")
            }
            .disabled(store.composedText.isEmpty)
            .accessibilityLabel("Copy composed chain")

            Button {
                Task {
                    await store.pasteComposedWithAutomation()
                }
            } label: {
                Label("Paste Chain", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.composedText.isEmpty)
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityLabel("Paste composed chain")
        }
    }

    private var composedPreview: some View {
        ZStack {
            if store.composedText.isEmpty {
                ContentUnavailableView {
                    Label("No Chain Yet", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Append the clipboard, then review the final block here before copying it.")
                } actions: {
                    Button {
                        store.appendCurrentPasteboard()
                    } label: {
                        Label("Append Clipboard", systemImage: "plus.square.on.square")
                    }
                }
            } else {
                ScrollView {
                    Text(store.composedText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary)
        }
        .accessibilityLabel("Composed chain preview")
    }

    private func selectedItemEditor(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(item.sourceDisplayName, systemImage: "app.dashed")
                Label(DateFormatting.shortTime.string(from: item.capturedAt), systemImage: "clock")
                Label("\(item.characterCount) chars", systemImage: "character.cursor.ibeam")

                Spacer()

                Button {
                    store.togglePinned(item)
                } label: {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }

                Button {
                    store.copyItemToPasteboard(item)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    store.remove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            TextEditor(text: selectedText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.quaternary)
                }
                .accessibilityLabel("Snippet text")
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label(separatorDescription, systemImage: "text.line.first.and.arrowtriangle.forward")
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Label("\(store.composedCharacterCount) characters", systemImage: "textformat.size")
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.appendCurrentPasteboard()
            } label: {
                Label("Append Clipboard", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive) {
                store.clear()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .disabled(store.items.isEmpty)
        }
        .font(.callout)
    }

    private var headerSubtitle: String {
        if let selectedItem {
            return selectedItem.metadataSummary
        }

        if store.items.isEmpty {
            return store.isCaptureEnabled ? "Idle. Nothing has been added to this chain." : "Paused. Resume before collecting snippets."
        }

        return "\(store.items.count) snippets joined with \(store.separatorPreset.title.lowercased())."
    }

    private var separatorDescription: String {
        if store.separatorPreset == .custom {
            return "Custom separator"
        }

        return "\(store.separatorPreset.title): \(store.separatorPreset.preview)"
    }
}

struct ComposerView_Previews: PreviewProvider {
    static var previews: some View {
        ComposerView(
            store: ClipboardStore(items: PreviewData.clips),
            selectedItemID: nil,
            accessibilityTrusted: true,
            requestAccessibility: {}
        )
    }
}
