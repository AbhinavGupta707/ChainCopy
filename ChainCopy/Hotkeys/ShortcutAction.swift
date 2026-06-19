import Foundation

enum ShortcutAction: UInt32, CaseIterable, Codable, Hashable, Identifiable {
    case toggleCapture = 1
    case copyChain = 2
    case pasteChain = 3
    case showComposer = 4
    case clearChain = 5

    var id: UInt32 {
        rawValue
    }

    var title: String {
        switch self {
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
        case .toggleCapture:
            return "Turns clipboard capture on or off."
        case .copyChain:
            return "Writes the chain to the clipboard."
        case .pasteChain:
            return "Copies the chain, then pastes when Accessibility is allowed."
        case .showComposer:
            return "Brings the composer window forward."
        case .clearChain:
            return "Clears the current in-memory chain."
        }
    }

    var defaultShortcut: HotkeyShortcut {
        switch self {
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
