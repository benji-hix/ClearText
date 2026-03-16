// Sources/ClearText/Preferences/KeyCaptureField.swift
import AppKit

protocol KeyCaptureFieldDelegate: AnyObject {
    func keyCaptureField(_ field: KeyCaptureField, didCapture binding: ShortcutBinding, for action: HotkeyAction)
    func keyCaptureField(_ field: KeyCaptureField, conflictedWith conflicting: HotkeyAction, for action: HotkeyAction)
    func keyCaptureFieldDidCancel(_ field: KeyCaptureField)
}

final class KeyCaptureField: NSTextField {

    var targetAction: HotkeyAction?
    var targetEditorAction: ShortcutRegistry.EditorAction?
    weak var captureDelegate: (any KeyCaptureFieldDelegate)?
    private var isCapturing: Bool = false
    private var conflictLabel: NSTextField?
    private var savedStringValue: String = ""

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        enterCaptureMode()
    }

    // MARK: - Key

    override func keyDown(with event: NSEvent) {
        guard isCapturing else { super.keyDown(with: event); return }

        // Escape cancels capture
        if event.keyCode == 53 {
            exitCaptureMode()
            captureDelegate?.keyCaptureFieldDidCancel(self)
            return
        }

        // Require at least one modifier
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { return }

        let rawMods = UInt64(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
            & ShortcutBinding.modifierMask
        let binding = ShortcutBinding(keyCode: event.keyCode, modifiers: rawMods)

        if let action = targetAction {
            // Global hotkey capture
            do {
                try ShortcutRegistry.shared.updateBinding(binding, for: action)
                savedStringValue = binding.displayString
                exitCaptureMode()
                captureDelegate?.keyCaptureField(self, didCapture: binding, for: action)
            } catch ShortcutRegistryError.conflict(let conflicting) {
                showConflict(conflicting.description, for: action)
                captureDelegate?.keyCaptureField(self, conflictedWith: conflicting, for: action)
            } catch ShortcutRegistryError.editorConflict(let conflicting) {
                showConflict("Already used by: \(conflicting)", for: action)
            } catch {
                exitCaptureMode()
            }
        } else if let editorAction = targetEditorAction {
            // Editor shortcut capture
            do {
                try ShortcutRegistry.shared.updateEditorBinding(binding, for: editorAction)
                savedStringValue = binding.displayString
                exitCaptureMode()
            } catch ShortcutRegistryError.conflict(let conflicting) {
                showConflict("Already used by: \(conflicting.description)", for: .toggleVisibility)
            } catch ShortcutRegistryError.editorConflict(let conflicting) {
                showConflict("Already used by: \(conflicting)", for: .toggleVisibility)
            } catch {
                exitCaptureMode()
            }
        }
    }

    // MARK: - Capture Mode

    private func enterCaptureMode() {
        isCapturing = true
        placeholderString = "Type shortcut…"
        savedStringValue = stringValue
        stringValue = ""
        window?.makeFirstResponder(self)
        clearConflict()
    }

    private func exitCaptureMode() {
        isCapturing = false
        placeholderString = nil
        stringValue = savedStringValue
    }

    private func showConflict(_ message: String, for action: HotkeyAction) {
        clearConflict()
        let label = NSTextField(labelWithString: message)
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 11)
        label.translatesAutoresizingMaskIntoConstraints = false
        guard let sv = superview else { return }
        sv.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: bottomAnchor, constant: 2)
        ])
        conflictLabel = label
    }

    private func clearConflict() {
        conflictLabel?.removeFromSuperview()
        conflictLabel = nil
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool { true }
}
