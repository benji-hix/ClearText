// Sources/ClearText/Hotkeys/ShortcutBinding.swift
import Carbon

/// A platform-independent representation of a keyboard shortcut.
struct ShortcutBinding: Equatable, Codable {
    let keyCode: UInt16
    /// Stored as UInt64 to match CGEventFlags.rawValue natively — avoids truncation of
    /// modifier flag bits. Only the four standard modifier bits are ever used.
    let modifiers: UInt64

    /// Mask covering exactly cmd (0x100000), opt (0x80000), ctrl (0x40000), shift (0x20000).
    static let modifierMask: UInt64 = 0x001E0000

    /// Human-readable string, e.g. "⌃⌥⇧⌘Space" (Apple HIG order: ctrl, opt, shift, cmd)
    var displayString: String {
        var parts = ""
        if modifiers & CGEventFlags.maskControl.rawValue != 0   { parts += "⌃" }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { parts += "⌥" }
        if modifiers & CGEventFlags.maskShift.rawValue != 0     { parts += "⇧" }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0   { parts += "⌘" }
        parts += keyCodeToGlyph(keyCode)
        return parts
    }

    private func keyCodeToGlyph(_ code: UInt16) -> String {
        switch code {
        case 49: return "Space"
        case 53: return "⎋"
        case 36: return "↩"
        case 51: return "⌫"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
                let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
                var chars = [UniChar](repeating: 0, count: 4)
                var length = 0
                var deadKeyState: UInt32 = 0
                data.withUnsafeBytes { raw in
                    let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!
                    UCKeyTranslate(layout, code, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, 4, &length, &chars)
                }
                if length > 0 { return String(chars[0]).uppercased() }
            }
            return "[\(code)]"
        }
    }
}
