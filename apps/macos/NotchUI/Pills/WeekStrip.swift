import SwiftUI
import AppKit

/// The coming seven days on Nook's home, under "Your day": each day its weekday and date, today in Nook's color, and a
/// dot per event in its calendar's color (three at most, then a count). A click on a day opens Calendar at it.
struct WeekStrip: View {
    @ObservedObject var week: WeekAgenda = .shared
    @EnvironmentObject private var app: AppModel

    var body: some View {
        HStack(spacing: NookTheme.Spacing.xxs) {
            ForEach(week.days, id: \.date) { day in
                WeekDayCell(day: day)
            }
        }
        .padding(NookTheme.Spacing.sm)
        .panelCard()
        // Again whenever the next hours change (an event added, moved or gone): the week follows.
        .task(id: app.upcoming) { await week.load(app.calendar) }
    }
}

/// The week's events by day, read from the same calendars as "Your day".
@MainActor
final class WeekAgenda: ObservableObject {
    static let shared = WeekAgenda()

    struct Day: Equatable {
        let date: Date
        let events: [CalEvent]
    }

    @Published private(set) var days: [Day] = []

    func load(_ calendar: CalendarService, now: Date = Date()) async {
        guard calendar.hasEventAccess else {
            if !days.isEmpty { days = [] }
            return
        }
        let start = Calendar.current.startOfDay(for: now)
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return }
        let events = await calendar.loadEvents(from: start, to: end)
        let made = Self.days(events, from: start)
        if made != days { days = made }
    }

    /// Seven days from `start`, each with the events that start on it, all-day ones first.
    static func days(_ events: [CalEvent], from start: Date, count: Int = 7, calendar: Calendar = .current) -> [Day] {
        (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let on = events
                .filter { calendar.isDate($0.start, inSameDayAs: date) }
                .sorted { ($0.allDay ? 0 : 1, $0.start) < ($1.allDay ? 0 : 1, $1.start) }
            return Day(date: date, events: on)
        }
    }
}

private struct WeekDayCell: View {
    let day: WeekAgenda.Day
    @State private var hovering = false

    private var isToday: Bool { Calendar.current.isDateInToday(day.date) }
    private var language: String { I18n.shared.currentLanguage.rawValue }

    var body: some View {
        Button(action: open) {
            VStack(spacing: NookTheme.Spacing.xs) {
                Text(NookDates.formatter("EEE", locale: language).string(from: day.date).prefix(2).uppercased())
                    .font(NookTheme.TextStyle.caption)
                    .foregroundStyle(isToday ? NookTheme.iris : NookTheme.textTertiary)
                Text(NookDates.formatter("d", locale: language).string(from: day.date))
                    .font(NookTheme.rounded(13, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? NookTheme.onIris : NookTheme.textStrong)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(isToday ? NookTheme.iris : Color.clear))
                dots
                    .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NookTheme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: NookTheme.Radius.control, style: .continuous)
                .fill(hovering ? NookTheme.rowHover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(NookTheme.hover, value: hovering)
        .help(summary)
        .accessibilityLabel(summary)
    }

    /// A dot per event in its calendar's color, three at most; more shows as a small "+".
    private var dots: some View {
        HStack(spacing: NookTheme.Spacing.xxs) {
            ForEach(day.events.prefix(3), id: \.id) { event in
                Circle()
                    .fill(NookPalette.eventColor(hex: event.colorHex, calendar: event.calendar))
                    .frame(width: 5, height: 5)
            }
            if day.events.count > 3 {
                Image(systemName: "plus")
                    .font(NookTheme.font(6, .bold))
                    .foregroundStyle(NookTheme.textTertiary)
            }
        }
    }

    /// "Tuesday 24 November: 3 events", or the day's only event by name.
    private var summary: String {
        let date = NookDates.formatter("EEEE d MMMM", locale: language).string(from: day.date)
        switch day.events.count {
        case 0: return tr("home.week.free", date)
        case 1: return "\(date): \(day.events[0].title)"
        default: return tr("home.week.events", date, day.events.count)
        }
    }

    private func open() {
        if let first = day.events.first {
            AgendaStrip.open(first)
        } else {
            AgendaStrip.open(CalEvent(id: "", title: "", start: day.date, end: day.date, location: ""))
        }
    }
}
