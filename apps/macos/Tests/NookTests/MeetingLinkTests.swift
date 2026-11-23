import XCTest

final class MeetingLinkTests: XCTestCase {
    func testFindsZoomInLocation() {
        let link = MeetingLink.find(in: [nil, "Room 4 / https://acme.zoom.us/j/123456789?pwd=abc.", "notes"])
        XCTAssertEqual(link?.service, .zoom)
        XCTAssertEqual(link?.url.absoluteString, "https://acme.zoom.us/j/123456789?pwd=abc")
    }

    func testPrefersTheEventURLOverNotes() {
        let link = MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij",
                                         "Join: https://teams.microsoft.com/l/meetup-join/19%3a"])
        XCTAssertEqual(link?.service, .meet)
    }

    func testFindsTeamsInNotes() {
        let notes = "Microsoft Teams meeting\nClick here to join (https://teams.microsoft.com/l/meetup-join/19%3ameeting_x)"
        XCTAssertEqual(MeetingLink.find(in: [nil, "", notes])?.service, .teams)
    }

    func testIgnoresHomePagesAndOtherSites() {
        XCTAssertNil(MeetingLink.find(in: ["https://zoom.us/", "https://example.com/meet", "Office"]))
        XCTAssertNil(MeetingLink.find(in: ["https://notzoom.us/j/1"]))
    }
}
