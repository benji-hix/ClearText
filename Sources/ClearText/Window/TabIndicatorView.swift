// Sources/ClearText/Window/TabIndicatorView.swift
import AppKit

final class TabIndicatorView: NSView {

    var activeTab: Int = 1 { didSet { needsDisplay = true } }
    var onTabSelected: ((Int) -> Void)?

    private let pillSize = NSSize(width: 24, height: 6)
    private let pillSpacing: CGFloat = 6
    private let cornerRadius: CGFloat = 3

    override var intrinsicContentSize: NSSize {
        NSSize(width: pillSize.width * 2 + pillSpacing, height: pillSize.height)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        for tab in 1...2 {
            let rect = pillRect(for: tab)
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            pillColor(for: tab).setFill()
            path.fill()
        }
    }

    private func pillRect(for tab: Int) -> NSRect {
        let totalWidth = pillSize.width * 2 + pillSpacing
        let startX = (bounds.width - totalWidth) / 2
        let x = tab == 1 ? startX : startX + pillSize.width + pillSpacing
        let y = (bounds.height - pillSize.height) / 2
        return NSRect(origin: NSPoint(x: x, y: y), size: pillSize)
    }

    private func pillColor(for tab: Int) -> NSColor {
        if tab == activeTab {
            return NSColor.controlAccentColor.withAlphaComponent(0.6)
        } else {
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return (isDark ? NSColor.white : NSColor.black).withAlphaComponent(0.2)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for tab in 1...2 {
            if pillRect(for: tab).contains(point) {
                onTabSelected?(tab)
                return
            }
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
