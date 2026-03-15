// Tests/ClearTextTests/HotkeyManagerTests.swift
import XCTest
import CoreGraphics
@testable import ClearText

final class HotkeyManagerTests: XCTestCase {

    func test_bindingTableMatchesDefaultToggleVisibility() {
        let suiteName = "hm.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registry = ShortcutRegistry(defaults: defaults)
        let manager = HotkeyManager(registry: registry)

        let cmdOpt = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
        let binding = ShortcutBinding(keyCode: 49, modifiers: cmdOpt & ShortcutBinding.modifierMask)

        let table = manager.bindingTableSnapshot()
        let match = table.first { $0.1 == binding }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.0, .toggleVisibility)
    }

    func test_refreshBindingTable_updatesAfterRegistryChange() {
        let suiteName = "hm.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registry = ShortcutRegistry(defaults: defaults)
        let manager = HotkeyManager(registry: registry)

        let newBinding = ShortcutBinding(keyCode: 15, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue)
        try? registry.updateBinding(newBinding, for: .toggleAlwaysOnTop)
        manager.refreshBindingTable()

        let table = manager.bindingTableSnapshot()
        let match = table.first { $0.0 == .toggleAlwaysOnTop }
        XCTAssertEqual(match?.1, newBinding)
    }

    func test_panelVisibilityCheck_false_doesNotConsumeSwitchToTabEvent() {
        let suiteName = "hm.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registry = ShortcutRegistry(defaults: defaults)
        let manager = HotkeyManager(registry: registry)
        manager.panelVisibilityCheck = { false }

        // Create a Cmd+Opt+1 key event (switchToTab(1) default binding: keyCode 18)
        let cmdOpt = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue)
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 18, keyDown: true) else {
            XCTFail("Could not create CGEvent"); return
        }
        event.flags = cmdOpt

        let result = manager.handleEvent(event)
        // Should pass through (not nil) because panel is not visible
        XCTAssertNotNil(result)
    }

    func test_panelVisibilityCheck_true_consumesSwitchToTabEvent() {
        let suiteName = "hm.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registry = ShortcutRegistry(defaults: defaults)
        let manager = HotkeyManager(registry: registry)
        manager.panelVisibilityCheck = { true }

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 18, keyDown: true) else {
            XCTFail("Could not create CGEvent"); return
        }
        let cmdOpt = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue)
        event.flags = cmdOpt

        let result = manager.handleEvent(event)
        // Should be consumed (nil) because panel is visible
        XCTAssertNil(result)
    }
}
