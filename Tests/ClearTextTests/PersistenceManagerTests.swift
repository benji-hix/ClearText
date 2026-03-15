// Tests/ClearTextTests/PersistenceManagerTests.swift
import XCTest
@testable import ClearText

@MainActor
final class PersistenceManagerTests: XCTestCase {
    var sut: PersistenceManager!
    var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "cleartext.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        sut = PersistenceManager(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func test_saveAndLoadTabContent() {
        sut.saveTabContent("hello world", tab: 1)
        sut.flushImmediately()
        XCTAssertEqual(sut.loadTabContent(tab: 1), "hello world")
    }

    func test_saveTab2DoesNotAffectTab1() {
        sut.saveTabContent("tab one", tab: 1)
        sut.saveTabContent("tab two", tab: 2)
        sut.flushImmediately()
        XCTAssertEqual(sut.loadTabContent(tab: 1), "tab one")
        XCTAssertEqual(sut.loadTabContent(tab: 2), "tab two")
    }

    func test_loadEmptyTabReturnsEmptyString() {
        XCTAssertEqual(sut.loadTabContent(tab: 1), "")
        XCTAssertEqual(sut.loadTabContent(tab: 2), "")
    }

    func test_saveAndLoadAlphaStep() {
        sut.saveAlphaStep(3)
        XCTAssertEqual(sut.loadAlphaStep(), 3)
    }

    func test_alphaStepDefaultIsTwo() {
        XCTAssertEqual(sut.loadAlphaStep(), 2)
    }

    func test_saveAndLoadFontSize() {
        sut.saveFontSize(18)
        XCTAssertEqual(sut.loadFontSize(), 18)
    }

    func test_fontSizeDefaultIs13() {
        XCTAssertEqual(sut.loadFontSize(), 13)
    }

    func test_boolPreferences() {
        sut.saveAlwaysOnTopOnLaunch(true)
        XCTAssertTrue(sut.loadAlwaysOnTopOnLaunch())
        sut.saveHoverToOpaque(true)
        XCTAssertTrue(sut.loadHoverToOpaque())
        sut.saveLaunchAtLogin(true)
        XCTAssertTrue(sut.loadLaunchAtLogin())
    }

    func test_boolPreferencesDefaultFalse() {
        XCTAssertFalse(sut.loadAlwaysOnTopOnLaunch())
        XCTAssertFalse(sut.loadHoverToOpaque())
        XCTAssertFalse(sut.loadLaunchAtLogin())
    }

    func test_debouncedSaveEventuallyPersists() {
        sut.saveTabContentDebounced("deferred", tab: 1)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.7))
        XCTAssertEqual(sut.loadTabContent(tab: 1), "deferred")
    }

    func test_flushImmediatelySavesPendingDebouncedContent() {
        sut.saveTabContentDebounced("pending content", tab: 1)
        sut.flushImmediately()
        XCTAssertEqual(sut.loadTabContent(tab: 1), "pending content")
    }

    func test_flushImmediatelyWithDirectSave_keepsMostRecentContent() {
        sut.saveTabContent("immediate", tab: 1)
        // Debounce queues "pending-debounced" AFTER the direct save — it's the newer value
        sut.saveTabContentDebounced("pending-debounced", tab: 1)
        // flush commits the pending debounce, so "pending-debounced" (the newer) wins
        sut.flushImmediately()
        XCTAssertEqual(sut.loadTabContent(tab: 1), "pending-debounced")
    }
}
