import SwiftUI

struct ChainStatusPill: View {
    let state: ChainVisualState
    let count: Int

    var body: some View {
        Label {
            Text(title)
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .accessibilityLabel(accessibilityText)
    }

    private var title: String {
        switch state {
        case .idle:
            return "Idle"
        case .collecting:
            return "\(count) Collected"
        case .appendMode:
            return count == 0 ? "Append Mode" : "Append Mode - \(count)"
        case .paused:
            return "Paused"
        case .error:
            return "Needs Attention"
        }
    }

    private var systemImage: String {
        switch state {
        case .idle:
            return "link"
        case .collecting:
            return "text.badge.plus"
        case .appendMode:
            return "bolt.circle.fill"
        case .paused:
            return "pause.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var foregroundStyle: some ShapeStyle {
        switch state {
        case .appendMode:
            return AnyShapeStyle(.tint)
        case .paused, .idle:
            return AnyShapeStyle(.secondary)
        case .error:
            return AnyShapeStyle(.red)
        case .collecting:
            return AnyShapeStyle(.primary)
        }
    }

    private var accessibilityText: String {
        switch state {
        case .idle:
            return "ChainCopy idle"
        case .collecting:
            return "ChainCopy has \(count) snippets collected"
        case .appendMode:
            return "Append Mode on with \(count) snippets collected"
        case .paused:
            return "ChainCopy paused"
        case .error:
            return "ChainCopy needs attention"
        }
    }
}

struct ChainFeedbackBanner: View {
    enum Style {
        case info
        case error
        case permission
    }

    let message: String
    let style: Style
    let actionTitle: String?
    let action: (() -> Void)?
    let dismiss: (() -> Void)?

    init(
        message: String,
        style: Style,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        dismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.style = style
        self.actionTitle = actionTitle
        self.action = action
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(iconStyle)
                .frame(width: 18)

            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .font(.callout.weight(.medium))
            }

            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Dismiss message")
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary)
        }
    }

    private var systemImage: String {
        switch style {
        case .info:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .permission:
            return "hand.raised.fill"
        }
    }

    private var iconStyle: some ShapeStyle {
        switch style {
        case .info:
            return AnyShapeStyle(.green)
        case .error:
            return AnyShapeStyle(.red)
        case .permission:
            return AnyShapeStyle(.orange)
        }
    }
}

struct SeparatorMenu: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        Menu {
            ForEach(SeparatorPreset.allCases.filter { $0 != .custom }) { preset in
                Button {
                    store.applySeparatorPreset(preset)
                } label: {
                    Label(preset.title, systemImage: store.separatorPreset == preset ? "checkmark" : "textformat")
                }
                .accessibilityLabel("\(preset.title) separator")
            }
        } label: {
            Label(store.separatorPreset.compactTitle, systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        .accessibilityLabel("Separator")
        .accessibilityValue(store.separatorPreset.title)
    }
}

struct SeparatorPicker: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        Picker("Separator", selection: separatorSelection) {
            ForEach(SeparatorPreset.allCases) { preset in
                Text(preset.title).tag(preset)
            }
        }
    }

    private var separatorSelection: Binding<SeparatorPreset> {
        Binding {
            store.separatorPreset
        } set: { preset in
            store.applySeparatorPreset(preset)
        }
    }
}
