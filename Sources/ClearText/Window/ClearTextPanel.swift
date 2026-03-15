// Sources/ClearText/Window/ClearTextPanel.swift
import AppKit

final class ClearTextPanel: NSPanel {

    static let alphaSteps: [CGFloat] = [0.3, 0.5, 0.7, 0.9, 1.0]
    private(set) var currentAlphaStep: Int = 2  // default 0.7
    private var hoverToOpaqueEnabled: Bool = false
    private var trackingArea: NSTrackingArea?
    weak var tabIndicator: TabIndicatorView?

    // MARK: - Init

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        self.delegate = self
        isFloatingPanel = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setFrameAutosaveName("ClearTextMainPanel")
        alphaValue = Self.alphaSteps[currentAlphaStep]

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        contentView = blur

        let indicator = TabIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: blur.topAnchor, constant: 8),
            indicator.widthAnchor.constraint(equalToConstant: 54),
            indicator.heightAnchor.constraint(equalToConstant: 6)
        ])
        self.tabIndicator = indicator
    }

    // MARK: - Transparency

    func stepAlphaUp() {
        setAlphaStep(min(currentAlphaStep + 1, Self.alphaSteps.count - 1))
    }

    func stepAlphaDown() {
        setAlphaStep(max(currentAlphaStep - 1, 0))
    }

    func setAlphaStep(_ step: Int) {
        currentAlphaStep = max(0, min(step, Self.alphaSteps.count - 1))
        animator().alphaValue = Self.alphaSteps[currentAlphaStep]
    }

    // MARK: - Always on Top

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }

    var isAlwaysOnTop: Bool { level == .floating }

    // MARK: - Hover to Opaque

    var isHoverToOpaqueEnabled: Bool { hoverToOpaqueEnabled }

    func setHoverToOpaque(_ enabled: Bool) {
        hoverToOpaqueEnabled = enabled
        updateTrackingArea()
        if !enabled {
            animator().alphaValue = Self.alphaSteps[currentAlphaStep]
        }
    }

    private func updateTrackingArea() {
        if let existing = trackingArea {
            contentView?.removeTrackingArea(existing)
        }
        trackingArea = nil
        guard hoverToOpaqueEnabled, let cv = contentView else { return }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: cv.bounds, options: opts, owner: self, userInfo: nil)
        cv.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard hoverToOpaqueEnabled else { return }
        animator().alphaValue = Self.alphaSteps[currentAlphaStep]
    }

    override func mouseExited(with event: NSEvent) {
        guard hoverToOpaqueEnabled else { return }
        animator().alphaValue = 0.2
    }

    // MARK: - NSPanel overrides

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - NSWindowDelegate

extension ClearTextPanel: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        guard hoverToOpaqueEnabled else { return }
        updateTrackingArea()
    }
}
