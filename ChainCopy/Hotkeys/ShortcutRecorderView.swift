import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: HotkeyShortcut?

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl()
        control.shortcut = shortcut
        control.onChange = { shortcut in
            context.coordinator.shortcut.wrappedValue = shortcut
        }
        return control
    }

    func updateNSView(_ nsView: ShortcutRecorderControl, context: Context) {
        nsView.shortcut = shortcut
    }

    final class Coordinator {
        var shortcut: Binding<HotkeyShortcut?>

        init(shortcut: Binding<HotkeyShortcut?>) {
            self.shortcut = shortcut
        }
    }
}

final class ShortcutRecorderControl: NSControl {
    var shortcut: HotkeyShortcut? {
        didSet {
            needsDisplay = true
            setAccessibilityValue(shortcut?.displayString ?? "Disabled")
        }
    }

    var onChange: ((HotkeyShortcut?) -> Void)?
    private var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 160, height: 28)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return false
        }

        capture(event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        let backgroundColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.12)
            : NSColor.controlBackgroundColor

        backgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        let text = isRecording ? "Type shortcut" : (shortcut?.displayString ?? "Disabled")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(
            x: bounds.minX + 8,
            y: bounds.midY - attributedText.size().height / 2,
            width: bounds.width - 16,
            height: attributedText.size().height
        )
        attributedText.draw(in: textRect)
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            needsDisplay = true
            return
        }

        let modifiers = ShortcutModifiers(eventFlags: event.modifierFlags)

        if (event.keyCode == 51 || event.keyCode == 117), modifiers.isEmpty {
            shortcut = nil
            onChange?(nil)
            isRecording = false
            return
        }

        let newShortcut = HotkeyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard newShortcut.isUsableGlobalShortcut else {
            NSSound.beep()
            return
        }

        shortcut = newShortcut
        onChange?(newShortcut)
        isRecording = false
    }
}
