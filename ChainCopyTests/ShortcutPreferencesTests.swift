import XCTest
@testable import ChainCopy

@MainActor
final class ShortcutPreferencesTests: XCTestCase {
    func testShortcutRoundTripsThroughStorageValue() {
        let shortcut = HotkeyShortcut.letter("V", modifiers: [.control, .command, .shift])

        let restored = HotkeyShortcut(storageValue: shortcut.storageValue)

        XCTAssertEqual(restored, shortcut)
        XCTAssertEqual(shortcut.displayString, "Ctrl+Cmd+Shift+V")
    }

    func testConflictingActionsFindsDuplicateEnabledShortcuts() {
        let duplicate = HotkeyShortcut.letter("C", modifiers: [.control, .command])
        var assignments = ShortcutPreferences.defaultAssignments()
        assignments[.appendSelectedText] = ShortcutAssignment(shortcut: duplicate)
        assignments[.copyChain] = ShortcutAssignment(shortcut: duplicate)
        assignments[.clearChain] = ShortcutAssignment(shortcut: nil)

        let conflicts = ShortcutPreferences.conflictingActions(in: assignments)

        XCTAssertEqual(conflicts, [.appendSelectedText, .copyChain])
    }

    func testDisabledShortcutDoesNotConflict() {
        let duplicate = HotkeyShortcut.letter("C", modifiers: [.control, .command])
        var assignments = ShortcutPreferences.defaultAssignments()
        assignments[.appendSelectedText] = ShortcutAssignment(shortcut: duplicate)
        assignments[.copyChain] = ShortcutAssignment(shortcut: nil)

        let conflicts = ShortcutPreferences.conflictingActions(in: assignments)

        XCTAssertFalse(conflicts.contains(.copyChain))
    }
}
