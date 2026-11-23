import Foundation

/// A small daily habit you tick off in the Tools tab ("Read 10 pages", "Walk"): the days it was done, so the tab can say
/// how many days in a row. Foundation only, so it is tested anywhere; `HabitStore` keeps them in the user defaults.
struct Habit: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    /// The days it was done, as "2026-11-24" in the user's calendar.
    var done: Set<String> = []

    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func isDone(on date: Date, calendar: Calendar = .current) -> Bool { done.contains(Self.day(date, calendar: calendar)) }

    /// Ticks `date` off, or takes the tick back.
    mutating func toggle(on date: Date, calendar: Calendar = .current) {
        let key = Self.day(date, calendar: calendar)
        if done.contains(key) { done.remove(key) } else { done.insert(key) }
    }

    /// Days in a row up to today; a streak that ran until yesterday still counts while today is not done yet.
    func streak(at now: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: now)
        if !isDone(on: day, calendar: calendar) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while isDone(on: day, calendar: calendar) {
            count += 1
            guard let before = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = before
        }
        return count
    }

    /// The last `count` days, oldest first, with whether each was done: the row of dots under a habit.
    func lastDays(_ count: Int, at now: Date, calendar: Calendar = .current) -> [Bool] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().map { back in
            calendar.date(byAdding: .day, value: -back, to: today).map { isDone(on: $0, calendar: calendar) } ?? false
        }
    }
}

/// A date you count down to in the Tools tab ("Holiday", "Exam"): how many days are left.
struct Countdown: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var date: Date

    /// Whole days from today to its day: 0 on the day itself, negative once it has passed.
    func daysLeft(at now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}

/// A place on the world clock: its time zone and what to call it.
struct WorldCity: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: String { zone }
    let name: String
    /// A time zone identifier ("Asia/Tokyo").
    let zone: String

    var timeZone: TimeZone? { TimeZone(identifier: zone) }

    /// Hours ahead of (or behind) `here` at `now`: "+8", "−5", "+5:30", or "" when it is the same.
    func offset(from here: TimeZone, at now: Date) -> String {
        guard let timeZone else { return "" }
        let seconds = timeZone.secondsFromGMT(for: now) - here.secondsFromGMT(for: now)
        guard seconds != 0 else { return "" }
        let sign = seconds > 0 ? "+" : "−"
        let hours = abs(seconds) / 3600, minutes = (abs(seconds) % 3600) / 60
        // Interpolation, not String(format: "%@"): a Swift String is no C argument on Linux, where the core tests run.
        return minutes == 0 ? "\(sign)\(hours)" : "\(sign)\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
    }

    /// Whether it is daytime there (7:00 to 19:00), for the sun or moon beside it.
    func isDaytime(at now: Date) -> Bool {
        guard let timeZone else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: now)
        return (7..<19).contains(hour)
    }

    /// Cities the world clock offers to add.
    static let suggestions: [WorldCity] = [
        WorldCity(name: "Amsterdam", zone: "Europe/Amsterdam"), WorldCity(name: "London", zone: "Europe/London"),
        WorldCity(name: "New York", zone: "America/New_York"), WorldCity(name: "San Francisco", zone: "America/Los_Angeles"),
        WorldCity(name: "Chicago", zone: "America/Chicago"), WorldCity(name: "São Paulo", zone: "America/Sao_Paulo"),
        WorldCity(name: "Dubai", zone: "Asia/Dubai"), WorldCity(name: "Mumbai", zone: "Asia/Kolkata"),
        WorldCity(name: "Singapore", zone: "Asia/Singapore"), WorldCity(name: "Tokyo", zone: "Asia/Tokyo"),
        WorldCity(name: "Sydney", zone: "Australia/Sydney"), WorldCity(name: "Auckland", zone: "Pacific/Auckland"),
        WorldCity(name: "Berlin", zone: "Europe/Berlin"), WorldCity(name: "Paris", zone: "Europe/Paris"),
        WorldCity(name: "Madrid", zone: "Europe/Madrid"), WorldCity(name: "Istanbul", zone: "Europe/Istanbul"),
        WorldCity(name: "Hong Kong", zone: "Asia/Hong_Kong"), WorldCity(name: "Toronto", zone: "America/Toronto"),
    ]
}

/// What the clipboard history keeps and what it leaves alone. Password managers and other apps mark secrets as
/// concealed or transient on the pasteboard (nspasteboard.org); those are never kept.
enum ClipboardPolicy {
    /// Pasteboard types that mark a copy as not for history.
    static let privateTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword", "com.typeit4me.clipping", "de.petermaurer.TransientPasteboardType",
        "Pasteboard generator type", "com.apple.is-remote-clipboard",
    ]

    /// How many copies the history keeps.
    static let limit = 30

    /// Whether a copy with these types and text belongs in the history.
    static func keeps(types: [String], text: String?) -> Bool {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return !types.contains { privateTypes.contains($0) }
    }

    /// The history with `text` on top: an earlier copy of the same text moves up instead of showing twice.
    static func adding(_ text: String, to history: [String]) -> [String] {
        Array(([text] + history.filter { $0 != text }).prefix(limit))
    }
}
