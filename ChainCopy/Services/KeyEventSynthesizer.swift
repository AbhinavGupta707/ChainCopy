import CoreGraphics
import Foundation

protocol KeyEventSynthesizing {
    func sendPaste()
}

struct CGKeyEventSynthesizer: KeyEventSynthesizing {
    func sendPaste() {
        sendCommand(keyCode: 9)
    }

    private func sendCommand(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
