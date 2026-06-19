import XCTest
@testable import ChainCopy

@MainActor
final class ShortcutPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ShortcutPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testShortcutRoundTripsThroughStorageValue() {
        let shortcut = HotkeyShortcut.letter("V", modifiers: [.control, .command, .shift])

        let restored = HotkeyShortcut(storageValue: shortcut.storageValue)

        XCTAssertEqual(restored, shortcut)
        XCTAssertEqual(shortcut.displayString, "Ctrl+Cmd+Shift+V")
    }

    func testConflictingActionsFindsDuplicateEnabledShortcuts() {
        let duplicate = HotkeyShortcut.letter("V", modifiers: [.control, .command])
        var assignments = ShortcutPreferences.defaultAssignments()
        assignments[.pasteChain] = ShortcutAssignment(shortcut: duplicate)
        assignments[.copyChain] = ShortcutAssignment(shortcut: duplicate)
        assignments[.clearChain] = ShortcutAssignment(shortcut: nil)

        let conflicts = ShortcutPreferences.conflictingActions(in: assignments)

        XCTAssertEqual(conflicts, [.pasteChain, .copyChain])
    }

    func testDisabledShortcutPersistsAndDoesNotConflict() {
        let preferences = ShortcutPreferences(userDefaults: defaults)

        preferences.setShortcut(nil, for: .copyChain)
        let restored = ShortcutPreferences(userDefaults: defaults)

        XCTAssertNil(restored.shortcut(for: .copyChain))
        XCTAssertFalse(restored.conflictingActions.contains(.copyChain))
    }
}
