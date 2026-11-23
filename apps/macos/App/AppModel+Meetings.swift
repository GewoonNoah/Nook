import Foundation

/// Two minutes before a video call (an event with a Meet, Zoom, Teams … link) Nook says so next to the notch, with
/// "Join" as its button. Only while Nook may speak up (not in quiet mode, not over something you are doing), and once
/// per event.
@MainActor
final class CallReminder {
    static let shared = CallReminder()

    /// How long before the start Nook speaks up.
    static let lead: TimeInterval = 120

    private var wait: Task<Void, Never>?
    /// Events already reminded of, so a refresh does not remind twice.
    private var reminded: Set<String> = []

    /// Waits for the next call among `events` and calls `remind` with it at its time; a newer list replaces the wait.
    func schedule(_ events: [CalEvent], now: Date = Date(), remind: @escaping (CalEvent) -> Void) {
        wait?.cancel()
        guard let next = Self.next(in: events, now: now, skipping: reminded) else { return }
        let delay = max(next.start.timeIntervalSince(now) - Self.lead, 0)
        wait = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.reminded.insert(next.id)
            remind(next)
            // On to the call after it.
            self.schedule(events, remind: remind)
        }
    }

    /// The first call that has not started yet and was not reminded of, within the next six hours.
    static func next(in events: [CalEvent], now: Date, skipping: Set<String>) -> CalEvent? {
        events
            .filter { $0.meeting != nil && !$0.allDay && !skipping.contains($0.id) }
            .filter { $0.start > now && $0.start.timeIntervalSince(now) < 6 * 3600 }
            .min { $0.start < $1.start }
    }
}

extension AppModel {
    /// "Team meeting starts in 2 min" next to the notch, with Join.
    func remindToJoin(_ event: CalEvent) {
        guard let meeting = event.meeting, event.start > Date().addingTimeInterval(-60) else { return }
        let minutes = max(Int((event.start.timeIntervalSinceNow / 60).rounded()), 0)
        let line = minutes > 0 ? tr("call.soon", event.title, minutes) : tr("call.now", event.title)
        let moment = NookMoment(id: "call-\(event.id)", line: line, mood: .remind, action: .join(meeting.url),
                                actionTitle: tr("home.agenda.joinHelp", meeting.service.title), seconds: 30)
        _ = viewModel.offerMoment(moment)
    }
}
