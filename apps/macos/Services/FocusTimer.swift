import Foundation
import Combine

/// The focus session that runs, if one does: started from home's Focus card, it counts down and, once over, calls
/// `onFinish` (Nook then celebrates it next to the notch and offers a breather). One at a time; starting another
/// replaces it.
@MainActor
final class FocusTimer: ObservableObject {
    static let shared = FocusTimer()

    @Published private(set) var session: FocusSession?
    /// Called once when a session runs out (not when you stop it), with how many minutes it ran.
    var onFinish: ((Int) -> Void)?
    private var wait: Task<Void, Never>?

    var isRunning: Bool { session != nil }

    func start(minutes: Int, now: Date = Date()) {
        session = FocusSession(started: now, minutes: minutes)
        schedule()
    }

    /// Five more minutes (or `minutes`), for when you are nearly there.
    func extend(by minutes: Int = 5) {
        guard let session else { return }
        self.session = session.extended(by: minutes)
        schedule()
    }

    /// Ends it early, without the celebration.
    func stop() {
        wait?.cancel()
        wait = nil
        session = nil
    }

    /// Sleeps until the session's end, then finishes it; a new start or "+5" schedules again.
    private func schedule() {
        wait?.cancel()
        guard let session else { return }
        let seconds = max(session.remaining(at: Date()), 0)
        wait = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard let session else { return }
        let minutes = Int((session.length / 60).rounded())
        self.session = nil
        wait = nil
        onFinish?(minutes)
    }
}
