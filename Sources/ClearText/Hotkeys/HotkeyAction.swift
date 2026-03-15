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

@MainActor
protocol HotkeyDelegate: AnyObject {
    func hotkeyDidFire(_ action: HotkeyAction)
}
