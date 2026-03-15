// Sources/ClearText/Editor/ClearTextView.swift
import AppKit

final class ClearTextView: NSTextView {

    var hideAction: (() -> Void)?
    var textChangedAction: ((String) -> Void)?
    var tabIndex: Int = 1

    // MARK: - Init

    override convenience init(frame: NSRect) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        self.init(frame: frame, textContainer: textContainer)
    }

    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        isRichText = false
        importsGraphics = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticTextCompletionEnabled = false
        isGrammarCheckingEnabled = false
        isContinuousSpellCheckingEnabled = false
        // rulersVisible: N/A on this SDK — NSTextView has no ruler by default
        drawsBackground = false
        backgroundColor = .clear

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        self.shadow = shadow

        textColor = .labelColor
        insertionPointColor = .labelColor
        selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]

        applyFont(size: PersistenceManager.shared.loadFontSize())

        textContainerInset = NSSize(width: 12, height: 22)
    }

    func applyFont(size: Int) {
        font = NSFont(name: "SFMono-Regular", size: CGFloat(size))
            ?? NSFont.monospacedSystemFont(ofSize: CGFloat(size), weight: .regular)
    }

    // MARK: - keyDown

    override func keyDown(with event: NSEvent) {
        // Escape (keyCode 53, no modifiers) — hide panel
        if event.keyCode == 53 &&
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            hideAction?()
            return
        }

        let pressed = ShortcutBinding(
            keyCode: event.keyCode,
            modifiers: UInt64(event.modifierFlags
                .intersection(.deviceIndependentFlagsMask).rawValue)
                & ShortcutBinding.modifierMask
        )
        let registry = ShortcutRegistry.shared
        if pressed == registry.editorBinding(for: .selectWord)    { selectWordUnderCursor(); return }
        if pressed == registry.editorBinding(for: .deleteLine)    { deleteCurrentLine();     return }
        if pressed == registry.editorBinding(for: .duplicateLine) { duplicateCurrentLine();  return }
        if pressed == registry.editorBinding(for: .moveLineUp)    { moveLineUp();            return }
        if pressed == registry.editorBinding(for: .moveLineDown)  { moveLineDown();          return }
        if pressed == registry.editorBinding(for: .selectLine)    { selectEntireLine();      return }

        super.keyDown(with: event)
    }

    // MARK: - NSTextView change notification

    override func didChangeText() {
        super.didChangeText()
        textChangedAction?(string)
    }

    // MARK: - Text Manipulation

    func selectWordUnderCursor() {
        let range = selectionRange(forProposedRange: selectedRange(), granularity: .selectByWord)
        setSelectedRange(range)
    }

    func deleteCurrentLine() {
        guard let storage = textStorage else { return }
        let range = lineRange(for: selectedRange().location)
        let str = storage.string as NSString

        // NSString.lineRange includes the trailing \n for non-last lines.
        // For the last line (no trailing \n): extend left to also remove the preceding \n.
        var deleteRange = range
        let lineText = str.substring(with: range)
        if !lineText.hasSuffix("\n") && range.location > 0 {
            deleteRange = NSRange(location: range.location - 1, length: range.length + 1)
        }
        replaceCharacters(in: deleteRange, with: "")
    }

    func duplicateCurrentLine() {
        guard let storage = textStorage else { return }
        let range = lineRange(for: selectedRange().location)
        let lineText = (storage.string as NSString).substring(with: range)
        if lineText.hasSuffix("\n") {
            // Non-last line: insert a copy (without the trailing \n) after the current line's \n
            let textOnly = String(lineText.dropLast())
            replaceCharacters(in: NSRange(location: range.upperBound, length: 0), with: textOnly + "\n")
        } else {
            // Last line: prepend \n so the copy starts on a new line
            replaceCharacters(in: NSRange(location: range.upperBound, length: 0), with: "\n" + lineText)
        }
    }

    func moveLineUp() {
        guard let storage = textStorage else { return }
        let str = storage.string as NSString
        let currentRange = lineRange(for: selectedRange().location)
        guard currentRange.location > 0 else { return }
        let prevRange = lineRange(for: currentRange.location - 1)
        let currentLine = str.substring(with: currentRange)
        let prevLine = str.substring(with: prevRange)
        let combined = NSRange(location: prevRange.location,
                               length: prevRange.length + currentRange.length)
        replaceCharacters(in: combined, with: currentLine + prevLine)
        setSelectedRange(NSRange(location: prevRange.location, length: 0))
    }

    func moveLineDown() {
        guard let storage = textStorage else { return }
        let str = storage.string as NSString
        let currentRange = lineRange(for: selectedRange().location)
        guard currentRange.upperBound < str.length else { return }
        let nextRange = lineRange(for: currentRange.upperBound)
        let currentLine = str.substring(with: currentRange)
        let nextLine = str.substring(with: nextRange)
        let combined = NSRange(location: currentRange.location,
                               length: currentRange.length + nextRange.length)
        replaceCharacters(in: combined, with: nextLine + currentLine)
        setSelectedRange(NSRange(location: currentRange.location + nextRange.length, length: 0))
    }

    func selectEntireLine() {
        var range = lineRange(for: selectedRange().location)
        // Strip trailing \n from selection — select only the text content
        let str = string as NSString
        if range.length > 0 &&
           range.location + range.length <= str.length &&
           str.character(at: range.location + range.length - 1) == ("\n" as NSString).character(at: 0) {
            range = NSRange(location: range.location, length: range.length - 1)
        }
        setSelectedRange(range)
    }

    // MARK: - Helpers

    private func lineRange(for characterIndex: Int) -> NSRange {
        let str = string as NSString
        let safeIndex = min(max(characterIndex, 0), str.length)
        return str.lineRange(for: NSRange(location: safeIndex, length: 0))
    }
}
