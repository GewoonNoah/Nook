import XCTest

final class FocusSessionTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func testProgressAndRemaining() {
        let session = FocusSession(started: start, minutes: 25)
        XCTAssertEqual(session.progress(at: start), 0)
        XCTAssertEqual(session.progress(at: start.addingTimeInterval(750)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(60)), 24 * 60)
        XCTAssertFalse(session.isOver(at: start.addingTimeInterval(24 * 60)))
        XCTAssertTrue(session.isOver(at: start.addingTimeInterval(25 * 60)))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(9999)), 0)
        XCTAssertEqual(session.progress(at: start.addingTimeInterval(9999)), 1)
    }

    func testExtendingIsCapped() {
        let session = FocusSession(started: start, minutes: 25).extended(by: 5)
        XCTAssertEqual(session.length, 30 * 60)
        XCTAssertEqual(FocusSession(started: start, minutes: 230).extended(by: 60).length, FocusSession.longest)
    }

    func testClock() {
        XCTAssertEqual(FocusSession.clock(25 * 60), "25:00")
        XCTAssertEqual(FocusSession.clock(59.2), "1:00")
        XCTAssertEqual(FocusSession.clock(3 * 3600 + 61), "3:01:01")
        XCTAssertEqual(FocusSession.clock(0), "0:00")
    }
}
