import Foundation

enum ShortcutAction: UInt32, CaseIterable, Codable, Hashable, Identifiable {
    case appendSelectedText = 1
    case appendCurrentClipboard = 2
    case toggleCapture = 3
    case copyChain = 4
    case pasteChain = 5
    case showComposer = 6
    case clearChain = 7

    var id: UInt32 {
        rawValue
    }

    var title: String {
        switch self {
        case .appendSelectedText:
            return "Append Selected Text"
        case .appendCurrentClipboard:
            return "Append Current Clipboard"
        case .toggleCapture:
            return "Toggle Capture"
        case .copyChain:
            return "Copy Chain"
        case .pasteChain:
            return "Paste Chain"
        case .showComposer:
            return "Show Composer"
        case .clearChain:
            return "Clear Chain"
        }
    }

    var settingsDescription: String {
        switch self {
        case .appendSelectedText:
            return "Copies the frontmost selection, then appends it when Accessibility is allowed."
        case .appendCurrentClipboard:
            return "Appends the current plain-text clipboard without synthetic key events."
        case .toggleCapture:
            return "Turns visible Append Mode clipboard capture on or off."
        case .copyChain:
            return "Writes the composed chain to the clipboard without pasting."
        case .pasteChain:
            return "Writes the composed chain and auto-pastes only when Accessibility is allowed."
        case .showComposer:
            return "Brings the ChainCopy composer window forward."
        case .clearChain:
            return "Clears the current in-memory chain."
        }
    }

    var defaultShortcut: HotkeyShortcut {
        switch self {
        case .appendSelectedText:
            return .letter("C", modifiers: [.control, .command])
        case .appendCurrentClipboard:
            return .letter("C", modifiers: [.control, .command, .shift])
        case .toggleCapture:
            return .letter("A", modifiers: [.control, .command])
        case .copyChain:
            return .letter("V", modifiers: [.control, .command, .shift])
        case .pasteChain:
            return .letter("V", modifiers: [.control, .command])
        case .showComposer:
            return .letter("O", modifiers: [.control, .command])
        case .clearChain:
            return .letter("X", modifiers: [.control, .command])
        }
    }

    var preferenceKey: String {
        "Shortcut.\(rawValue)"
    }
}
