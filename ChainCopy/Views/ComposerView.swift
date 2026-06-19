import SwiftUI

struct ComposerView: View {
    @ObservedObject var store: ClipboardStore
    let selectedItem: ClipItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedItem == nil ? "Composed Chain" : "Selected Copy")
                        .font(.title2.weight(.semibold))

                    Text("\(store.composedCharacterCount) characters ready")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Button {
                        store.copyComposedToPasteboard()
                    } label: {
                        Label("Copy Chain", systemImage: "doc.on.clipboard")
                    }
                    .disabled(store.composedText.isEmpty)

                    Button {
                        store.pasteComposedWithAutomation()
                    } label: {
                        Label("Paste Chain", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.composedText.isEmpty)
                }
            }

            if let result = store.lastPasteAutomationResult {
                Label(result.message, systemImage: result == .pasted ? "checkmark.circle" : "hand.raised")
                    .font(.callout)
                    .foregroundStyle(result == .pasted ? .green : .secondary)
            }

            ScrollView {
                Text(selectedItem?.text ?? store.composedText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if store.composedText.isEmpty {
                    ContentUnavailableView("No copied text", systemImage: "doc.on.clipboard")
                }
            }

            HStack {
                Label(separatorLabel, systemImage: "text.line.first.and.arrowtriangle.forward")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    store.clear()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(store.items.isEmpty)
            }
            .font(.callout)
        }
        .padding(24)
    }

    private var separatorLabel: String {
        switch store.separator {
        case "\n\n":
            return "Blank line separator"
        case "\n":
            return "Line separator"
        case " ":
            return "Space separator"
        default:
            return "Custom separator"
        }
    }
}

struct ComposerView_Previews: PreviewProvider {
    static var previews: some View {
        ComposerView(store: ClipboardStore(items: PreviewData.clips), selectedItem: nil)
    }
}
