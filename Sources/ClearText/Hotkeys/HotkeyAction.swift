// Sources/ClearText/Hotkeys/HotkeyAction.swift
import Foundation

enum HotkeyAction: Equatable {
    case toggleVisibility
    case toggleAlwaysOnTop
    case increaseTransparency
    case decreaseTransparency
    case toggleHoverToOpaque
    case switchToTab(Int)  // 1 or 2
}

extension HotkeyAction: CustomStringConvertible {
    var description: String {
        switch self {
        case .toggleVisibility:      return "Show / Hide ClearText"
        case .toggleAlwaysOnTop:     return "Toggle Always on Top"
        case .increaseTransparency:  return "Increase Transparency"
        case .decreaseTransparency:  return "Decrease Transparency"
        case .toggleHoverToOpaque:   return "Toggle Hover to Opaque"
        case .switchToTab(let n):    return "Switch to Tab \(n)"
        }
    }
}

@MainActor
protocol HotkeyDelegate: AnyObject {
    func hotkeyDidFire(_ action: HotkeyAction)
}
