// Sources/ClearText/App/AppDelegate.swift
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyDelegate {

    // MARK: - Owned objects
    private var statusItem: NSStatusItem!
    private var panel: ClearTextPanel!
    private var tabController: TabController!
    var hotkeyManager: HotkeyManager!  // internal access — read by PreferencesWindowController
    private var preferencesController: PreferencesWindowController?

    private weak var previousApp: NSRunningApplication?
    private var accessibilityMenuItem: NSMenuItem?

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupMenuBar()
        setupHotkeyManager()
        restoreState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        PersistenceManager.shared.flushImmediately()
    }

    // MARK: - Setup

    private func setupPanel() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = screen.visibleFrame.maxX - 480 - 20
        let y = screen.visibleFrame.minY + 20
        let rect = NSRect(x: x, y: y, width: 480, height: 320)

        panel = ClearTextPanel(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        panel.minSize = NSSize(width: 280, height: 160)

        tabController = TabController()
        if let contentView = panel.contentView {
            tabController.addToView(contentView)
        }

        // Wire tab indicator click → tab switch
        panel.tabIndicator?.onTabSelected = { [weak self] tab in
            self?.switchToTab(tab)
        }

        // Wire save + hide actions on each text view
        tabController.tab1.hideAction = { [weak self] in self?.hidePanel() }
        tabController.tab1.textChangedAction = { [weak self] content in
            PersistenceManager.shared.saveTabContentDebounced(content, tab: 1)
        }
        tabController.tab2.hideAction = { [weak self] in self?.hidePanel() }
        tabController.tab2.textChangedAction = { [weak self] content in
            PersistenceManager.shared.saveTabContentDebounced(content, tab: 2)
        }

        // Observe preference change notifications
        NotificationCenter.default.addObserver(
            forName: .clearTextAlphaStepChanged, object: nil, queue: .main
        ) { [weak self] note in
            if let step = note.object as? Int { self?.panel.setAlphaStep(step) }
        }
        NotificationCenter.default.addObserver(
            forName: .clearTextHoverToOpaqueChanged, object: nil, queue: .main
        ) { [weak self] note in
            if let on = note.object as? Bool { self?.panel.setHoverToOpaque(on) }
        }
        NotificationCenter.default.addObserver(
            forName: .clearTextFontSizeChanged, object: nil, queue: .main
        ) { [weak self] note in
            guard let size = note.object as? Int, let self else { return }
            self.tabController.tab1.applyFont(size: size)
            self.tabController.tab2.applyFont(size: size)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.on.rectangle",
                                   accessibilityDescription: "ClearText")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide ClearText", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))

        let axItem = NSMenuItem(title: "Grant Accessibility Access…",
                                action: #selector(openAccessibilitySettings),
                                keyEquivalent: "")
        axItem.isHidden = AXIsProcessTrusted()
        accessibilityMenuItem = axItem
        menu.addItem(axItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClearText",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager(registry: .shared)
        hotkeyManager.delegate = self
        hotkeyManager.panelVisibilityCheck = { [weak self] in self?.panel.isVisible ?? false }

        NotificationCenter.default.addObserver(
            forName: .clearTextAccessibilityDenied, object: nil, queue: .main
        ) { [weak self] _ in
            self?.accessibilityMenuItem?.isHidden = false
            self?.statusItem.button?.image = NSImage(
                systemSymbolName: "rectangle.on.rectangle.badge.exclamationmark",
                accessibilityDescription: "ClearText — Needs Accessibility")
            self?.statusItem.button?.image?.isTemplate = true
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.accessibilityMenuItem?.isHidden = true
                self?.statusItem.button?.image = NSImage(
                    systemSymbolName: "rectangle.on.rectangle",
                    accessibilityDescription: "ClearText")
                self?.statusItem.button?.image?.isTemplate = true
            }
        }

        hotkeyManager.start()
    }

    private func restoreState() {
        let pm = PersistenceManager.shared
        tabController.tab1.string = pm.loadTabContent(tab: 1)
        tabController.tab2.string = pm.loadTabContent(tab: 2)
        panel.setAlphaStep(pm.loadAlphaStep())
        if pm.loadAlwaysOnTopOnLaunch() { panel.setAlwaysOnTop(true) }
        panel.setHoverToOpaque(pm.loadHoverToOpaque())
    }

    // MARK: - Show / Hide

    @objc private func togglePanel() {
        if panel.isVisible { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        tabController.activeView.window?.makeFirstResponder(tabController.activeView)
    }

    private func hidePanel() {
        panel.orderOut(nil)
        _ = previousApp?.activate(from: NSRunningApplication.current)
        previousApp = nil
    }

    // MARK: - HotkeyDelegate

    func hotkeyDidFire(_ action: HotkeyAction) {
        switch action {
        case .toggleVisibility:
            togglePanel()
        case .toggleAlwaysOnTop:
            panel.setAlwaysOnTop(!panel.isAlwaysOnTop)
            PersistenceManager.shared.saveAlwaysOnTopOnLaunch(panel.isAlwaysOnTop)
        case .increaseTransparency:
            panel.stepAlphaUp()
            PersistenceManager.shared.saveAlphaStep(panel.currentAlphaStep)
        case .decreaseTransparency:
            panel.stepAlphaDown()
            PersistenceManager.shared.saveAlphaStep(panel.currentAlphaStep)
        case .toggleHoverToOpaque:
            let newValue = !panel.isHoverToOpaqueEnabled
            panel.setHoverToOpaque(newValue)
            PersistenceManager.shared.saveHoverToOpaque(newValue)
        case .switchToTab(let n) where panel.isVisible:
            switchToTab(n)
        default:
            break
        }
    }

    private func switchToTab(_ n: Int) {
        tabController.switchToTab(n)
        panel.tabIndicator?.activeTab = n
    }

    // MARK: - Menu Actions

    @objc private func openPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        NSApp.activate()
        preferencesController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
