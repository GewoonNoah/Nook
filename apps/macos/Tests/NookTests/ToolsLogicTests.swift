import XCTest

final class ToolsLogicTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    // MARK: Units

    func testConvertsLengthAndTemperature() {
        XCTAssertEqual(UnitConversion.convert("5 km to mi")?.text, "3.1069 mi")
        XCTAssertEqual(UnitConversion.convert("100 c in f")?.text, "212 f")
        XCTAssertEqual(UnitConversion.convert("3,5 kg naar lb")?.value ?? 0, 7.7162, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.convert("12 in to cm")?.text, "30.48 cm")
    }

    func testRefusesMismatchedOrUnknownUnits() {
        XCTAssertNil(UnitConversion.convert("5 km to kg"))
        XCTAssertNil(UnitConversion.convert("5 bananas to mi"))
        XCTAssertNil(UnitConversion.convert("hello"))
    }

    func testFormat() {
        XCTAssertEqual(UnitConversion.format(68), "68")
        XCTAssertEqual(UnitConversion.format(0.5), "0.5")
        XCTAssertEqual(UnitConversion.format(1.234567), "1.2346")
    }

    // MARK: Habits

    func testStreakCountsDaysInARow() {
        var habit = Habit(title: "Walk")
        for day in [20, 21, 22, 23] { habit.toggle(on: date(day), calendar: calendar) }
        XCTAssertEqual(habit.streak(at: date(23), calendar: calendar), 4)
        // Today not done yet: yesterday's streak still counts.
        XCTAssertEqual(habit.streak(at: date(24), calendar: calendar), 4)
        // A day missed: the streak is over.
        XCTAssertEqual(habit.streak(at: date(25), calendar: calendar), 0)
        habit.toggle(on: date(22), calendar: calendar)
        XCTAssertEqual(habit.streak(at: date(23), calendar: calendar), 1)
        XCTAssertEqual(habit.lastDays(4, at: date(23), calendar: calendar), [true, true, false, true])
    }

    // MARK: Countdowns

    func testDaysLeft() {
        let holiday = Countdown(title: "Holiday", date: date(30, hour: 8))
        XCTAssertEqual(holiday.daysLeft(at: date(24, hour: 23), calendar: calendar), 6)
        XCTAssertEqual(holiday.daysLeft(at: date(30, hour: 20), calendar: calendar), 0)
    }

    // MARK: World clock

    func testOffsets() {
        let tokyo = WorldCity(name: "Tokyo", zone: "Asia/Tokyo")
        let mumbai = WorldCity(name: "Mumbai", zone: "Asia/Kolkata")
        let here = TimeZone(identifier: "Europe/Amsterdam")!
        let winter = date(24)
        XCTAssertEqual(tokyo.offset(from: here, at: winter), "+8")
        XCTAssertEqual(mumbai.offset(from: here, at: winter), "+4:30")
        XCTAssertEqual(WorldCity(name: "A", zone: "Europe/Amsterdam").offset(from: here, at: winter), "")
    }

    // MARK: Clipboard

    func testClipboardSkipsSecretsAndDeduplicates() {
        XCTAssertFalse(ClipboardPolicy.keeps(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"], text: "hunter2"))
        XCTAssertFalse(ClipboardPolicy.keeps(types: ["public.utf8-plain-text"], text: "  "))
        XCTAssertTrue(ClipboardPolicy.keeps(types: ["public.utf8-plain-text"], text: "hello"))
        XCTAssertEqual(ClipboardPolicy.adding("b", to: ["a", "b", "c"]), ["b", "a", "c"])
    }
}
