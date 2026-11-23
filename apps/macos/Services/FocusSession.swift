import Foundation

/// A stretch of focused work you start from Nook's home ("Focus for 25 minutes"): when it started and how long it runs,
/// so the ring can show how far along it is and Nook can say when it is over. Foundation only, so it is tested anywhere;
/// `FocusTimer` keeps the one that runs.
struct FocusSession: Equatable, Sendable {
    let started: Date
    /// How long it runs, minutes added with "+5" included.
    var length: TimeInterval

    /// The lengths home offers, in minutes.
    static let presets = [25, 50, 90]
    /// The longest a session may run once extended.
    static let longest: TimeInterval = 4 * 3600

    init(started: Date, minutes: Int) {
        self.started = started
        self.length = TimeInterval(max(minutes, 1)) * 60
    }

    var ends: Date { started.addingTimeInterval(length) }

    /// The seconds left at `now`, never below zero.
    func remaining(at now: Date) -> TimeInterval { max(ends.timeIntervalSince(now), 0) }

    /// How far along it is at `now`, from 0 (just started) to 1 (over).
    func progress(at now: Date) -> Double {
        guard length > 0 else { return 1 }
        return min(max(now.timeIntervalSince(started) / length, 0), 1)
    }

    func isOver(at now: Date) -> Bool { now >= ends }

    /// The same session with `minutes` more, at most `longest` in all.
    func extended(by minutes: Int) -> FocusSession {
        var copy = self
        copy.length = min(length + TimeInterval(minutes) * 60, Self.longest)
        return copy
    }

    /// The time left as the ring shows it: "24:59", or "1:04:59" past an hour.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600, minutes = (total % 3600) / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }
}
