import AppKit
import Carbon.HIToolbox
import Foundation

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt32

    static let control = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let command = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var modifiers: ShortcutModifiers = []

        if eventFlags.contains(.control) {
            modifiers.insert(.control)
        }

        if eventFlags.contains(.option) {
            modifiers.insert(.option)
        }

        if eventFlags.contains(.command) {
            modifiers.insert(.command)
        }

        if eventFlags.contains(.shift) {
            modifiers.insert(.shift)
        }

        self = modifiers
    }

    var displayComponents: [String] {
        var components: [String] = []

        if contains(.control) {
            components.append("Ctrl")
        }

        if contains(.option) {
            components.append("Opt")
        }

        if contains(.command) {
            components.append("Cmd")
        }

        if contains(.shift) {
            components.append("Shift")
        }

        return components
    }

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0

        if contains(.control) {
            flags |= UInt32(controlKey)
        }

        if contains(.option) {
            flags |= UInt32(optionKey)
        }

        if contains(.command) {
            flags |= UInt32(cmdKey)
        }

        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        return flags
    }

    var containsGlobalModifier: Bool {
        contains(.control) || contains(.option) || contains(.command)
    }
}

struct HotkeyShortcut: Codable, Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: ShortcutModifiers

    init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(storageValue: String) {
        let components = storageValue.split(separator: ":")
        guard components.count == 2,
              let keyCode = UInt32(components[0]),
              let modifierRawValue = UInt32(components[1])
        else {
            return nil
        }

        self.keyCode = keyCode
        self.modifiers = ShortcutModifiers(rawValue: modifierRawValue)
    }

    var storageValue: String {
        "\(keyCode):\(modifiers.rawValue)"
    }

    var carbonModifiers: UInt32 {
        modifiers.carbonFlags
    }

    var isUsableGlobalShortcut: Bool {
        modifiers.containsGlobalModifier
    }

    var displayString: String {
        let keyName = Self.displayName(for: keyCode)
        let modifierText = modifiers.displayComponents.joined(separator: "+")

        guard !modifierText.isEmpty else {
            return keyName
        }

        return "\(modifierText)+\(keyName)"
    }

    static func letter(_ letter: Character, modifiers: ShortcutModifiers) -> HotkeyShortcut {
        guard let keyCode = keyCode(for: letter) else {
            preconditionFailure("Unsupported default shortcut letter: \(letter)")
        }

        return HotkeyShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    static func keyCode(for letter: Character) -> UInt32? {
        keyCodesByLetter[String(letter).uppercased()]
    }

    static func displayName(for keyCode: UInt32) -> String {
        keyNamesByCode[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyCodesByLetter: [String: UInt32] = [
        "A": 0,
        "S": 1,
        "D": 2,
        "F": 3,
        "H": 4,
        "G": 5,
        "Z": 6,
        "X": 7,
        "C": 8,
        "V": 9,
        "B": 11,
        "Q": 12,
        "W": 13,
        "E": 14,
        "R": 15,
        "Y": 16,
        "T": 17,
        "O": 31,
        "U": 32,
        "I": 34,
        "P": 35,
        "L": 37,
        "J": 38,
        "K": 40,
        "N": 45,
        "M": 46
    ]

    private static let keyNamesByCode: [UInt32: String] = [
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        4: "H",
        5: "G",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        16: "Y",
        17: "T",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "O",
        32: "U",
        33: "[",
        34: "I",
        35: "P",
        36: "Return",
        37: "L",
        38: "J",
        39: "'",
        40: "K",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "N",
        46: "M",
        47: ".",
        48: "Tab",
        49: "Space",
        51: "Delete",
        53: "Esc",
        123: "Left",
        124: "Right",
        125: "Down",
        126: "Up"
    ]
}
