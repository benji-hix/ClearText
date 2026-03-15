// Sources/ClearText/Hotkeys/ShortcutRegistry.swift
import Carbon

enum ShortcutRegistryError: Error, LocalizedError {
    case conflict(HotkeyAction)

    var errorDescription: String? {
        switch self {
        case .conflict(let action): return "Already used by: \(action)"
        }
    }
}

final class ShortcutRegistry: @unchecked Sendable {
    static let shared = ShortcutRegistry()

    private let defaults: UserDefaults
    private var bindings: [String: ShortcutBinding] = [:]

    private static let defaultBindings: [(HotkeyAction, ShortcutBinding)] = {
        let cmdOpt = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
        return [
            (.toggleVisibility,    ShortcutBinding(keyCode: 49, modifiers: cmdOpt)),
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
        let pKey = "cleartext.editor.\(action.rawValue)"
        if let data = defaults.data(forKey: pKey),
           let binding = try? JSONDecoder().decode(ShortcutBinding.self, from: data) {
            return binding
        }
        return Self.defaultEditorBindings.first { $0.0 == action }?.1
            ?? ShortcutBinding(keyCode: 0, modifiers: 0)
    }

    func updateEditorBinding(_ newBinding: ShortcutBinding, for action: EditorAction) throws {
        for (existingAction, existingBinding) in allBindings() where existingBinding == newBinding {
            throw ShortcutRegistryError.conflict(existingAction)
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
        bindings[key(for: action)] ?? defaultBinding(for: action)
    }

    func allBindings() -> [(HotkeyAction, ShortcutBinding)] {
        Self.defaultBindings.map { (action, _) in (action, binding(for: action)) }
    }

    func updateBinding(_ newBinding: ShortcutBinding, for action: HotkeyAction) throws {
        for (existingAction, existingBinding) in allBindings() {
            if existingAction != action && existingBinding == newBinding {
                throw ShortcutRegistryError.conflict(existingAction)
            }
        }
        bindings[key(for: action)] = newBinding
        persist(newBinding, for: action)
    }

    func resetToDefaults() {
        for (action, _) in Self.defaultBindings {
            defaults.removeObject(forKey: persistKey(for: action))
        }
        bindings.removeAll()
    }

    private func defaultBinding(for action: HotkeyAction) -> ShortcutBinding {
        Self.defaultBindings.first { $0.0 == action }?.1
            ?? ShortcutBinding(keyCode: 0, modifiers: 0)
    }

    private func loadFromDefaults() {
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
