import AppKit
import Combine
import Foundation
import IOKit.pwr_mgt

/// What the Tools tab keeps between launches: your habits, countdowns, world clock, scratch note and picked colors, in
/// the user defaults on this Mac. Nothing here leaves the Mac.
@MainActor
final class ToolsStore: ObservableObject {
    static let shared = ToolsStore()

    @Published var habits: [Habit] { didSet { save(habits, "tools.habits") } }
    @Published var countdowns: [Countdown] { didSet { save(countdowns, "tools.countdowns") } }
    @Published var cities: [WorldCity] { didSet { save(cities, "tools.cities") } }
    @Published var note: String { didSet { UserDefaults.standard.set(note, forKey: "tools.note") } }
    /// Colors picked from the screen, newest first, as "#RRGGBB".
    @Published var colors: [String] { didSet { save(colors, "tools.colors") } }

    private init() {
        habits = Self.load("tools.habits") ?? []
        countdowns = Self.load("tools.countdowns") ?? []
        cities = Self.load("tools.cities") ?? [WorldCity(name: "New York", zone: "America/New_York"),
                                               WorldCity(name: "Tokyo", zone: "Asia/Tokyo")]
        note = UserDefaults.standard.string(forKey: "tools.note") ?? ""
        colors = Self.load("tools.colors") ?? []
    }

    func addColor(_ hex: String) {
        colors = Array(([hex] + colors.filter { $0 != hex }).prefix(12))
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

/// The last texts you copied, kept in memory only (gone when Nook quits), so one copied a while ago can be copied again
/// from the Tools tab. A copy a password manager marks as concealed or transient is never kept (`ClipboardPolicy`).
/// Off in Settings › Appearance › Tools, it keeps nothing and stops looking.
@MainActor
final class ClipboardHistory: ObservableObject {
    static let shared = ClipboardHistory()

    @Published private(set) var items: [String] = []
    private var lastCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    var enabled: Bool { AppSettings.shared.clipboardHistory }

    /// Looks at the pasteboard's change count once a second: cheap, and the only way macOS offers.
    func start() {
        guard timer == nil else { return }
        lastCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.look() }
        }
    }

    func clear() { items = [] }

    func remove(_ text: String) { items.removeAll { $0 == text } }

    /// Puts `text` back on the clipboard; it moves to the top of the history.
    func copy(_ text: String) {
        Pasteboard.copy(text)
        lastCount = NSPasteboard.general.changeCount
        items = ClipboardPolicy.adding(text, to: items)
    }

    private func look() {
        let board = NSPasteboard.general
        guard board.changeCount != lastCount else { return }
        lastCount = board.changeCount
        guard enabled else {
            if !items.isEmpty { items = [] }
            return
        }
        let types = (board.types ?? []).map(\.rawValue)
        let text = board.string(forType: .string)
        guard ClipboardPolicy.keeps(types: types, text: text), let text else { return }
        // A very long copy (a whole file) is kept short: the history is for snippets.
        items = ClipboardPolicy.adding(String(text.prefix(4000)), to: items)
    }
}

/// "Keep awake" in the Tools tab: holds off the display going to sleep for an hour, three hours, or until you stop it.
/// It shows in Activity Monitor and `pmset -g assertions` as "Nook: keep awake".
@MainActor
final class AwakeHold: ObservableObject {
    static let shared = AwakeHold()

    /// Until when it holds; `.distantFuture` until you stop it; nil while it does not.
    @Published private(set) var until: Date?
    private var assertion: IOPMAssertionID = 0
    private var release: Task<Void, Never>?

    var isOn: Bool { until != nil }

    /// Holds for `minutes`, or until stopped when nil.
    func start(minutes: Int?) {
        stop()
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "Nook: keep awake" as CFString, &id)
        guard result == kIOReturnSuccess else { return }
        assertion = id
        if let minutes {
            let end = Date().addingTimeInterval(TimeInterval(minutes) * 60)
            until = end
            release = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } else {
            until = .distantFuture
        }
    }

    func stop() {
        release?.cancel()
        release = nil
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
        until = nil
    }
}

/// Kitchen timers from the Tools tab ("Tea, 4 min"): several at once, each counting down, and when one runs out Nook
/// says so next to the notch with a sound (`onFinish`).
@MainActor
final class NookTimers: ObservableObject {
    static let shared = NookTimers()

    struct Running: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var session: FocusSession
    }

    @Published private(set) var running: [Running] = []
    var onFinish: ((Running) -> Void)?
    private var waits: [UUID: Task<Void, Never>] = [:]

    /// The lengths offered, in minutes.
    static let presets = [1, 3, 5, 10, 15, 30]

    func start(minutes: Int, title: String) {
        let timer = Running(title: title, session: FocusSession(started: Date(), minutes: minutes))
        running.append(timer)
        let seconds = timer.session.length
        waits[timer.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(timer.id)
        }
    }

    func stop(_ id: UUID) {
        waits[id]?.cancel()
        waits[id] = nil
        running.removeAll { $0.id == id }
    }

    private func finish(_ id: UUID) {
        guard let timer = running.first(where: { $0.id == id }) else { return }
        waits[id] = nil
        running.removeAll { $0.id == id }
        NSSound(named: NSSound.Name("Glass"))?.play()
        onFinish?(timer)
    }
}

/// The battery, looked at once a minute: its level for the Tools tab, and once per discharge a word from Nook when it
/// runs low (20 % and 10 %), and once per charge when it is full.
@MainActor
final class BatteryWatch: ObservableObject {
    static let shared = BatteryWatch()

    @Published private(set) var level: Int?
    @Published private(set) var onPower = true
    /// Called with the level when it crosses a low mark on battery, and with 100 once it is full on power.
    var onAlert: ((Int, Bool) -> Void)?
    private var warned: Set<Int> = []
    private var timer: Timer?

    /// The levels Nook speaks up at.
    static let lowMarks = [20, 10]

    func start() {
        guard timer == nil else { return }
        look()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.look() }
        }
    }

    private func look() {
        let power = PowerSource.current()
        if power.battery != level { level = power.battery }
        if power.onPower != onPower { onPower = power.onPower }
        guard let battery = power.battery, AppSettings.shared.batteryAlerts else { return }
        if power.onPower {
            // Plugged in: the low warnings may come again on the next discharge.
            warned.subtract(Self.lowMarks)
            if battery >= 100, !warned.contains(100) {
                warned.insert(100)
                onAlert?(100, true)
            }
        } else {
            warned.remove(100)
            if let mark = Self.lowMarks.filter({ battery <= $0 && !warned.contains($0) }).min() {
                // Both marks count as said once the lower one is: no second warning a minute later.
                warned.formUnion(Self.lowMarks.filter { $0 >= mark })
                onAlert?(battery, false)
            }
        }
    }
}
