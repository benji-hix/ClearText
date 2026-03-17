// Sources/ClearText/Hotkeys/ShortcutRegistry.swift
import Carbon
import Foundation

enum ShortcutRegistryError: Error, LocalizedError {
    case conflict(HotkeyAction)
    case editorConflict(ShortcutRegistry.EditorAction)

    var errorDescription: String? {
        switch self {
        case .conflict(let action): return "Already used by: \(action)"
        case .editorConflict(let action): return "Already used by editor action: \(action.rawValue)"
        }
    }
}

// @unchecked Sendable: all mutable state (bindings dict) is protected by bindingsLock.
final class ShortcutRegistry: @unchecked Sendable {
    static let shared = ShortcutRegistry()

    private let defaults: UserDefaults
    private var bindings: [String: ShortcutBinding] = [:]
    private let bindingsLock = NSLock()

    private static let defaultBindings: [(HotkeyAction, ShortcutBinding)] = {
        let cmdOpt = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
        return [
            (.toggleVisibility,    ShortcutBinding(keyCode: 42, modifiers: cmdOpt)),
            (.toggleAlwaysOnTop,   ShortcutBinding(keyCode: 17, modifiers: cmdOpt)),
            (.increaseTransparency,ShortcutBinding(keyCode: 30, modifiers: cmdOpt)),
            (.decreaseTransparency,ShortcutBinding(keyCode: 33, modifiers: cmdOpt)),
            (.toggleHoverToOpaque, ShortcutBinding(keyCode: 4,  modifiers: cmdOpt)),
            (.switchToTab(1),      ShortcutBinding(keyCode: 18, modifiers: cmdOpt)),
            (.switchToTab(2),      ShortcutBinding(keyCode: 19, modifiers: cmdOpt)),
        ]
    }()

    enum EditorAction: String, CaseIterable {
        case selectWord, deleteLine, duplicateLine, moveLineUp, moveLineDown, selectLine
    }

    private static let defaultEditorBindings: [(EditorAction, ShortcutBinding)] = {
        let cmd  = CGEventFlags.maskCommand.rawValue
        let opt  = CGEventFlags.maskAlternate.rawValue
        let shft = CGEventFlags.maskShift.rawValue
        return [
            (.selectWord,    ShortcutBinding(keyCode: 2,   modifiers: cmd)),
            (.deleteLine,    ShortcutBinding(keyCode: 40,  modifiers: cmd | shft)),
            (.duplicateLine, ShortcutBinding(keyCode: 2,   modifiers: cmd | shft)),
            (.moveLineUp,    ShortcutBinding(keyCode: 126, modifiers: opt)),
            (.moveLineDown,  ShortcutBinding(keyCode: 125, modifiers: opt)),
            (.selectLine,    ShortcutBinding(keyCode: 37,  modifiers: cmd)),
        ]
    }()

    func editorBinding(for action: EditorAction) -> ShortcutBinding {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        let pKey = "cleartext.editor.\(action.rawValue)"
        if let data = defaults.data(forKey: pKey),
           let binding = try? JSONDecoder().decode(ShortcutBinding.self, from: data) {
            return binding
        }
        return Self.defaultEditorBindings.first { $0.0 == action }?.1
            ?? ShortcutBinding(keyCode: 0, modifiers: 0)
    }

    func updateEditorBinding(_ newBinding: ShortcutBinding, for action: EditorAction) throws {
        bindingsLock.lock()
        let globalBindings = Self.defaultBindings.map { (act, _) in
            (act, bindings[key(for: act)] ?? defaultBinding(for: act))
        }
        bindingsLock.unlock()

        // Check conflict against global hotkeys
        for (existingAction, existingBinding) in globalBindings where existingBinding == newBinding {
            throw ShortcutRegistryError.conflict(existingAction)
        }
        // Check conflict against other editor bindings
        for existingAction in EditorAction.allCases where existingAction != action {
            if editorBinding(for: existingAction) == newBinding {
                // Use a generic conflict description for editor-vs-editor (no HotkeyAction to reference)
                throw ShortcutRegistryError.editorConflict(existingAction)
            }
        }

        if let data = try? JSONEncoder().encode(newBinding) {
            defaults.set(data, forKey: "cleartext.editor.\(action.rawValue)")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()
    }

    func binding(for action: HotkeyAction) -> ShortcutBinding {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        return bindings[key(for: action)] ?? defaultBinding(for: action)
    }

    func allBindings() -> [(HotkeyAction, ShortcutBinding)] {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        return Self.defaultBindings.map { (action, _) in
            (action, bindings[key(for: action)] ?? defaultBinding(for: action))
        }
    }

    func updateBinding(_ newBinding: ShortcutBinding, for action: HotkeyAction) throws {
        bindingsLock.lock()
        let currentBindings = Self.defaultBindings.map { (a, _) in
            (a, bindings[key(for: a)] ?? defaultBinding(for: a))
        }
        for (existingAction, existingBinding) in currentBindings {
            if existingAction != action && existingBinding == newBinding {
                bindingsLock.unlock()
                throw ShortcutRegistryError.conflict(existingAction)
            }
        }
        bindings[key(for: action)] = newBinding
        bindingsLock.unlock()
        persist(newBinding, for: action)
        NotificationCenter.default.post(name: .shortcutBindingsChanged, object: nil)
    }

    func resetToDefaults() {
        bindingsLock.lock()
        for (action, _) in Self.defaultBindings {
            defaults.removeObject(forKey: persistKey(for: action))
        }
        // Also reset editor bindings
        for action in EditorAction.allCases {
            defaults.removeObject(forKey: "cleartext.editor.\(action.rawValue)")
        }
        bindings.removeAll()
        bindingsLock.unlock()
        NotificationCenter.default.post(name: .shortcutBindingsChanged, object: nil)
    }

    private func defaultBinding(for action: HotkeyAction) -> ShortcutBinding {
        Self.defaultBindings.first { $0.0 == action }?.1
            ?? ShortcutBinding(keyCode: 0, modifiers: 0)
    }

    private func loadFromDefaults() {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        for (action, _) in Self.defaultBindings {
            let pKey = persistKey(for: action)
            if let data = defaults.data(forKey: pKey),
               let binding = try? JSONDecoder().decode(ShortcutBinding.self, from: data) {
                bindings[key(for: action)] = binding
            }
        }
    }

    private func persist(_ binding: ShortcutBinding, for action: HotkeyAction) {
        if let data = try? JSONEncoder().encode(binding) {
            defaults.set(data, forKey: persistKey(for: action))
        }
    }

    private func key(for action: HotkeyAction) -> String {
        switch action {
        case .toggleVisibility:     return "toggleVisibility"
        case .toggleAlwaysOnTop:    return "toggleAlwaysOnTop"
        case .increaseTransparency: return "increaseTransparency"
        case .decreaseTransparency: return "decreaseTransparency"
        case .toggleHoverToOpaque:  return "toggleHoverToOpaque"
        case .switchToTab(let n):   return "switchToTab\(n)"
        }
    }

    private func persistKey(for action: HotkeyAction) -> String {
        "cleartext.shortcut.\(key(for: action))"
    }
}

extension ShortcutRegistry.EditorAction: CustomStringConvertible {
    var description: String {
        switch self {
        case .selectWord:    return "Select Word Under Cursor"
        case .deleteLine:    return "Delete Current Line"
        case .duplicateLine: return "Duplicate Current Line"
        case .moveLineUp:    return "Move Line Up"
        case .moveLineDown:  return "Move Line Down"
        case .selectLine:    return "Select Entire Line"
        }
    }
}

extension Notification.Name {
    static let shortcutBindingsChanged = Notification.Name("cleartext.shortcutBindingsChanged")
}
