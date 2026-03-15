// Tests/ClearTextTests/TabControllerTests.swift
import XCTest
@testable import ClearText

@MainActor
final class TabControllerTests: XCTestCase {
    var sut: TabController!

    override func setUp() {
        super.setUp()
        sut = TabController()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_initiallyActiveTabIsOne() {
        XCTAssertEqual(sut.activeTabIndex, 1)
    }

    func test_switchToTab2_makesTab2Active() {
        sut.switchToTab(2)
        XCTAssertEqual(sut.activeTabIndex, 2)
        XCTAssertTrue(sut.scrollView1.isHidden)
        XCTAssertFalse(sut.scrollView2.isHidden)
    }

    func test_switchToTab1_makesTab1Active() {
        sut.switchToTab(2)
        sut.switchToTab(1)
        XCTAssertEqual(sut.activeTabIndex, 1)
        XCTAssertFalse(sut.scrollView1.isHidden)
        XCTAssertTrue(sut.scrollView2.isHidden)
    }

    func test_activeView_returnsCorrectView() {
        XCTAssertTrue(sut.activeView === sut.tab1)
        sut.switchToTab(2)
        XCTAssertTrue(sut.activeView === sut.tab2)
    }

    func test_switchToInvalidTab_doesNothing() {
        sut.switchToTab(3)
        XCTAssertEqual(sut.activeTabIndex, 1)
    }
}
