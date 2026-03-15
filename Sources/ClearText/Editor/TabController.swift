// Sources/ClearText/Editor/TabController.swift
import AppKit

final class TabController {

    let tab1: ClearTextView
    let tab2: ClearTextView
    /// Expose scroll views for hiding/showing — hiding ClearTextView alone does not hide its wrapper.
    let scrollView1: NSScrollView
    let scrollView2: NSScrollView
    private(set) var activeTabIndex: Int = 1

    var activeView: ClearTextView {
        activeTabIndex == 1 ? tab1 : tab2
    }

    init() {
        (tab1, scrollView1) = TabController.makeScrolled(tabIndex: 1)
        (tab2, scrollView2) = TabController.makeScrolled(tabIndex: 2)
        scrollView2.isHidden = true
    }

    func switchToTab(_ index: Int) {
        guard index == 1 || index == 2 else { return }
        activeTabIndex = index
        scrollView1.isHidden = (index != 1)
        scrollView2.isHidden = (index != 2)
    }

    func addToView(_ containerView: NSView) {
        for scrollView in [scrollView1, scrollView2] {
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
    }

    // MARK: - Private

    private static func makeScrolled(tabIndex: Int) -> (ClearTextView, NSScrollView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let view = ClearTextView(frame: scrollView.bounds)
        view.tabIndex = tabIndex
        view.autoresizingMask = [.width]
        view.isVerticallyResizable = true
        view.minSize = NSSize(width: 0, height: scrollView.bounds.height)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                              height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: scrollView.bounds.width,
                                                    height: .greatestFiniteMagnitude)
        scrollView.documentView = view
        return (view, scrollView)
    }
}
