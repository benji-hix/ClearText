// Sources/ClearText/Hotkeys/HotkeyManager.swift
import AppKit
import Carbon

final class HotkeyManager: @unchecked Sendable {
    weak var delegate: (any HotkeyDelegate)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let registry: ShortcutRegistry
    /// Retained pointer passed into the CGEventTap callback — released in stop().
    private var selfPtr: Unmanaged<HotkeyManager>?

    /// In-memory snapshot of all bindings, refreshed on shortcut changes.
    private var bindingTable: [(HotkeyAction, ShortcutBinding)] = []
    private let tableLock = NSLock()

    /// Set by AppDelegate; consulted before consuming switchToTab events.
    /// Safe to read from the tap callback since the tap runs on CFRunLoopGetMain (main thread).
    var panelVisibilityCheck: (() -> Bool)?

    init(registry: ShortcutRegistry = .shared) {
        self.registry = registry
        refreshBindingTable()
    }

    // MARK: - Setup

    func start() {
        guard AXIsProcessTrusted() else {
            let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            NotificationCenter.default.post(name: .clearTextAccessibilityDenied, object: nil)
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(accessibilityStatusChanged),
                name: NSNotification.Name("com.apple.accessibility.api"),
                object: nil
            )
            return
        }
        installTap()
    }

    @objc private func accessibilityStatusChanged() {
        guard AXIsProcessTrusted() else { return }
        DistributedNotificationCenter.default().removeObserver(self)
        DispatchQueue.main.async { [weak self] in self?.installTap() }
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        selfPtr?.release()  // balance the passRetained from installTap
        selfPtr = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func refreshBindingTable() {
        let snapshot = registry.allBindings()
        tableLock.lock()
        bindingTable = snapshot
        tableLock.unlock()
    }

    // MARK: - Private

    private func installTap() {
        // .commonModes ensures the tap fires even when a modal panel is tracking events.
        // .headInsertEventTap places this tap first in the chain so it can consume shortcuts
        // before other apps or system handlers see them.
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let retained = Unmanaged.passRetained(self)
        selfPtr = retained

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard type == .keyDown, let ref = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ref).takeUnretainedValue()
                return manager.handleEvent(event)
            },
            userInfo: retained.toOpaque()
        )

        guard let tap = eventTap else {
            retained.release()
            selfPtr = nil
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource!, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let rawMods = event.flags.rawValue & ShortcutBinding.modifierMask

        tableLock.lock()
        let table = bindingTable
        tableLock.unlock()

        for (action, binding) in table {
            if binding.keyCode == keyCode && binding.modifiers == rawMods {
                if case .switchToTab = action, !(panelVisibilityCheck?() ?? false) {
                    return Unmanaged.passUnretained(event)
                }
                // Tap fires on main thread — safe to assume main actor isolation
                MainActor.assumeIsolated {
                    delegate?.hotkeyDidFire(action)
                }
                return nil  // consume the event
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Testability

    func bindingTableSnapshot() -> [(HotkeyAction, ShortcutBinding)] {
        tableLock.lock()
        defer { tableLock.unlock() }
        return bindingTable
    }
}

extension Notification.Name {
    static let clearTextAccessibilityDenied = Notification.Name("clearTextAccessibilityDenied")
}
