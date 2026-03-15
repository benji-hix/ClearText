// Tests/ClearTextTests/ClearTextViewTests.swift
import XCTest
@testable import ClearText

@MainActor
final class ClearTextViewTests: XCTestCase {
    var sut: ClearTextView!

    override func setUp() {
        super.setUp()
        sut = ClearTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        sut.string = ""
    }

    // MARK: - Select Word Under Cursor (Cmd+D)

    func test_selectWordUnderCursor_selectsCurrentWord() {
        sut.string = "hello world"
        sut.setSelectedRange(NSRange(location: 2, length: 0))
        sut.selectWordUnderCursor()
        XCTAssertEqual(sut.selectedRange(), NSRange(location: 0, length: 5))
    }

    func test_selectWordUnderCursor_whenOnWhitespace_selectsNextWord() {
        sut.string = "hello world"
        sut.setSelectedRange(NSRange(location: 5, length: 0))
        sut.selectWordUnderCursor()
        XCTAssertGreaterThan(sut.selectedRange().length, 0)
    }

    // MARK: - Delete Line (Cmd+Shift+K)

    func test_deleteCurrentLine_removesLineAndNewline() {
        sut.string = "line one\nline two\nline three"
        sut.setSelectedRange(NSRange(location: 0, length: 0))
        sut.deleteCurrentLine()
        XCTAssertEqual(sut.string, "line two\nline three")
    }

    func test_deleteCurrentLine_lastLine_noTrailingNewline() {
        sut.string = "line one\nline two"
        sut.setSelectedRange(NSRange(location: 10, length: 0))
        sut.deleteCurrentLine()
        XCTAssertEqual(sut.string, "line one")
    }

    func test_deleteCurrentLine_onlyLine() {
        sut.string = "only line"
        sut.setSelectedRange(NSRange(location: 0, length: 0))
        sut.deleteCurrentLine()
        XCTAssertEqual(sut.string, "")
    }

    // MARK: - Duplicate Line (Cmd+Shift+D)

    func test_duplicateLine_insertsLineCopyBelow() {
        sut.string = "hello\nworld"
        sut.setSelectedRange(NSRange(location: 0, length: 0))
        sut.duplicateCurrentLine()
        XCTAssertEqual(sut.string, "hello\nhello\nworld")
    }

    // MARK: - Move Line (Opt+Up / Opt+Down)

    func test_moveLineUp_swapsWithPreviousLine() {
        sut.string = "line one\nline two\nline three"
        sut.setSelectedRange(NSRange(location: 10, length: 0))
        sut.moveLineUp()
        XCTAssertEqual(sut.string, "line two\nline one\nline three")
    }

    func test_moveLineDown_swapsWithNextLine() {
        sut.string = "line one\nline two\nline three"
        sut.setSelectedRange(NSRange(location: 0, length: 0))
        sut.moveLineDown()
        XCTAssertEqual(sut.string, "line two\nline one\nline three")
    }

    func test_moveLineUp_atFirstLine_doesNothing() {
        sut.string = "line one\nline two"
        sut.setSelectedRange(NSRange(location: 0, length: 0))
        sut.moveLineUp()
        XCTAssertEqual(sut.string, "line one\nline two")
    }

    func test_moveLineDown_atLastLine_doesNothing() {
        sut.string = "line one\nline two"
        sut.setSelectedRange(NSRange(location: 10, length: 0))
        sut.moveLineDown()
        XCTAssertEqual(sut.string, "line one\nline two")
    }

    // MARK: - Select Line (Cmd+L)

    func test_selectEntireLine_selectsLineContent() {
        sut.string = "hello\nworld"
        sut.setSelectedRange(NSRange(location: 0, length: 0))
        sut.selectEntireLine()
        // lineRange returns "hello\n" — selectEntireLine strips the \n
        XCTAssertEqual(sut.selectedRange(), NSRange(location: 0, length: 5))
    }

    func test_deleteCurrentLine_cursorAtEndOfDocument() {
        sut.string = "line one\nline two"
        sut.setSelectedRange(NSRange(location: 16, length: 0))
        sut.deleteCurrentLine()
        XCTAssertEqual(sut.string, "line one")
    }

    func test_selectEntireLine_cursorAtEndOfDocument() {
        sut.string = "hello\nworld"
        sut.setSelectedRange(NSRange(location: 10, length: 0))
        sut.selectEntireLine()
        XCTAssertEqual(sut.selectedRange(), NSRange(location: 6, length: 5))
    }
}
