import Combine
import Foundation

struct ShortcutAssignment: Equatable, Sendable {
    var shortcut: HotkeyShortcut?
}

@MainActor
final class ShortcutPreferences: ObservableObject {
    @Published private(set) var assignments: [ShortcutAction: ShortcutAssignment]

    private let userDefaults: UserDefaults
    private let disabledValue = "disabled"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.assignments = Self.loadAssignments(from: userDefaults, disabledValue: disabledValue)
    }

    func shortcut(for action: ShortcutAction) -> HotkeyShortcut? {
        guard let assignment = assignments[action] else {
            return action.defaultShortcut
        }

        return assignment.shortcut
    }

    func setShortcut(_ shortcut: HotkeyShortcut?, for action: ShortcutAction) {
        assignments[action] = ShortcutAssignment(shortcut: shortcut)

        if let shortcut {
            userDefaults.set(shortcut.storageValue, forKey: action.preferenceKey)
        } else {
            userDefaults.set(disabledValue, forKey: action.preferenceKey)
        }
    }

    func reset(_ action: ShortcutAction) {
        userDefaults.removeObject(forKey: action.preferenceKey)
        assignments[action] = ShortcutAssignment(shortcut: action.defaultShortcut)
    }

    func resetAll() {
        for action in ShortcutAction.allCases {
            userDefaults.removeObject(forKey: action.preferenceKey)
        }

        assignments = Self.defaultAssignments()
    }

    var conflictingActions: Set<ShortcutAction> {
        Self.conflictingActions(in: assignments)
    }

    static func defaultAssignments() -> [ShortcutAction: ShortcutAssignment] {
        Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { action in
            (action, ShortcutAssignment(shortcut: action.defaultShortcut))
        })
    }

    static func conflictingActions(in assignments: [ShortcutAction: ShortcutAssignment]) -> Set<ShortcutAction> {
        var actionsByShortcut: [HotkeyShortcut: [ShortcutAction]] = [:]

        for action in ShortcutAction.allCases {
            guard let shortcut = assignments[action]?.shortcut else {
                continue
            }

            actionsByShortcut[shortcut, default: []].append(action)
        }

        return Set(actionsByShortcut.values.filter { $0.count > 1 }.flatMap { $0 })
    }

    private static func loadAssignments(
        from userDefaults: UserDefaults,
        disabledValue: String
    ) -> [ShortcutAction: ShortcutAssignment] {
        Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { action in
            let storedValue = userDefaults.string(forKey: action.preferenceKey)
            let shortcut: HotkeyShortcut?

            if storedValue == disabledValue {
                shortcut = nil
            } else if let storedValue, let storedShortcut = HotkeyShortcut(storageValue: storedValue) {
                shortcut = storedShortcut
            } else {
                shortcut = action.defaultShortcut
            }

            return (action, ShortcutAssignment(shortcut: shortcut))
        })
    }
}
