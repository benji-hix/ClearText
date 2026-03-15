// Sources/ClearText/Preferences/PreferencesWindowController.swift
import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController {

    // MARK: - Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClearText Preferences"
        window.isRestorable = false
        self.init(window: window)
        window.center()
        loadContent()
    }

    // MARK: - UI Construction

    private func loadContent() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        let appearanceTab = NSTabViewItem(identifier: "appearance")
        appearanceTab.label = "Appearance"
        appearanceTab.view = makeAppearanceView()
        tabView.addTabViewItem(appearanceTab)

        let shortcutsTab = NSTabViewItem(identifier: "shortcuts")
        shortcutsTab.label = "Shortcuts"
        shortcutsTab.view = makeShortcutsView()
        tabView.addTabViewItem(shortcutsTab)
    }

    // MARK: - Appearance Tab

    private func makeAppearanceView() -> NSView {
        let view = NSView()
        let pm = PersistenceManager.shared
        var yOffset: CGFloat = 200

        func addLabel(_ text: String) {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 16, y: yOffset, width: 180, height: 22)
            view.addSubview(label)
        }

        // Transparency stepper (5 steps)
        addLabel("Transparency level:")
        let alphaSegment = NSSegmentedControl(
            labels: ["30%", "50%", "70%", "90%", "100%"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(alphaStepChanged(_:))
        )
        alphaSegment.selectedSegment = pm.loadAlphaStep()
        alphaSegment.frame = NSRect(x: 200, y: yOffset, width: 170, height: 24)
        view.addSubview(alphaSegment)
        yOffset -= 36

        // Always on top
        addLabel("Always on top at launch:")
        let alwaysOnTopCheck = NSButton(checkboxWithTitle: "", target: self, action: #selector(alwaysOnTopChanged(_:)))
        alwaysOnTopCheck.state = pm.loadAlwaysOnTopOnLaunch() ? .on : .off
        alwaysOnTopCheck.frame = NSRect(x: 200, y: yOffset, width: 24, height: 24)
        view.addSubview(alwaysOnTopCheck)
        yOffset -= 36

        // Hover to opaque
        addLabel("Hover to show (opacity):")
        let hoverCheck = NSButton(checkboxWithTitle: "", target: self, action: #selector(hoverToOpaqueChanged(_:)))
        hoverCheck.state = pm.loadHoverToOpaque() ? .on : .off
        hoverCheck.frame = NSRect(x: 200, y: yOffset, width: 24, height: 24)
        view.addSubview(hoverCheck)
        yOffset -= 36

        // Font size
        addLabel("Font size:")
        let fontStepper = NSStepper()
        fontStepper.minValue = 10; fontStepper.maxValue = 24; fontStepper.increment = 1
        fontStepper.integerValue = pm.loadFontSize()
        fontStepper.target = self; fontStepper.action = #selector(fontSizeChanged(_:))
        fontStepper.frame = NSRect(x: 200, y: yOffset, width: 42, height: 24)
        let fontSizeLabel = NSTextField(labelWithString: "\(pm.loadFontSize())pt")
        fontSizeLabel.frame = NSRect(x: 248, y: yOffset, width: 50, height: 24)
        fontSizeLabel.tag = 99
        view.addSubview(fontStepper)
        view.addSubview(fontSizeLabel)
        yOffset -= 36

        // Launch at login
        addLabel("Launch at login:")
        let loginCheck = NSButton(checkboxWithTitle: "", target: self, action: #selector(launchAtLoginChanged(_:)))
        loginCheck.state = pm.loadLaunchAtLogin() ? .on : .off
        loginCheck.frame = NSRect(x: 200, y: yOffset, width: 24, height: 24)
        view.addSubview(loginCheck)

        return view
    }

    // MARK: - Shortcuts Tab

    private func makeShortcutsView() -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        let container = NSView()

        let actions: [(String, HotkeyAction)] = [
            ("Show / Hide window", .toggleVisibility),
            ("Toggle always-on-top", .toggleAlwaysOnTop),
            ("Increase transparency", .increaseTransparency),
            ("Decrease transparency", .decreaseTransparency),
            ("Toggle hover opacity", .toggleHoverToOpaque),
            ("Switch to Tab 1", .switchToTab(1)),
            ("Switch to Tab 2", .switchToTab(2)),
        ]

        var yOffset: CGFloat = CGFloat(actions.count) * 36 + 40
        for (label, action) in actions {
            let nameLabel = NSTextField(labelWithString: label)
            nameLabel.frame = NSRect(x: 16, y: yOffset, width: 180, height: 22)
            container.addSubview(nameLabel)

            let captureField = KeyCaptureField()
            captureField.stringValue = ShortcutRegistry.shared.binding(for: action).displayString
            captureField.frame = NSRect(x: 200, y: yOffset, width: 130, height: 24)
            captureField.targetAction = action
            captureField.captureDelegate = self
            captureField.bezelStyle = .squareBezel
            container.addSubview(captureField)
            yOffset -= 36
        }

        // Reset button
        let resetBtn = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetShortcuts))
        resetBtn.frame = NSRect(x: 200, y: 8, width: 150, height: 28)
        container.addSubview(resetBtn)

        container.frame = NSRect(x: 0, y: 0, width: 360, height: CGFloat(actions.count) * 36 + 60)
        scrollView.documentView = container
        return scrollView
    }

    // MARK: - Actions

    @objc private func alphaStepChanged(_ sender: NSSegmentedControl) {
        PersistenceManager.shared.saveAlphaStep(sender.selectedSegment)
        NotificationCenter.default.post(name: .clearTextAlphaStepChanged, object: sender.selectedSegment)
    }

    @objc private func alwaysOnTopChanged(_ sender: NSButton) {
        PersistenceManager.shared.saveAlwaysOnTopOnLaunch(sender.state == .on)
    }

    @objc private func hoverToOpaqueChanged(_ sender: NSButton) {
        let on = sender.state == .on
        PersistenceManager.shared.saveHoverToOpaque(on)
        NotificationCenter.default.post(name: .clearTextHoverToOpaqueChanged, object: on)
    }

    @objc private func fontSizeChanged(_ sender: NSStepper) {
        let size = sender.integerValue
        PersistenceManager.shared.saveFontSize(size)
        if let label = window?.contentView?.viewWithTag(99) as? NSTextField {
            label.stringValue = "\(size)pt"
        }
        NotificationCenter.default.post(name: .clearTextFontSizeChanged, object: size)
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let on = sender.state == .on
        PersistenceManager.shared.saveLaunchAtLogin(on)
        if on {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    @objc private func resetShortcuts() {
        ShortcutRegistry.shared.resetToDefaults()
        hotkeyManager?.refreshBindingTable()
        // Rebuild the view from scratch
        window?.contentView?.subviews.forEach { $0.removeFromSuperview() }
        loadContent()
    }

    private var hotkeyManager: HotkeyManager? {
        (NSApp.delegate as? AppDelegate)?.hotkeyManager
    }
}

// MARK: - KeyCaptureFieldDelegate

extension PreferencesWindowController: KeyCaptureFieldDelegate {
    nonisolated func keyCaptureField(_ field: KeyCaptureField, didCapture binding: ShortcutBinding, for action: HotkeyAction) {
        MainActor.assumeIsolated {
            hotkeyManager?.refreshBindingTable()
        }
    }
    nonisolated func keyCaptureField(_ field: KeyCaptureField, conflictedWith conflicting: HotkeyAction, for action: HotkeyAction) {}
    nonisolated func keyCaptureFieldDidCancel(_ field: KeyCaptureField) {}
}
