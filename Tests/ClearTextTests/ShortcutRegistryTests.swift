// Tests/ClearTextTests/ShortcutRegistryTests.swift
import XCTest
import CoreGraphics
@testable import ClearText

final class ShortcutRegistryTests: XCTestCase {
    var sut: ShortcutRegistry!
    var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "cleartext.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        sut = ShortcutRegistry(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_defaultBindingForToggleVisibility() {
        let binding = sut.binding(for: .toggleVisibility)
        XCTAssertEqual(binding.keyCode, 49)
        XCTAssertNotEqual(binding.modifiers & CGEventFlags.maskCommand.rawValue, 0)
        XCTAssertNotEqual(binding.modifiers & CGEventFlags.maskAlternate.rawValue, 0)
    }

    func test_allActionsHaveDefaultBindings() {
        let actions: [HotkeyAction] = [
            .toggleVisibility, .toggleAlwaysOnTop,
            .increaseTransparency, .decreaseTransparency,
            .toggleHoverToOpaque, .switchToTab(1), .switchToTab(2)
        ]
        for action in actions {
            let binding = sut.binding(for: action)
            XCTAssertFalse(binding.displayString.isEmpty, "No default for \(action)")
        }
    }

    func test_updateBinding_persistsAndReadsBack() {
        let newBinding = ShortcutBinding(keyCode: 11, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue)
        XCTAssertNoThrow(try sut.updateBinding(newBinding, for: .toggleAlwaysOnTop))
        let loaded = sut.binding(for: .toggleAlwaysOnTop)
        XCTAssertEqual(loaded, newBinding)
    }

    func test_conflictDetection_throwsOnDuplicate() {
        let binding = sut.binding(for: .toggleVisibility)
        XCTAssertThrowsError(try sut.updateBinding(binding, for: .toggleAlwaysOnTop)) { error in
            guard case ShortcutRegistryError.conflict(let conflicting) = error else {
                return XCTFail("Expected conflict error")
            }
            XCTAssertEqual(conflicting, .toggleVisibility)
        }
    }

    func test_updateBinding_sameActionDoesNotConflict() {
        let binding = sut.binding(for: .toggleVisibility)
        XCTAssertNoThrow(try sut.updateBinding(binding, for: .toggleVisibility))
    }

    func test_resetToDefaults() {
        let original = sut.binding(for: .toggleVisibility)
        let newBinding = ShortcutBinding(keyCode: 11, modifiers: CGEventFlags.maskCommand.rawValue)
        XCTAssertNoThrow(try sut.updateBinding(newBinding, for: .toggleVisibility))
        sut.resetToDefaults()
        XCTAssertEqual(sut.binding(for: .toggleVisibility), original)
    }

    func test_allBindings_returnsAllActions() {
        let all = sut.allBindings()
        XCTAssertEqual(all.count, 7)
    }

    func test_conflictDescription() {
        let binding = sut.binding(for: .toggleVisibility)
        XCTAssertThrowsError(try sut.updateBinding(binding, for: .toggleAlwaysOnTop)) { error in
            if case ShortcutRegistryError.conflict = error {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            } else {
                XCTFail("Expected ShortcutRegistryError.conflict, got \(error)")
            }
        }
    }

    func test_editorBinding_defaultForSelectWord() {
        let binding = sut.editorBinding(for: .selectWord)
        // Cmd+D: keyCode 2, command modifier
        XCTAssertEqual(binding.keyCode, 2)
        XCTAssertNotEqual(binding.modifiers & CGEventFlags.maskCommand.rawValue, 0)
    }

    func test_editorBinding_allActionsHaveDefaults() {
        for action in ShortcutRegistry.EditorAction.allCases {
            let binding = sut.editorBinding(for: action)
            XCTAssertFalse(binding.displayString.isEmpty, "No default for editor action \(action)")
        }
    }
}
